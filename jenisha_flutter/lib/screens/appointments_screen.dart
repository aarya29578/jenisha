import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────────────────────────────────────

class _AppointmentService {
  final String id;
  final String name;
  final String description;
  final double price;
  final bool isActive;

  const _AppointmentService({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.isActive,
  });

  factory _AppointmentService.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _AppointmentService(
      id: doc.id,
      name: d['name'] as String? ?? '',
      description: d['description'] as String? ?? '',
      price: (d['price'] as num?)?.toDouble() ?? 0.0,
      isActive: d['isActive'] as bool? ?? true,
    );
  }
}

class _Appointment {
  final String id;
  final String appointmentServiceName;
  final String date;
  final String time;
  final String status;
  final Timestamp createdAt;

  const _Appointment({
    required this.id,
    required this.appointmentServiceName,
    required this.date,
    required this.time,
    required this.status,
    required this.createdAt,
  });

  factory _Appointment.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _Appointment(
      id: doc.id,
      appointmentServiceName: d['appointmentServiceName'] as String? ?? '',
      date: d['date'] as String? ?? '',
      time: d['time'] as String? ?? '',
      status: d['status'] as String? ?? 'pending',
      createdAt: d['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }
}

class _AppointmentField {
  final String id;
  final String label;
  final String type; // text | number | date | dropdown | image
  final bool required;
  final List<String> options;
  final double? maxFileSizeMB;

  const _AppointmentField({
    required this.id,
    required this.label,
    required this.type,
    required this.required,
    required this.options,
    this.maxFileSizeMB,
  });

  factory _AppointmentField.fromMap(Map<String, dynamic> m) {
    return _AppointmentField(
      id: m['id'] as String? ?? '',
      label: m['label'] as String? ?? '',
      type: m['type'] as String? ?? 'text',
      required: m['required'] as bool? ?? false,
      options: List<String>.from(m['options'] as List<dynamic>? ?? []),
      maxFileSizeMB: (m['maxFileSizeMB'] as num?)?.toDouble(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({Key? key}) : super(key: key);

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Streams ─────────────────────────────────────────────────────────────

  Stream<List<_AppointmentService>> _servicesStream() {
    return _firestore
        .collection('appointment_services')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => _AppointmentService.fromDoc(d)).toList());
  }

  Stream<List<_Appointment>> _myAppointmentsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return _firestore
        .collection('appointments')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => _Appointment.fromDoc(d)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // ── Booking form ─────────────────────────────────────────────────────────

  Future<void> _openBookingForm(_AppointmentService service) async {
    // Fetch dynamic fields for this service (one-time read)
    List<_AppointmentField> fields = [];
    try {
      final snap = await _firestore
          .collection('appointment_fields')
          .doc(service.id)
          .get();
      if (snap.exists) {
        final rawList = (snap.data()?['fields'] as List<dynamic>? ?? []);
        fields = rawList
            .map((e) =>
                _AppointmentField.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingFormSheet(service: service, fields: fields),
    );
  }

  // ── Status badge ─────────────────────────────────────────────────────────

  Widget _statusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status.toLowerCase()) {
      case 'approved':
        bg = AppTheme.successGreen.withOpacity(0.15);
        fg = AppTheme.successGreen;
        label = '✅ Approved';
        break;
      case 'rejected':
        bg = AppTheme.errorRed.withOpacity(0.15);
        fg = AppTheme.errorRed;
        label = '❌ Rejected';
        break;
      default:
        bg = AppTheme.warningOrange.withOpacity(0.15);
        fg = AppTheme.warningOrange;
        label = '🕐 Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGray,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        title: const Text(
          'Appointments',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Book Appointment'),
            Tab(text: 'My Bookings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildServicesTab(),
          _buildMyBookingsTab(),
        ],
      ),
    );
  }

  // ── Tab 1: Services ──────────────────────────────────────────────────────

  Widget _buildServicesTab() {
    return StreamBuilder<List<_AppointmentService>>(
      stream: _servicesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryBlue),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading services: ${snapshot.error}',
              style: const TextStyle(color: AppTheme.errorRed),
            ),
          );
        }
        final services = snapshot.data ?? [];
        if (services.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No appointment services available',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: services.length,
          itemBuilder: (context, index) => _serviceCard(services[index]),
        );
      },
    );
  }

  Widget _serviceCard(_AppointmentService service) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppTheme.pureWhite,
      child: InkWell(
        onTap: () => _openBookingForm(service),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_month,
                    color: AppTheme.primaryBlue, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (service.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        service.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      service.price > 0
                          ? '₹${service.price.toStringAsFixed(0)}'
                          : 'Free',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: service.price > 0
                            ? AppTheme.primaryBlue
                            : AppTheme.accentGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  size: 16, color: AppTheme.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab 2: My Bookings ───────────────────────────────────────────────────

  Widget _buildMyBookingsTab() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(
        child: Text(
          'Please log in to view your bookings.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return StreamBuilder<List<_Appointment>>(
      stream: _myAppointmentsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryBlue),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading bookings: ${snapshot.error}',
              style: const TextStyle(color: AppTheme.errorRed),
            ),
          );
        }
        final bookings = snapshot.data ?? [];
        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No bookings yet',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap "Book Appointment" to get started',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) => _bookingCard(bookings[index]),
        );
      },
    );
  }

  Widget _bookingCard(_Appointment appt) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppTheme.pureWhite,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    appt.appointmentServiceName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                _statusBadge(appt.status),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppTheme.borderColor),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 15, color: AppTheme.textTertiary),
                const SizedBox(width: 6),
                Text(
                  appt.date,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.access_time,
                    size: 15, color: AppTheme.textTertiary),
                const SizedBox(width: 6),
                Text(
                  appt.time,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Booking Form Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _BookingFormSheet extends StatefulWidget {
  final _AppointmentService service;
  final List<_AppointmentField> fields;
  const _BookingFormSheet({required this.service, required this.fields});

  @override
  State<_BookingFormSheet> createState() => _BookingFormSheetState();
}

class _BookingFormSheetState extends State<_BookingFormSheet> {
  // Step: 0 = dynamic fields, 1 = date/time selection
  int _step = 0;
  final Map<String, String> _formAnswers = {};
  String? _formError;

  DateTime? _selectedDate;
  String? _selectedTime;
  bool _submitting = false;

  static const List<String> _timeSlots = [
    '09:00 AM',
    '09:30 AM',
    '10:00 AM',
    '10:30 AM',
    '11:00 AM',
    '11:30 AM',
    '12:00 PM',
    '12:30 PM',
    '02:00 PM',
    '02:30 PM',
    '03:00 PM',
    '03:30 PM',
    '04:00 PM',
    '04:30 PM',
    '05:00 PM',
  ];

  // ── Dynamic form ──────────────────────────────────────────────────────

  void _validateAndProceed() {
    for (final field in widget.fields) {
      if (!field.required) continue;
      final val = (_formAnswers[field.id] ?? '').trim();
      if (val.isEmpty) {
        setState(() => _formError = '${field.label} is required');
        return;
      }
    }
    setState(() {
      _formError = null;
      _step = 1;
    });
  }

  Widget _buildDynamicForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...widget.fields.map((field) {
          final value = _formAnswers[field.id] ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${field.label}${field.required ? ' *' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                if (field.type == 'dropdown')
                  DropdownButtonFormField<String>(
                    value: value.isEmpty ? null : value,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    hint: const Text('Select an option'),
                    items: field.options
                        .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _formAnswers[field.id] = v ?? ''),
                  )
                else if (field.type == 'date')
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => _formAnswers[field.id] =
                            DateFormat('dd MMM yyyy').format(picked));
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: value.isNotEmpty
                              ? AppTheme.primaryBlue
                              : AppTheme.borderColor,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        value.isEmpty ? 'Tap to select date' : value,
                        style: TextStyle(
                          color: value.isEmpty
                              ? AppTheme.textTertiary
                              : AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else
                  TextFormField(
                    initialValue: value,
                    keyboardType: field.type == 'number'
                        ? TextInputType.number
                        : TextInputType.text,
                    onChanged: (v) =>
                        setState(() => _formAnswers[field.id] = v),
                    decoration: InputDecoration(
                      hintText: field.label,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                  ),
              ],
            ),
          );
        }),
        if (_formError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _formError!,
              style: const TextStyle(color: AppTheme.errorRed, fontSize: 12),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _validateAndProceed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text(
              'Next →',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  // ── Date picker ─────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_selectedDate == null) {
      _showSnack('Please select a date', isError: true);
      return;
    }
    if (_selectedTime == null) {
      _showSnack('Please select a time slot', isError: true);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('You must be logged in', isError: true);
      return;
    }

    setState(() => _submitting = true);

    try {
      // Get the user's name and phone from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      final userName = userData['name'] as String? ??
          userData['fullName'] as String? ??
          user.displayName ??
          'N/A';
      final phone = userData['phone'] as String? ??
          userData['mobile'] as String? ??
          user.phoneNumber ??
          'N/A';

      await FirebaseFirestore.instance.collection('appointments').add({
        'userId': user.uid,
        'userName': userName,
        'phone': phone,
        'appointmentServiceId': widget.service.id,
        'appointmentServiceName': widget.service.name,
        'formData': Map<String, dynamic>.from(_formAnswers),
        'date': DateFormat('dd MMM yyyy').format(_selectedDate!),
        'time': _selectedTime,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        _showSnack('Appointment booked successfully! ✅');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _showSnack('Failed to book: $e', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.errorRed : AppTheme.accentGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Book: ${widget.service.name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            if (widget.service.price > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '₹${widget.service.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // Show dynamic form first (if fields exist), then date/time
            if (widget.fields.isNotEmpty && _step == 0)
              _buildDynamicForm()
            else ...[
              // Date picker
              const Text(
                'Select Date',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedDate != null
                          ? AppTheme.primaryBlue
                          : AppTheme.borderColor,
                      width: _selectedDate != null ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    color: _selectedDate != null
                        ? AppTheme.primaryBlue.withOpacity(0.04)
                        : AppTheme.backgroundGray,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 18, color: AppTheme.primaryBlue),
                      const SizedBox(width: 10),
                      Text(
                        _selectedDate != null
                            ? DateFormat('EEE, dd MMM yyyy')
                                .format(_selectedDate!)
                            : 'Tap to choose a date',
                        style: TextStyle(
                          fontSize: 14,
                          color: _selectedDate != null
                              ? AppTheme.textPrimary
                              : AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Time slots
              const Text(
                'Select Time Slot',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _timeSlots.map((slot) {
                  final isSelected = _selectedTime == slot;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTime = slot),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryBlue
                            : AppTheme.backgroundGray,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryBlue
                              : AppTheme.borderColor,
                        ),
                      ),
                      child: Text(
                        slot,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Confirm Booking',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ], // close date/time step
          ],
        ),
      ),
    );
  }
}
