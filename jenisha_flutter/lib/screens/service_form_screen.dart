import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/firestore_service.dart';
import 'document_upload_widget.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class ServiceFormScreen extends StatefulWidget {
  const ServiceFormScreen({Key? key}) : super(key: key);

  @override
  _ServiceFormScreenState createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _serviceId = '';
  String _serviceName = '';
  String _serviceLogoUrl = '';

  // Dynamic fields from admin panel
  List<Map<String, dynamic>> _dynamicFields = [];
  Map<String, TextEditingController> _textControllers = {};
  Map<String, String> _dynamicFieldValues =
      {}; // Store all field values including images

  // Appointment field state
  Map<String, DateTime?> _appointmentDates = {};
  Map<String, TimeOfDay?> _appointmentTimes = {};

  bool _isSubmitting = false;
  bool _hasInitialized = false;
  bool _isLoadingFields = true;
  bool _showValidationErrors = false; // highlight empty required fields
  final Set<String> _uploadingFields =
      {}; // tracks per-field upload in progress

  // Form template (set by admin) + filled form submission
  String _formTemplateUrl = '';
  File? _filledFormFile;
  Uint8List? _filledFormBytes; // actual bytes read from the picked file
  String _filledFormName = ''; // original filename for display
  String _filledFormUrl = '';
  bool _isUploadingFilledForm = false;
  int _serviceFee = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasInitialized) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _serviceId = args['serviceId'] ?? '';
      _serviceName = args['serviceName'] ?? 'Service';
      _serviceLogoUrl = (args['logoUrl'] as String? ?? '').trim();
      print('✅ ServiceFormScreen initialized:');
      print('   serviceId: "$_serviceId"');
      print('   serviceName: "$_serviceName"');

      // Load dynamic fields from Firestore
      _loadDynamicFields();
    }
    _hasInitialized = true;
  }

  /// Load dynamic fields configured in admin panel for this service
  Future<void> _loadDynamicFields() async {
    try {
      setState(() => _isLoadingFields = true);

      // Fetch form template URL from the services document
      try {
        final serviceDoc = await FirebaseFirestore.instance
            .collection('services')
            .doc(_serviceId)
            .get();
        if (serviceDoc.exists) {
          final sData = serviceDoc.data();
          final rawUrl = sData?['formTemplateUrl']?.toString().trim() ?? '';
          print('🔍 Template URL from Firestore: "$rawUrl"');
          final validUrl = rawUrl.isNotEmpty && rawUrl != 'None';
          final feeRaw = sData?['price'];
          setState(() {
            _formTemplateUrl = validUrl ? rawUrl : '';
            _serviceFee = (feeRaw is num) ? feeRaw.toInt() : 0;
          });
          print(validUrl
              ? '✅ Form template URL loaded: $_formTemplateUrl'
              : '⚠️ No valid form template for this service');
          if (_serviceFee > 0) print('💰 Service fee: ₹$_serviceFee');
        }
      } catch (e) {
        print('⚠️ Could not fetch formTemplateUrl: $e');
      }

      final fieldsDoc = await FirebaseFirestore.instance
          .collection('service_document_fields')
          .doc(_serviceId)
          .get();

      if (fieldsDoc.exists) {
        final data = fieldsDoc.data();
        if (data != null && data['fields'] != null) {
          final fields = List<Map<String, dynamic>>.from(data['fields']);

          setState(() {
            _dynamicFields = fields;
            // Create controllers for text fields
            for (var field in fields) {
              final fieldName = (field['fieldName'] ?? field['name'] as dynamic)
                      ?.toString()
                      .trim() ??
                  '';
              // Support both 'fieldType' (service_document_fields) and 'type' (services.documentFields)
              final fieldType =
                  ((field['fieldType'] ?? field['type']) as String? ?? 'text')
                      .trim();

              if (fieldType == 'text' ||
                  fieldType == 'number' ||
                  fieldType == 'date' ||
                  fieldType == 'dob' ||
                  fieldType == 'address' ||
                  fieldType == 'mobile') {
                _textControllers[fieldName] = TextEditingController();
                _textControllers[fieldName]!.addListener(() {
                  setState(() {});
                });
              }
            }
          });

          print('✅ Loaded ${fields.length} dynamic fields for $_serviceName');
          print('   Fields: $fields');
        }
      } else {
        print('⚠️ No dynamic fields found for service $_serviceId');
      }
    } catch (e) {
      print('❌ Error loading dynamic fields: $e');
    } finally {
      setState(() => _isLoadingFields = false);
    }
  }

  bool get _canSubmit {
    // Check if all required fields are filled
    for (var field in _dynamicFields) {
      final isRequired =
          field['isRequired'] == true || field['required'] == true;
      if (!isRequired) continue;

      final fieldName = ((field['fieldName'] ?? field['name']) as dynamic)
              ?.toString()
              .trim() ??
          '';
      final fieldType =
          ((field['fieldType'] ?? field['type']) as String? ?? 'text').trim();

      if (fieldType == 'text' ||
          fieldType == 'number' ||
          fieldType == 'date' ||
          fieldType == 'dob' ||
          fieldType == 'address' ||
          fieldType == 'mobile') {
        final controller = _textControllers[fieldName];
        if (controller == null || controller.text.trim().isEmpty) {
          return false;
        }
        // Mobile: require exactly 10 digits
        if (fieldType == 'mobile') {
          final digits = controller.text.trim().replaceAll(RegExp(r'\D'), '');
          if (digits.length != 10) return false;
        }
      } else if (fieldType == 'image' ||
          fieldType == 'pdf' ||
          fieldType == 'document') {
        final value = _dynamicFieldValues[fieldName];
        if (value == null || value.isEmpty) {
          return false;
        }
      } else if (fieldType == 'appointment') {
        if (_appointmentDates[fieldName] == null ||
            _appointmentTimes[fieldName] == null) {
          return false;
        }
      } else if (fieldType == 'time_range') {
        if (_appointmentTimes['${fieldName}_start'] == null ||
            _appointmentTimes['${fieldName}_end'] == null) {
          return false;
        }
      }
      // template: admin-only, skip validation
    }

    return true;
  }

  /// Upload image to Hostinger
  Future<String?> _uploadImageToHostinger(
      XFile imageFile, String fieldName) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('https://jenishaonlineservice.com/uploads/upload_field.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'image': base64Image,
          'filename':
              'field_${fieldName}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        }),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          print('✅ Image uploaded: ${result['url']}');
          return result['url'];
        } else {
          print('❌ Upload failed: ${result['error'] ?? 'Unknown error'}');
        }
      } else {
        print('❌ Image upload failed with status: ${response.statusCode}');
        print('   Response: ${response.body}');
      }

      return null;
    } catch (e) {
      print('❌ Error uploading image: $e');
      return null;
    }
  }

  /// Pick a filled form (PDF/DOC) file using file_picker
  Future<void> _pickFilledForm() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true, // load bytes immediately, avoids Android path issues
      );
      if (result != null && result.files.isNotEmpty) {
        final picked = result.files.first;
        final bytes = picked.bytes;
        if (bytes == null || bytes.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Could not read the selected file. Please try another file.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        setState(() {
          _filledFormBytes = bytes;
          _filledFormName = picked.name;
          _filledFormFile = picked.path != null ? File(picked.path!) : null;
          _filledFormUrl = ''; // reset old uploaded URL
        });
      }
    } catch (e) {
      print('❌ Error picking file: $e');
    }
  }

  /// Upload the picked filled form to Hostinger
  Future<String?> _uploadFilledFormToHostinger(File file) async {
    try {
      setState(() => _isUploadingFilledForm = true);
      final user = _auth.currentUser;

      // Use pre-loaded bytes if available (more reliable on Android)
      Uint8List? bytes = _filledFormBytes;
      String filename = _filledFormName.isNotEmpty
          ? _filledFormName
          : file.path.split('/').last;

      // Fallback: read from file if bytes weren't loaded at pick time
      if (bytes == null || bytes.isEmpty) {
        bytes = await file.readAsBytes();
      }

      if (bytes.isEmpty) {
        print('❌ File bytes are empty — cannot upload');
        return null;
      }

      print('📤 Uploading $filename (${bytes.length} bytes) to Hostinger...');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
            'https://jenishaonlineservice.com/uploads/upload_form_submission.php'),
      );
      request.fields['userId'] = user?.uid ?? 'unknown';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 PHP response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          print('✅ Filled form uploaded: ${result["fileUrl"]}');
          return result['fileUrl'] as String;
        } else {
          print('❌ Filled form upload failed: ${result["error"]}');
        }
      } else {
        print('❌ Filled form upload HTTP error: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      print('❌ Error uploading filled form: $e');
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingFilledForm = false);
    }
  }

  // ── Payment confirmation dialog ───────────────────────────────────────────
  Future<bool> _showPaymentConfirmDialog(int balance) async {
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Color(0xFF4C4CFF)),
            SizedBox(width: 8),
            Text('Payment Confirmation'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _paymentRow('Service Fee', '₹$_serviceFee', bold: true),
            const Divider(),
            _paymentRow('Wallet Balance', '₹$balance'),
            _paymentRow('Balance After Payment', '₹${balance - _serviceFee}'),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4C4CFF)),
            child: const Text('Pay & Submit',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Widget _paymentRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
                color: bold ? const Color(0xFF4C4CFF) : Colors.black87,
              )),
        ],
      ),
    );
  }

  /// Process referral commission immediately on the client after a paid
  /// application is created.  Mirrors the Cloud Function logic so commission
  /// is credited even when the function has not been deployed yet.
  /// The Cloud Function will skip reprocessing if it sees commissionGenerated==true.
  Future<void> _processReferralCommission({
    required String userId,
    required String applicationId,
    required String agentFullName,
    required double amountPaid,
  }) async {
    try {
      final db = FirebaseFirestore.instance;

      // 1. Get the submitting user's referredBy field
      final userDoc = await db.collection('users').doc(userId).get();
      final referredBy =
          ((userDoc.data()?['referredBy'] ?? '') as String).trim();
      if (referredBy.isEmpty) {
        debugPrint('ℹ️ No referredBy on user $userId — skipping commission');
        return;
      }

      // 2. Find the referring agent by their referCode
      final agentQuery = await db
          .collection('users')
          .where('referCode', isEqualTo: referredBy)
          .limit(1)
          .get();
      if (agentQuery.docs.isEmpty) {
        debugPrint('ℹ️ No agent found for referCode "$referredBy"');
        return;
      }

      final agentDoc = agentQuery.docs.first;
      final agentId = agentDoc.id;
      if (agentId == userId) return; // no self-commission

      final agentData = agentDoc.data() as Map<String, dynamic>;
      final agentName =
          (agentData['fullName'] ?? agentData['name'] ?? 'Agent') as String;

      // 3. Read commission percentage from settings (default 20 %)
      double commissionPct = 20.0;
      try {
        final settingsDoc =
            await db.collection('settings').doc('commission').get();
        if (settingsDoc.exists) {
          final pct = settingsDoc.data()?['commissionPercentage'];
          if (pct is num) commissionPct = pct.toDouble();
        }
      } catch (_) {}

      final commissionAmount =
          double.parse((amountPaid * commissionPct / 100).toStringAsFixed(2));
      if (commissionAmount <= 0) return;

      // 4. Credit the agent's wallet (atomic increment)
      await db.collection('users').doc(agentId).update({
        'walletBalance': FieldValue.increment(commissionAmount),
        'lastCommissionAt': FieldValue.serverTimestamp(),
      });

      // 5. Record the commission transaction
      await db.collection('wallet_transactions').add({
        'agentId': agentId,
        'agentName': agentName,
        'userId': userId,
        'customerName': agentFullName,
        'userName': agentFullName,
        'serviceId': _serviceId,
        'serviceName': _serviceName,
        'applicationId': applicationId,
        'amount': commissionAmount,
        'commissionPercentage': commissionPct,
        'serviceFee': amountPaid,
        'type': 'commission',
        'description': 'Commission from $_serviceName',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 6. Stamp the application so Cloud Function skips double-processing
      await db.collection('serviceApplications').doc(applicationId).update({
        'commissionGenerated': true,
        'commissionAgentId': agentId,
        'commissionAgentName': agentName,
        'commissionAmount': commissionAmount,
        'commissionPercentage': commissionPct,
      });

      debugPrint(
          '💰 Commission ₹$commissionAmount credited to agent $agentId ($agentName)');
    } catch (e) {
      // Non-fatal: the application is already saved.
      debugPrint('⚠️ Commission processing error (non-fatal): $e');
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    // Validate required fields — show errors if anything is missing
    if (!_canSubmit) {
      setState(() => _showValidationErrors = true);
      // Build list of missing field names
      final missing = <String>[];
      for (var field in _dynamicFields) {
        if (field['isRequired'] != true && field['required'] != true) continue;
        final name = ((field['fieldName'] ?? field['name']) as dynamic)
                ?.toString()
                .trim() ??
            '';
        final type =
            ((field['fieldType'] ?? field['type']) as String? ?? 'text').trim();
        if (type == 'text' ||
            type == 'number' ||
            type == 'date' ||
            type == 'dob' ||
            type == 'address' ||
            type == 'mobile') {
          if (_textControllers[name]?.text.trim().isEmpty ?? true) {
            missing.add(name);
          }
        } else if (type == 'image' || type == 'pdf' || type == 'document') {
          if (_dynamicFieldValues[name]?.isEmpty ?? true) missing.add(name);
        } else if (type == 'appointment') {
          if (_appointmentDates[name] == null ||
              _appointmentTimes[name] == null) {
            missing.add(name);
          }
        } else if (type == 'time_range') {
          if (_appointmentTimes['${name}_start'] == null ||
              _appointmentTimes['${name}_end'] == null) {
            missing.add(name);
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              missing.isNotEmpty
                  ? 'Please fill in: ${missing.join(', ')}'
                  : 'Please fill in all required fields (*)',
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    // ── Payment check ──────────────────────────────────────────────────────
    bool paymentMade = false;
    if (_serviceFee > 0) {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final walletDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final balanceRaw = walletDoc.data()?['walletBalance'] ?? 0;
      final balance = (balanceRaw is num) ? balanceRaw.toInt() : 0;

      if (balance < _serviceFee) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Insufficient Balance. Please recharge your wallet.'),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final confirmed = await _showPaymentConfirmDialog(balance);
      if (!confirmed) return;
      paymentMade = true;
    }

    try {
      setState(() => _isSubmitting = true);

      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppLocalizations.of(context).get('user_not_authenticated'))),
        );
        return;
      }

      // Build field data from dynamic fields
      Map<String, dynamic> fieldData = {};
      for (var field in _dynamicFields) {
        final fieldName = ((field['fieldName'] ?? field['name']) as dynamic)
                ?.toString()
                .trim() ??
            '';
        final fieldType =
            ((field['fieldType'] ?? field['type']) as String? ?? 'text').trim();

        if (fieldType == 'text' ||
            fieldType == 'number' ||
            fieldType == 'date' ||
            fieldType == 'dob' ||
            fieldType == 'address' ||
            fieldType == 'mobile') {
          final controller = _textControllers[fieldName];
          if (controller != null) {
            fieldData[fieldName] = controller.text.trim();
          }
        } else if (fieldType == 'image' ||
            fieldType == 'pdf' ||
            fieldType == 'document') {
          final value = _dynamicFieldValues[fieldName];
          if (value != null) {
            fieldData[fieldName] = value;
          }
        } else if (fieldType == 'appointment') {
          final date = _appointmentDates[fieldName];
          final time = _appointmentTimes[fieldName];
          if (date != null && time != null) {
            final day = date.day.toString().padLeft(2, '0');
            final month = date.month.toString().padLeft(2, '0');
            final year = date.year.toString();
            final hour = time.hour.toString().padLeft(2, '0');
            final minute = time.minute.toString().padLeft(2, '0');
            fieldData[fieldName] = '$day/$month/$year | $hour:$minute';
          }
        } else if (fieldType == 'time_range') {
          final start = _appointmentTimes['${fieldName}_start'];
          final end = _appointmentTimes['${fieldName}_end'];
          if (start != null && end != null) {
            fieldData[fieldName] =
                '${start.format(context)} - ${end.format(context)}';
          }
        }
        // template: admin-only, skip in user-facing form
      }

      print('✅ Submitting application:');
      print('   Service: $_serviceName ($_serviceId)');
      print('   Fields: $fieldData');

      // Fetch user profile data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();
      final fullName = userData?['fullName'] ?? '';
      final phone = userData?['phone'] ?? '';
      final email = userData?['email'] ?? '';

      // Upload filled form if the user attached one
      String? uploadedFilledFormUrl;
      if (_filledFormBytes != null && _filledFormUrl.isEmpty) {
        // Create a temporary File reference for the upload function (path may be null on some devices)
        final fileToUpload = _filledFormFile ?? File('');
        uploadedFilledFormUrl =
            await _uploadFilledFormToHostinger(fileToUpload);
        if (uploadedFilledFormUrl == null) {
          // Upload failed — show error and stop
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    '❌ Failed to upload your filled form. Please check your internet connection and try again.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }
        setState(() => _filledFormUrl = uploadedFilledFormUrl!);
      } else if (_filledFormUrl.isNotEmpty) {
        uploadedFilledFormUrl = _filledFormUrl;
      }

      // ── Wallet deduction (if payment required) ───────────────────────────
      if (paymentMade) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'walletBalance': FieldValue.increment(-_serviceFee)});
        try {
          await FirebaseFirestore.instance
              .collection('wallet_transactions')
              .add({
            'agentId': user.uid,
            'userId': user.uid,
            'agentName': fullName,
            'serviceId': _serviceId,
            'serviceName': _serviceName,
            'amount': _serviceFee,
            'type': 'service_payment',
            'description': 'Service payment for $_serviceName',
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (txnError) {
          print('⚠️ Could not log wallet transaction: $txnError');
        }
      }

      // Create application document with a unique ID per submission
      final applicationId =
          '${user.uid}_${_serviceId}_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance
          .collection('serviceApplications')
          .doc(applicationId)
          .set({
        'serviceId': _serviceId,
        'serviceName': _serviceName,
        'userId': user.uid,
        'fullName': fullName,
        'phone': phone,
        'email': email,
        'fieldData': fieldData, // Store all dynamic field values
        if (uploadedFilledFormUrl != null && uploadedFilledFormUrl.isNotEmpty)
          'filledFormUrl': uploadedFilledFormUrl,
        'status': 'pending',
        'paymentStatus': paymentMade ? 'paid' : 'free',
        'amountPaid': paymentMade ? _serviceFee : 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Application submitted successfully');

      // ── Commission processing (client-side) ─────────────────────────────
      // Runs immediately after app creation so commission is credited even
      // before the Cloud Function is deployed.
      if (paymentMade) {
        _processReferralCommission(
          userId: user.uid,
          applicationId: applicationId,
          agentFullName: fullName,
          amountPaid: _serviceFee.toDouble(),
        );
      }

      if (mounted) {
        // Show a clear success dialog so the user knows their request was sent
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle,
                      color: Colors.green, size: 48),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Request Submitted!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your request has been sent to the admin.\nThe admin will review and approve your application shortly.',
                  style: TextStyle(
                      fontSize: 14, color: Color(0xFF555555), height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(); // Go back to previous screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(AppLocalizations.of(context).get('ok'),
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('❌ Error submitting application: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: AppLocalizations.of(context).translateText(label),
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Theme.of(context).primaryColor)),
      );

  @override
  Widget build(BuildContext context) {
    // Show form
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: Icon(Icons.arrow_back,
                          color: Theme.of(context)
                                  .extension<CustomColors>()
                                  ?.textSecondary ??
                              Colors.grey.shade700,
                          size: 24),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            AppLocalizations.of(context)
                                .get('service_application'),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                        .extension<CustomColors>()
                                        ?.textPrimary ??
                                    Colors.black87)),
                        Text(
                            AppLocalizations.of(context)
                                .translateText(_serviceName)
                                .toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1A1A),
                              letterSpacing: 0.4,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isLoadingFields)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else ...[
                          // ── Service image ─────────────────────────────────────────
                          if (_serviceLogoUrl.isNotEmpty) ...[
                            Center(
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: Colors.grey.shade100,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    _serviceLogoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          // 📄 Download Form Template card — always show when template exists
                          if (_formTemplateUrl.isNotEmpty &&
                              _formTemplateUrl != 'None') ...[
                            // only when admin uploaded a template
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F4FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFF4C4CFF)
                                        .withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.description_outlined,
                                      color: Color(0xFF4C4CFF), size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'Form Template Available',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1a1a1a),
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Download and fill the template before submitting',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF666666)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () async {
                                      final uri = Uri.parse(_formTemplateUrl);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri,
                                            mode:
                                                LaunchMode.externalApplication);
                                      }
                                    },
                                    icon: const Icon(Icons.download, size: 18),
                                    label: const Text('Download'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF4C4CFF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // 📎 Attach Filled Form — only shown when a template exists
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Attach Filled Form (Optional)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Upload your filled PDF/DOC form if required',
                                    style: TextStyle(
                                        fontSize: 12, color: Color(0xFF666666)),
                                  ),
                                  const SizedBox(height: 10),
                                  if (_filledFormFile != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0F4FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.insert_drive_file,
                                              color: Color(0xFF4C4CFF),
                                              size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _filledFormName.isNotEmpty
                                                  ? _filledFormName
                                                  : (_filledFormFile?.path
                                                          .split(Platform
                                                              .pathSeparator)
                                                          .last ??
                                                      'form_file'),
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF1a1a1a)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => setState(() {
                                              _filledFormFile = null;
                                              _filledFormBytes = null;
                                              _filledFormName = '';
                                              _filledFormUrl = '';
                                            }),
                                            child: const Icon(Icons.close,
                                                size: 18, color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_isUploadingFilledForm)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: LinearProgressIndicator(),
                                      ),
                                  ] else
                                    OutlinedButton.icon(
                                      onPressed: _pickFilledForm,
                                      icon: const Icon(Icons.attach_file,
                                          size: 18),
                                      label:
                                          const Text('Attach Form (PDF / DOC)'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFF4C4CFF),
                                        side: const BorderSide(
                                            color: Color(0xFF4C4CFF)),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Dynamic fields (or empty message if none configured)
                          if (_dynamicFields.isEmpty)
                            Center(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24.0),
                                child: Text(
                                  AppLocalizations.of(context)
                                      .get('no_fields_configured'),
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          else
                            ..._buildDynamicFields(),
                        ],
                        const SizedBox(height: 20),
                        if (_serviceFee > 0) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color:
                                      const Color(0xFF4C4CFF).withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.account_balance_wallet,
                                    color: Color(0xFF4C4CFF), size: 22),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Service Fee',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF666666)),
                                    ),
                                    Text(
                                      '₹$_serviceFee',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF4C4CFF)),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                const Text(
                                  'Will be deducted\nfrom your wallet',
                                  style: TextStyle(
                                      fontSize: 11, color: Color(0xFF888888)),
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _handleSubmit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  AppLocalizations.of(context)
                                      .get('submit_application'),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build dynamic form fields based on admin configuration
  List<Widget> _buildDynamicFields() {
    List<Widget> widgets = [];

    for (int i = 0; i < _dynamicFields.length; i++) {
      final field = _dynamicFields[i];
      // Support both 'fieldName' (service_document_fields) and 'name' (services.documentFields)
      final fieldName = ((field['fieldName'] ?? field['name']) as dynamic)
              ?.toString()
              .trim() ??
          '';
      // Support both 'fieldType' (service_document_fields) and 'type' (services.documentFields)
      final fieldType =
          ((field['fieldType'] ?? field['type']) as String? ?? 'text').trim();
      final placeholder = (field['placeholder'] as String? ?? '').trim();
      // Support both 'isRequired' (service_document_fields) and 'required' (services.documentFields)
      final isRequired =
          field['isRequired'] == true || field['required'] == true;

      // Debug log — helps diagnose type mismatches
      print('FIELD TYPE: $fieldType | NAME: $fieldName');

      // Add field label with required indicator
      widgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: 8.0, top: i == 0 ? 0 : 12),
          child: Text(
            '$fieldName${isRequired ? ' *' : ''}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ),
      );

      // Build field based on type
      if (fieldType == 'template') {
        // Admin-only template field — not rendered in user-facing form
      } else if (fieldType == 'text' || fieldType == 'number') {
        widgets.add(
            _buildTextField(fieldName, fieldType, placeholder, isRequired));
      } else if (fieldType == 'dob') {
        widgets.add(_buildDobField(fieldName, isRequired));
      } else if (fieldType == 'date') {
        widgets.add(_buildDateField(fieldName, isRequired));
      } else if (fieldType == 'address') {
        widgets.add(_buildAddressField(fieldName, placeholder, isRequired));
      } else if (fieldType == 'mobile') {
        widgets.add(_buildMobileField(fieldName, placeholder, isRequired));
      } else if (fieldType == 'image' ||
          fieldType == 'pdf' ||
          fieldType == 'document') {
        widgets.add(_buildFileUploadField(fieldName, fieldType, isRequired));
      } else if (fieldType == 'appointment') {
        widgets.add(_buildAppointmentField(fieldName, isRequired));
      } else if (fieldType == 'time_range') {
        widgets.add(_buildTimeRangeField(fieldName, isRequired));
      } else {
        // Unknown type — fall back to a plain text field so the label is never orphaned
        print(
            '⚠️ Unknown fieldType "$fieldType" for "$fieldName" — rendering as text');
        if (_textControllers[fieldName] == null) {
          _textControllers[fieldName] = TextEditingController();
        }
        widgets
            .add(_buildTextField(fieldName, 'text', placeholder, isRequired));
      }
    }

    return widgets;
  }

  /// Build text/number input field
  Widget _buildTextField(
      String fieldName, String fieldType, String placeholder, bool isRequired) {
    final controller = _textControllers[fieldName];
    if (controller == null) return const SizedBox.shrink();

    return TextFormField(
      controller: controller,
      keyboardType:
          fieldType == 'number' ? TextInputType.number : TextInputType.text,
      onChanged: (_) {
        // Clear validation errors once user starts typing
        if (_showValidationErrors)
          setState(() => _showValidationErrors = false);
      },
      decoration: InputDecoration(
        hintText: placeholder.isNotEmpty ? placeholder : 'Enter $fieldName',
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        // Red border when validation errors shown and field is empty
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: (_showValidationErrors &&
                    isRequired &&
                    (controller.text.trim().isEmpty))
                ? Colors.red.shade600
                : Colors.grey.shade200,
            width: (_showValidationErrors &&
                    isRequired &&
                    controller.text.trim().isEmpty)
                ? 1.5
                : 1.0,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
        errorText: (_showValidationErrors &&
                isRequired &&
                controller.text.trim().isEmpty)
            ? 'This field is required'
            : null,
      ),
    );
  }

  /// Build date-only field (admin field type = 'date')
  Widget _buildDateField(String fieldName, bool isRequired) {
    final controller = _textControllers[fieldName];
    if (controller == null) return const SizedBox.shrink();

    final showError =
        _showValidationErrors && isRequired && controller.text.trim().isEmpty;

    return GestureDetector(
      onTap: () async {
        DateTime initial = DateTime.now();
        try {
          if (controller.text.isNotEmpty) {
            final parts = controller.text.split('/');
            if (parts.length == 3) {
              initial = DateTime(
                int.parse(parts[2]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
            }
          }
        } catch (_) {}
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) {
          final formatted =
              '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
          controller.text = formatted;
          if (mounted) setState(() {});
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFF),
          border: Border.all(
            color: showError ? Colors.red.shade600 : Colors.grey.shade300,
            width: showError ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today,
                size: 16,
                color: controller.text.isNotEmpty
                    ? const Color(0xFF4C4CFF)
                    : Colors.grey.shade500),
            const SizedBox(width: 8),
            Text(
              controller.text.isEmpty ? 'Select Date' : controller.text,
              style: TextStyle(
                fontSize: 14,
                color: controller.text.isNotEmpty
                    ? const Color(0xFF1a1a1a)
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build appointment field — shows date picker + time picker buttons
  Widget _buildAppointmentField(String fieldName, bool isRequired) {
    final selectedDate = _appointmentDates[fieldName];
    final selectedTime = _appointmentTimes[fieldName];
    final bothSelected = selectedDate != null && selectedTime != null;
    final showError = _showValidationErrors &&
        isRequired &&
        (selectedDate == null || selectedTime == null);

    String displayValue = '';
    if (bothSelected) {
      final day = selectedDate.day.toString().padLeft(2, '0');
      final month = selectedDate.month.toString().padLeft(2, '0');
      final year = selectedDate.year.toString();
      final hour = selectedTime.hour.toString().padLeft(2, '0');
      final minute = selectedTime.minute.toString().padLeft(2, '0');
      displayValue = '$day/$month/$year - $hour:$minute';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: showError ? Colors.red.shade600 : Colors.grey.shade200,
              width: showError ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date picker button
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() {
                      _appointmentDates[fieldName] = picked;
                      if (_showValidationErrors) _showValidationErrors = false;
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selectedDate != null
                          ? const Color(0xFF4C4CFF)
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16,
                          color: selectedDate != null
                              ? const Color(0xFF4C4CFF)
                              : Colors.grey.shade500),
                      const SizedBox(width: 8),
                      Text(
                        selectedDate == null
                            ? 'Select Date'
                            : '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}',
                        style: TextStyle(
                          fontSize: 14,
                          color: selectedDate != null
                              ? const Color(0xFF1a1a1a)
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Time picker button
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: selectedTime ?? TimeOfDay.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _appointmentTimes[fieldName] = picked;
                      if (_showValidationErrors) _showValidationErrors = false;
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selectedTime != null
                          ? const Color(0xFF4C4CFF)
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 16,
                          color: selectedTime != null
                              ? const Color(0xFF4C4CFF)
                              : Colors.grey.shade500),
                      const SizedBox(width: 8),
                      Text(
                        selectedTime == null
                            ? 'Select Time'
                            : selectedTime.format(context),
                        style: TextStyle(
                          fontSize: 14,
                          color: selectedTime != null
                              ? const Color(0xFF1a1a1a)
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Combined confirmation row
              if (bothSelected) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Selected: $displayValue',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Please select appointment date and time',
              style: TextStyle(color: Colors.red.shade600, fontSize: 12),
            ),
          ),
      ],
    );
  }

  /// Build date-of-birth field — date picker with lastDate = today
  Widget _buildDobField(String fieldName, bool isRequired) {
    final controller = _textControllers[fieldName];
    if (controller == null) return const SizedBox.shrink();

    final showError =
        _showValidationErrors && isRequired && controller.text.isEmpty;

    return GestureDetector(
      onTap: () async {
        DateTime initial = DateTime.now();
        if (controller.text.isNotEmpty) {
          try {
            final parts = controller.text.split('/');
            if (parts.length == 3) {
              initial = DateTime(
                int.parse(parts[2]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
            }
          } catch (_) {}
        }
        final picked = await showDatePicker(
          context: context,
          initialDate:
              initial.isAfter(DateTime.now()) ? DateTime.now() : initial,
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          final formatted =
              '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
          controller.text = formatted;
          if (mounted) setState(() {});
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              border: Border.all(
                color: showError ? Colors.red.shade600 : Colors.grey.shade300,
                width: showError ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.cake,
                    size: 16,
                    color: controller.text.isNotEmpty
                        ? const Color(0xFF4C4CFF)
                        : Colors.grey.shade500),
                const SizedBox(width: 8),
                Text(
                  controller.text.isEmpty
                      ? 'Select Date of Birth'
                      : controller.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: controller.text.isNotEmpty
                        ? const Color(0xFF1a1a1a)
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          if (showError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Date of birth is required',
                style: TextStyle(color: Colors.red.shade600, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  /// Build address field — multi-line text input
  Widget _buildAddressField(
      String fieldName, String placeholder, bool isRequired) {
    final controller = _textControllers[fieldName];
    if (controller == null) return const SizedBox.shrink();

    final showError =
        _showValidationErrors && isRequired && controller.text.trim().isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: placeholder.isEmpty ? 'Enter address' : placeholder,
            filled: true,
            fillColor: const Color(0xFFF8FAFF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color:
                      showError ? Colors.red.shade600 : Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color:
                      showError ? Colors.red.shade600 : Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF4C4CFF), width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          onChanged: (_) {
            if (_showValidationErrors) setState(() {});
          },
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Address is required',
              style: TextStyle(color: Colors.red.shade600, fontSize: 12),
            ),
          ),
      ],
    );
  }

  /// Build mobile number field — phone keyboard, 10-digit validation
  Widget _buildMobileField(
      String fieldName, String placeholder, bool isRequired) {
    final controller = _textControllers[fieldName];
    if (controller == null) return const SizedBox.shrink();

    final digits = controller.text.trim().replaceAll(RegExp(r'\D'), '');
    final showError = _showValidationErrors &&
        isRequired &&
        (controller.text.trim().isEmpty || digits.length != 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.phone,
          maxLength: 15,
          decoration: InputDecoration(
            hintText: placeholder.isEmpty ? 'Enter mobile number' : placeholder,
            counterText: '',
            prefixIcon: const Icon(Icons.phone, size: 18),
            filled: true,
            fillColor: const Color(0xFFF8FAFF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color:
                      showError ? Colors.red.shade600 : Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color:
                      showError ? Colors.red.shade600 : Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF4C4CFF), width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          onChanged: (_) {
            if (_showValidationErrors) setState(() {});
          },
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              controller.text.trim().isEmpty
                  ? 'Mobile number is required'
                  : 'Enter a valid 10-digit mobile number',
              style: TextStyle(color: Colors.red.shade600, fontSize: 12),
            ),
          ),
      ],
    );
  }

  /// Build time-range field — separate start and end time pickers
  Widget _buildTimeRangeField(String fieldName, bool isRequired) {
    final startTime = _appointmentTimes['${fieldName}_start'];
    final endTime = _appointmentTimes['${fieldName}_end'];
    final bothSelected = startTime != null && endTime != null;
    final showError = _showValidationErrors &&
        isRequired &&
        (startTime == null || endTime == null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: showError ? Colors.red.shade600 : Colors.grey.shade200,
              width: showError ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Start time picker
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: startTime ?? TimeOfDay.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _appointmentTimes['${fieldName}_start'] = picked;
                      if (_showValidationErrors) _showValidationErrors = false;
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: startTime != null
                          ? const Color(0xFF4C4CFF)
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 16,
                          color: startTime != null
                              ? const Color(0xFF4C4CFF)
                              : Colors.grey.shade500),
                      const SizedBox(width: 8),
                      Text(
                        startTime == null
                            ? 'Select Start Time'
                            : 'From: ${startTime.format(context)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: startTime != null
                              ? const Color(0xFF1a1a1a)
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // End time picker
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: endTime ?? TimeOfDay.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _appointmentTimes['${fieldName}_end'] = picked;
                      if (_showValidationErrors) _showValidationErrors = false;
                    });
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: endTime != null
                          ? const Color(0xFF4C4CFF)
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_filled,
                          size: 16,
                          color: endTime != null
                              ? const Color(0xFF4C4CFF)
                              : Colors.grey.shade500),
                      const SizedBox(width: 8),
                      Text(
                        endTime == null
                            ? 'Select End Time'
                            : 'To: ${endTime.format(context)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: endTime != null
                              ? const Color(0xFF1a1a1a)
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (bothSelected) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${startTime!.format(context)} - ${endTime!.format(context)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Please select both start and end time',
              style: TextStyle(color: Colors.red.shade600, fontSize: 12),
            ),
          ),
      ],
    );
  }

  /// Build file upload field (image/pdf/document)
  Widget _buildFileUploadField(
      String fieldName, String fieldType, bool isRequired) {
    final hasFile = _dynamicFieldValues[fieldName] != null;
    final showError = _showValidationErrors && isRequired && !hasFile;

    final container = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: showError ? Colors.red.shade600 : Colors.grey.shade200,
          width: showError ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasFile)
            Row(
              children: [
                Icon(
                  fieldType == 'image'
                      ? Icons.image
                      : fieldType == 'document'
                          ? Icons.attach_file
                          : Icons.picture_as_pdf,
                  color: Theme.of(context).extension<CustomColors>()!.success,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).get('file_uploaded_success'),
                    style: TextStyle(
                        color: Theme.of(context)
                            .extension<CustomColors>()!
                            .success,
                        fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.remove_red_eye,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                  onPressed: () {
                    final imageUrl = _dynamicFieldValues[fieldName];
                    if (imageUrl != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => _ImagePreviewScreen(
                            imageUrl: imageUrl,
                            fieldName: fieldName,
                          ),
                        ),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() {
                      _dynamicFieldValues.remove(fieldName);
                    });
                  },
                ),
              ],
            )
          else
            ElevatedButton.icon(
              onPressed: _uploadingFields.contains(fieldName)
                  ? null
                  : () => _pickAndUploadFile(fieldName, fieldType),
              icon: _uploadingFields.contains(fieldName)
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(fieldType == 'image'
                      ? Icons.camera_alt
                      : fieldType == 'document'
                          ? Icons.attach_file
                          : Icons.upload_file),
              label: Text(_uploadingFields.contains(fieldName)
                  ? AppLocalizations.of(context).get('uploading')
                  : fieldType == 'image'
                      ? AppLocalizations.of(context).get('upload_image')
                      : fieldType == 'document'
                          ? 'Upload Document'
                          : AppLocalizations.of(context).get('upload_pdf')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        container,
        if (showError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'This field is required',
              style: TextStyle(color: Colors.red.shade600, fontSize: 12),
            ),
          ),
      ],
    );
  }

  /// Pick and upload file to Hostinger
  Future<void> _pickAndUploadFile(String fieldName, String fieldType) async {
    try {
      final ImagePicker picker = ImagePicker();

      // Show bottom sheet to choose Camera or Gallery
      ImageSource? source;
      if (fieldType == 'image') {
        source = await showModalBottomSheet<ImageSource>(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.camera_alt),
                    title: Text(AppLocalizations.of(context).get('camera')),
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: Text(AppLocalizations.of(context).get('gallery')),
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                ],
              ),
            ),
          ),
        );
        if (source == null) return;
      }

      XFile? file;
      if (fieldType == 'image') {
        file = await picker.pickImage(
          source: source!,
          imageQuality: 70, // Compress to avoid large uploads crashing/hanging
          maxWidth: 1280,
          maxHeight: 1280,
        );
      } else if (fieldType == 'pdf' || fieldType == 'document') {
        final extensions =
            fieldType == 'document' ? ['pdf', 'doc', 'docx'] : ['pdf'];
        final pickerResult = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: extensions,
          withData: false,
        );
        if (pickerResult == null || pickerResult.files.isEmpty) return;
        final pickedFile = pickerResult.files.first;
        if (pickedFile.path == null) return;
        file = XFile(pickedFile.path!);
      }

      if (file == null) return;

      // Show inline loading state — avoids Navigator.pop issues when camera
      // reopens the activity on Android (which would pop the wrong route)
      if (mounted) setState(() => _uploadingFields.add(fieldName));

      String? uploadedUrl;
      try {
        // Upload to Hostinger with timeout
        uploadedUrl = await _uploadImageToHostinger(file, fieldName)
            .timeout(const Duration(seconds: 60));
      } catch (uploadError) {
        print('❌ Upload error: $uploadError');
        uploadedUrl = null;
      } finally {
        if (mounted) setState(() => _uploadingFields.remove(fieldName));
      }

      if (!mounted) return;

      if (uploadedUrl != null) {
        setState(() {
          _dynamicFieldValues[fieldName] = uploadedUrl!;
          _showValidationErrors = false; // clear errors once a file is picked
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context).get('file_upload_success_snack')),
            backgroundColor:
                Theme.of(context).extension<CustomColors>()!.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context).get('upload_failed_retry')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      print('❌ Error picking/uploading file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Dispose all dynamic text controllers
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

// Image preview screen
class _ImagePreviewScreen extends StatelessWidget {
  final String imageUrl;
  final String fieldName;

  const _ImagePreviewScreen({
    required this.imageUrl,
    required this.fieldName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          fieldName,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        color: Theme.of(context).colorScheme.error, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context).get('failed_to_load_cert'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
