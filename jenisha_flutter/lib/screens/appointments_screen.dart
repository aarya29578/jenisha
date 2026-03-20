import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
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

  // Extra state for typed fields in the dynamic form
  final Map<String, DateTime> _fieldDates = {}; // dob / appointment date
  final Map<String, TimeOfDay> _fieldTimes =
      {}; // appointment time / time_range end
  final Map<String, TimeOfDay> _fieldStartTimes = {}; // time_range start
  final Map<String, String> _fieldFileNames = {}; // picked file display name
  final Map<String, File?> _fieldFiles = {}; // picked file object

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

  void _validateAndProceed() {
    for (final field in widget.fields) {
      if (!field.required) continue;
      final type = field.type;
      // File-based types: check _fieldFiles
      if (['image', 'pdf', 'document', 'template'].contains(type)) {
        if (_fieldFiles[field.id] == null) {
          setState(() => _formError = '${field.label} is required');
          return;
        }
      } else if (type == 'dob' || type == 'appointment') {
        if (_fieldDates[field.id] == null) {
          setState(() => _formError = '${field.label} is required');
          return;
        }
        if (type == 'appointment' && _fieldTimes[field.id] == null) {
          setState(
              () => _formError = 'Please select a time for ${field.label}');
          return;
        }
      } else if (type == 'time_range') {
        if (_fieldStartTimes[field.id] == null ||
            _fieldTimes[field.id] == null) {
          setState(
              () => _formError = '${field.label} start/end time is required');
          return;
        }
      } else {
        final val = (_formAnswers[field.id] ?? '').trim();
        if (val.isEmpty) {
          setState(() => _formError = '${field.label} is required');
          return;
        }
      }
    }
    setState(() {
      _formError = null;
      _step = 1;
    });
  }

  // ── Helpers to build the formatted answer strings ─────────────────────────

  void _buildAnswersFromState() {
    for (final field in widget.fields) {
      final type = field.type;
      if (type == 'dob') {
        final d = _fieldDates[field.id];
        if (d != null)
          _formAnswers[field.id] = DateFormat('dd/MM/yyyy').format(d);
      } else if (type == 'appointment') {
        final d = _fieldDates[field.id];
        final t = _fieldTimes[field.id];
        if (d != null && t != null) {
          _formAnswers[field.id] =
              '${DateFormat('dd MMM yyyy').format(d)} ${t.format(context)}';
        }
      } else if (type == 'time_range') {
        final start = _fieldStartTimes[field.id];
        final end = _fieldTimes[field.id];
        if (start != null && end != null) {
          _formAnswers[field.id] =
              '${start.format(context)} – ${end.format(context)}';
        }
      } else if (['image', 'pdf', 'document', 'template'].contains(type)) {
        _formAnswers[field.id] = _fieldFileNames[field.id] ?? '';
      }
    }
  }

  Widget _buildDynamicForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...widget.fields.map((field) {
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
                _buildFieldWidget(field),
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
            onPressed: () {
              _buildAnswersFromState();
              _validateAndProceed();
            },
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

  Widget _buildFieldWidget(_AppointmentField field) {
    final type = field.type;

    // ── Date of Birth ─────────────────────────────────────────────────
    if (type == 'dob') {
      final picked = _fieldDates[field.id];
      return _datePickerTile(
        label: picked != null
            ? DateFormat('dd MMM yyyy').format(picked)
            : 'Select date of birth',
        hasValue: picked != null,
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: picked ?? DateTime(2000),
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
          );
          if (d != null) setState(() => _fieldDates[field.id] = d);
        },
      );
    }

    // ── Appointment (date + time) ─────────────────────────────────────
    if (type == 'appointment') {
      final pickedDate = _fieldDates[field.id];
      final pickedTime = _fieldTimes[field.id];
      return Column(
        children: [
          _datePickerTile(
            label: pickedDate != null
                ? DateFormat('dd MMM yyyy').format(pickedDate)
                : 'Select date',
            hasValue: pickedDate != null,
            onTap: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate: pickedDate ?? now.add(const Duration(days: 1)),
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
              );
              if (d != null) setState(() => _fieldDates[field.id] = d);
            },
          ),
          const SizedBox(height: 8),
          _timePickerTile(
            label:
                pickedTime != null ? pickedTime.format(context) : 'Select time',
            hasValue: pickedTime != null,
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: pickedTime ?? TimeOfDay.now(),
              );
              if (t != null) setState(() => _fieldTimes[field.id] = t);
            },
          ),
        ],
      );
    }

    // ── Time Period (start → end) ─────────────────────────────────────
    if (type == 'time_range') {
      final start = _fieldStartTimes[field.id];
      final end = _fieldTimes[field.id];
      return Row(
        children: [
          Expanded(
            child: _timePickerTile(
              label: start != null ? start.format(context) : 'Start time',
              hasValue: start != null,
              onTap: () async {
                final t = await showTimePicker(
                    context: context,
                    initialTime: start ?? const TimeOfDay(hour: 9, minute: 0));
                if (t != null) setState(() => _fieldStartTimes[field.id] = t);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('–',
                style: TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
          ),
          Expanded(
            child: _timePickerTile(
              label: end != null ? end.format(context) : 'End time',
              hasValue: end != null,
              onTap: () async {
                final t = await showTimePicker(
                    context: context,
                    initialTime: end ?? const TimeOfDay(hour: 10, minute: 0));
                if (t != null) setState(() => _fieldTimes[field.id] = t);
              },
            ),
          ),
        ],
      );
    }

    // ── Image Upload ──────────────────────────────────────────────────
    if (type == 'image') {
      return _fileTile(
        fieldId: field.id,
        label: 'Upload Image',
        icon: Icons.image_outlined,
        acceptedFormats: 'JPG, PNG, etc.',
        onTap: () async {
          final img = await ImagePicker()
              .pickImage(source: ImageSource.gallery, imageQuality: 85);
          if (img != null) {
            setState(() {
              _fieldFiles[field.id] = File(img.path);
              _fieldFileNames[field.id] = img.name;
            });
          }
        },
      );
    }

    // ── PDF Upload ────────────────────────────────────────────────────
    if (type == 'pdf') {
      return _fileTile(
        fieldId: field.id,
        label: 'Upload PDF',
        icon: Icons.picture_as_pdf_outlined,
        acceptedFormats: 'PDF only',
        onTap: () async {
          final result = await FilePicker.platform
              .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
          if (result != null && result.files.single.path != null) {
            setState(() {
              _fieldFiles[field.id] = File(result.files.single.path!);
              _fieldFileNames[field.id] = result.files.single.name;
            });
          }
        },
      );
    }

    // ── Document Upload ───────────────────────────────────────────────
    if (type == 'document') {
      return _fileTile(
        fieldId: field.id,
        label: 'Upload Document',
        icon: Icons.insert_drive_file_outlined,
        acceptedFormats: 'PDF, DOC, DOCX',
        onTap: () async {
          final result = await FilePicker.platform.pickFiles(
              type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']);
          if (result != null && result.files.single.path != null) {
            setState(() {
              _fieldFiles[field.id] = File(result.files.single.path!);
              _fieldFileNames[field.id] = result.files.single.name;
            });
          }
        },
      );
    }

    // ── Template Upload ───────────────────────────────────────────────
    if (type == 'template') {
      return _fileTile(
        fieldId: field.id,
        label: 'Upload Template',
        icon: Icons.upload_file_outlined,
        acceptedFormats: 'PDF, DOC, DOCX, XLS',
        onTap: () async {
          final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx']);
          if (result != null && result.files.single.path != null) {
            setState(() {
              _fieldFiles[field.id] = File(result.files.single.path!);
              _fieldFileNames[field.id] = result.files.single.name;
            });
          }
        },
      );
    }

    // ── Address ───────────────────────────────────────────────────────
    if (type == 'address') {
      return TextFormField(
        initialValue: _formAnswers[field.id] ?? '',
        maxLines: 3,
        keyboardType: TextInputType.streetAddress,
        onChanged: (v) => setState(() => _formAnswers[field.id] = v),
        decoration: InputDecoration(
          hintText: 'Enter full address',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
        ),
      );
    }

    // ── Mobile Number ─────────────────────────────────────────────────
    if (type == 'mobile') {
      return TextFormField(
        initialValue: _formAnswers[field.id] ?? '',
        keyboardType: TextInputType.phone,
        maxLength: 10,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (v) => setState(() => _formAnswers[field.id] = v),
        decoration: InputDecoration(
          hintText: '10-digit mobile number',
          counterText: '',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
        ),
      );
    }

    // ── Dropdown ──────────────────────────────────────────────────────
    if (type == 'dropdown') {
      final value = _formAnswers[field.id] ?? '';
      return DropdownButtonFormField<String>(
        value: value.isEmpty ? null : value,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        hint: const Text('Select an option'),
        items: field.options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: (v) => setState(() => _formAnswers[field.id] = v ?? ''),
      );
    }

    // ── Date ──────────────────────────────────────────────────────────
    if (type == 'date') {
      final picked = _fieldDates[field.id];
      return _datePickerTile(
        label: picked != null
            ? DateFormat('dd MMM yyyy').format(picked)
            : 'Tap to select date',
        hasValue: picked != null,
        onTap: () async {
          final now = DateTime.now();
          final d = await showDatePicker(
            context: context,
            initialDate: picked ?? now,
            firstDate: DateTime(1900),
            lastDate: DateTime(2100),
          );
          if (d != null) {
            setState(() {
              _fieldDates[field.id] = d;
              _formAnswers[field.id] = DateFormat('dd MMM yyyy').format(d);
            });
          }
        },
      );
    }

    // ── Default: text / number ────────────────────────────────────────
    return TextFormField(
      initialValue: _formAnswers[field.id] ?? '',
      keyboardType:
          type == 'number' ? TextInputType.number : TextInputType.text,
      onChanged: (v) => setState(() => _formAnswers[field.id] = v),
      decoration: InputDecoration(
        hintText: field.label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  // ── Reusable UI tiles ─────────────────────────────────────────────────────

  Widget _datePickerTile({
    required String label,
    required bool hasValue,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasValue ? AppTheme.primaryBlue : AppTheme.borderColor,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today,
                size: 18,
                color: hasValue ? AppTheme.primaryBlue : AppTheme.textTertiary),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: hasValue ? AppTheme.textPrimary : AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timePickerTile({
    required String label,
    required bool hasValue,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasValue ? AppTheme.primaryBlue : AppTheme.borderColor,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time,
                size: 18,
                color: hasValue ? AppTheme.primaryBlue : AppTheme.textTertiary),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: hasValue ? AppTheme.textPrimary : AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileTile({
    required String fieldId,
    required String label,
    required IconData icon,
    required String acceptedFormats,
    required VoidCallback onTap,
  }) {
    final fileName = _fieldFileNames[fieldId];
    final hasFile = fileName != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: hasFile
              ? AppTheme.primaryBlue.withOpacity(0.05)
              : Colors.grey.shade50,
          border: Border.all(
            color: hasFile ? AppTheme.primaryBlue : AppTheme.borderColor,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(hasFile ? Icons.check_circle_outline : icon,
                size: 22,
                color: hasFile ? AppTheme.primaryBlue : AppTheme.textTertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFile ? fileName : label,
                    style: TextStyle(
                      fontSize: 14,
                      color: hasFile
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!hasFile)
                    Text(
                      acceptedFormats,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textTertiary),
                    ),
                ],
              ),
            ),
            Icon(
              hasFile ? Icons.edit_outlined : Icons.upload_outlined,
              size: 18,
              color: AppTheme.textTertiary,
            ),
          ],
        ),
      ),
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
