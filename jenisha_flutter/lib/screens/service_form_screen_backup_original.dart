import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/firestore_service.dart';
import 'document_upload_widget.dart';

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
  List<Map<String, dynamic>> _documentRequirements = [];

  /// NEW: Dynamic document fields from Firestore
  List<Map<String, dynamic>> _dynamicFields = [];

  /// Track field values by field ID
  /// For text/number/date: stores the value directly
  /// For image/pdf: stores the uploaded URL
  Map<String, dynamic> _fieldValues = {};

  /// Track text field controllers for dynamic text inputs
  Map<String, TextEditingController> _fieldControllers = {};

  /// Track uploaded documents: documentId -> imageUrl (legacy support)
  Map<String, String> _uploadedDocuments = {};
  bool _isSubmitting = false;
  bool _hasInitialized = false;
  bool _isCheckingApplication = true;
  String? _existingApplicationStatus;
  Map<String, dynamic>? _existingApplication;

  // Helper to check if fields list has changed
  bool _fieldsHaveChanged(List<Map<String, dynamic>> oldFields,
      List<Map<String, dynamic>> newFields) {
    if (oldFields.length != newFields.length) return true;
    for (int i = 0; i < oldFields.length; i++) {
      if (oldFields[i]['id'] != newFields[i]['id'] ||
          oldFields[i]['name'] != newFields[i]['name'] ||
          oldFields[i]['type'] != newFields[i]['type']) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();

    // Start monitoring uploaded documents after screen loads
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _startMonitoringDocuments();
      }
    });
  }

  void _startMonitoringDocuments() {
    final user = _auth.currentUser;
    if (user == null) return;

    print('🔍 Starting document monitoring for user: ${user.uid}');

    // Listen to user document changes in real-time
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        final documents = data['documents'] as Map<String, dynamic>? ?? {};

        final previousCount = _uploadedDocuments.length;

        setState(() {
          _uploadedDocuments.clear();
          // Count only required documents that have URLs
          for (var req in _documentRequirements) {
            if (req['required'] == true) {
              final docId = req['id'] ?? '';
              final url = documents[docId];
              if (url != null && url.toString().isNotEmpty) {
                _uploadedDocuments[docId] = url.toString();
              }
            }
          }

          final requiredCount =
              _documentRequirements.where((d) => d['required'] == true).length;
          print(
              '✅ Document monitor: ${_uploadedDocuments.length} / $requiredCount uploaded');

          if (_uploadedDocuments.length != previousCount) {
            print(
                '📄 Upload count changed from $previousCount to ${_uploadedDocuments.length}');
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasInitialized) return; // Prevent repeated initialization

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _serviceId = args['serviceId'] ?? '';
      _serviceName = args['serviceName'] ?? 'Service';
      print('✅ ServiceFormScreen initialized:');
      print('   serviceId: "$_serviceId"');
      print('   serviceName: "$_serviceName"');
      if (_serviceId.isEmpty) {
        print('   ⚠️ WARNING: serviceId is empty!');
      }

      // Check if user already has an application for this service
      _checkExistingApplication();
    } else {
      print('❌ No arguments passed to ServiceFormScreen');
    }
    _hasInitialized = true;
  }

  Future<void> _checkExistingApplication() async {
    final user = _auth.currentUser;
    if (user == null || _serviceId.isEmpty) {
      setState(() => _isCheckingApplication = false);
      return;
    }

    try {
      final applicationId = '${user.uid}_$_serviceId';
      final appDoc = await FirebaseFirestore.instance
          .collection('serviceApplications')
          .doc(applicationId)
          .get();

      if (appDoc.exists) {
        final data = appDoc.data();
        final status = data?['status'] as String? ?? 'pending';

        print('📄 Existing application found:');
        print('   Status: $status');
        print('   Can resubmit: ${status == 'rejected'}');

        setState(() {
          _existingApplication = data;
          _existingApplicationStatus = status;
          _isCheckingApplication = false;
        });
      } else {
        print('✅ No existing application - user can submit new');
        setState(() => _isCheckingApplication = false);
      }
    } catch (e) {
      print('❌ Error checking existing application: $e');
      setState(() => _isCheckingApplication = false);
    }
  }

  bool get _canSubmit {
    // Check all required dynamic fields are filled
    bool allRequiredFieldsFilled = true;
    for (var field in _dynamicFields) {
      final isRequired = field['required'] == true;
      if (isRequired) {
        final fieldId = field['id'] as String? ?? '';
        final value = _fieldValues[fieldId];
        if (value == null || value.toString().trim().isEmpty) {
          allRequiredFieldsFilled = false;
          break;
        }
      }
    }

    print('🔵 [SUBMIT CHECK] Required fields filled: $allRequiredFieldsFilled');

    return allRequiredFieldsFilled;
  }

  void _updateUploadedCount() {
    // Now handled by _startMonitoringDocuments() stream
    print('🔄 Upload complete callback triggered');
  }

  Future<void> _handleSubmit() async {
    if (!_canSubmit || _isSubmitting) return;

    try {
      setState(() => _isSubmitting = true);

      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      print('✅ Submitting application:');
      print('   Service: $_serviceName ($_serviceId)');
      print('   Field values: $_fieldValues');

      // Create application document with dynamic field values ONLY
      final applicationId = '${user.uid}_$_serviceId';
      await FirebaseFirestore.instance
          .collection('applications')
          .doc(applicationId)
          .set({
        'serviceId': _serviceId,
        'serviceName': _serviceName,
        'userId': user.uid,
        'documents': _fieldValues, // All field values (text or image URLs)
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      // Update user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'documentsCompleted': true,
      });

      print('✅ Application submitted successfully to applications collection');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to home
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } catch (e) {
      print('❌ Error submitting: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF5b47c7))),
      );

  // Build dynamic field UI based on type
  Widget _buildDynamicField({
    required String fieldId,
    required String fieldName,
    required String fieldType,
    required bool isRequired,
    required String placeholder,
  }) {
    switch (fieldType) {
      case 'text':
      case 'number':
      case 'date':
        return _buildTextInputField(
          fieldId: fieldId,
          fieldName: fieldName,
          fieldType: fieldType,
          isRequired: isRequired,
          placeholder: placeholder,
        );

      case 'image':
      case 'pdf':
        return _buildFileUploadField(
          fieldId: fieldId,
          fieldName: fieldName,
          fieldType: fieldType,
          isRequired: isRequired,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // Build text/number/date input field
  Widget _buildTextInputField({
    required String fieldId,
    required String fieldName,
    required String fieldType,
    required bool isRequired,
    required String placeholder,
  }) {
    final controller = _fieldControllers[fieldId];
    if (controller == null) return const SizedBox.shrink();

    TextInputType keyboardType = TextInputType.text;
    if (fieldType == 'number') keyboardType = TextInputType.number;
    if (fieldType == 'date') keyboardType = TextInputType.datetime;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _inputDecoration(
        '$fieldName${isRequired ? ' *' : ''}',
      ).copyWith(
        hintText: placeholder.isNotEmpty ? placeholder : null,
      ),
    );
  }

  // Build image/PDF upload field with Hostinger upload
  Widget _buildFileUploadField({
    required String fieldId,
    required String fieldName,
    required String fieldType,
    required bool isRequired,
  }) {
    final uploadedUrl = _fieldValues[fieldId] as String?;
    final hasFile = uploadedUrl != null && uploadedUrl.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                fieldType == 'image' ? Icons.image : Icons.picture_as_pdf,
                size: 20,
                color: const Color(0xFF5b47c7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$fieldName${isRequired ? ' *' : ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              if (hasFile)
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasFile)
            ElevatedButton.icon(
              onPressed: () => _pickAndUploadFile(fieldId, fieldType),
              icon: const Icon(Icons.upload, size: 18),
              label: Text('Upload ${fieldType == 'image' ? 'Image' : 'PDF'}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5b47c7),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            )
          else
            Column(
              children: [
                if (fieldType == 'image')
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      uploadedUrl,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 120,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.error, color: Colors.red),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Uploaded successfully',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _pickAndUploadFile(fieldId, fieldType),
                      child:
                          const Text('Change', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  // Pick and upload file to Hostinger
  Future<void> _pickAndUploadFile(String fieldId, String fieldType) async {
    try {
      final ImagePicker picker = ImagePicker();

      // Pick image or file
      XFile? pickedFile;
      if (fieldType == 'image') {
        pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
      } else {
        // For PDF, use pickImage with gallery (limited support)
        // In production, you might want to use file_picker package for better PDF support
        pickedFile = await picker.pickImage(source: ImageSource.gallery);
      }

      if (pickedFile == null) {
        print('📷 User cancelled file selection');
        return;
      }

      print('📤 Uploading file to Hostinger...');
      print('   Field ID: $fieldId');
      print('   File: ${pickedFile.name}');

      if (!mounted) return;

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading file...'),
          duration: Duration(seconds: 30),
        ),
      );

      // Upload to Hostinger PHP endpoint
      const uploadUrl =
          'https://cyan-llama-839264.hostingersite.com/uploads/upload_document.php';

      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.files.add(
        await http.MultipartFile.fromPath(
          'document', // PHP expects 'document' key
          pickedFile.path,
          filename: pickedFile.name,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Upload response: ${response.statusCode}');
      print('   Body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Upload failed with status ${response.statusCode}');
      }

      final jsonResponse = json.decode(response.body);

      if (jsonResponse['success'] != true || jsonResponse['imageUrl'] == null) {
        throw Exception(
            jsonResponse['error'] ?? 'Upload failed: No image URL returned');
      }

      final imageUrl = jsonResponse['imageUrl'] as String;

      print('✅ File uploaded successfully: $imageUrl');

      // Save URL to field values
      setState(() {
        _fieldValues[fieldId] = imageUrl;
      });

      if (!mounted) return;

      // Hide loading and show success
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File uploaded successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error uploading file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking for existing application
    if (_isCheckingApplication) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF6852D6),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title:
              Text(_serviceName, style: const TextStyle(color: Colors.white)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show status screen if application already exists (pending or approved)
    // If rejected, show rejection screen but allow resubmission below
    if (_existingApplicationStatus != null &&
        _existingApplicationStatus != 'rejected') {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF6852D6),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title:
              Text(_serviceName, style: const TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _existingApplicationStatus == 'approved'
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFF4E6),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _existingApplicationStatus == 'approved'
                        ? Icons.check_circle
                        : Icons.schedule,
                    size: 48,
                    color: _existingApplicationStatus == 'approved'
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF9800),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _existingApplicationStatus == 'approved'
                      ? 'Application Approved!'
                      : 'Application Under Review',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _existingApplicationStatus == 'approved'
                      ? 'Your $_serviceName application has been approved by admin. You can now proceed with the service.'
                      : 'Your $_serviceName application is currently being reviewed by admin. You will be notified once it is approved.',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Show certificate if available
                if (_existingApplicationStatus == 'approved' &&
                    _existingApplication?['certificateUrl'] != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.workspace_premium,
                                color: Color(0xFF4CAF50), size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Your Certificate',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _existingApplication!['certificateUrl'],
                            fit: BoxFit.contain,
                            width: double.infinity,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 200,
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                alignment: Alignment.center,
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error_outline,
                                        color: Color(0xFFEF5350), size: 48),
                                    SizedBox(height: 8),
                                    Text('Failed to load certificate'),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Open certificate in browser for download
                            // You can use url_launcher package here
                          },
                          icon: const Icon(Icons.download, size: 20),
                          label: const Text('Download Certificate'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context, '/home', (route) => false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5b47c7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 48, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Go to Home',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show form if no application or if rejected
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
                    child: const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: Icon(Icons.arrow_back,
                          color: Color(0xFF374151), size: 24),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Service Application',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827))),
                        Text(_serviceName,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Show rejection banner if application was rejected
            if (_existingApplicationStatus == 'rejected')
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  border: Border.all(color: const Color(0xFFEF5350)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFD32F2F), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Application Rejected',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD32F2F),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _existingApplication?['rejectionReason']
                                    as String? ??
                                'Your previous application was rejected. Please correct the issues and resubmit.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                            ),
                          ),
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
                        const SizedBox(height: 4),
                        // Display dynamic document fields from services/{serviceId}/documentFields
                        if (_serviceId.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Service Requirements',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827))),
                              const SizedBox(height: 4),
                              const Text(
                                  'Please fill in all required information below',
                                  style: TextStyle(
                                      fontSize: 13, color: Color(0xFF666666))),
                              const SizedBox(height: 16),
                              StreamBuilder<List<Map<String, dynamic>>>(
                                stream: _firestoreService
                                    .getServiceDocumentFieldsStream(_serviceId),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    print(
                                        '📋 Dynamic fields: Loading (serviceId: $_serviceId)...');
                                    return const Center(
                                      child: SizedBox(
                                        height: 40,
                                        width: 40,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  }

                                  if (snapshot.hasError) {
                                    print(
                                        '❌ Error loading dynamic fields: ${snapshot.error}');
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFFFEEEE),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Text(
                                          'Error loading fields: ${snapshot.error}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF9F1239))),
                                    );
                                  }

                                  final fields = snapshot.data ?? [];

                                  // Only update state if fields actually changed (prevents infinite loop)
                                  if (_fieldsHaveChanged(
                                      _dynamicFields, fields)) {
                                    // Schedule update after current frame to avoid calling setState during build
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      if (mounted) {
                                        setState(() {
                                          _dynamicFields = fields;
                                        });
                                      }
                                    });
                                  }

                                  // Initialize controllers for NEW text fields only (without triggering rebuild)
                                  for (var field in fields) {
                                    final fieldId =
                                        field['id'] as String? ?? '';
                                    final fieldType =
                                        field['type'] as String? ?? 'text';

                                    if ((fieldType == 'text' ||
                                            fieldType == 'number' ||
                                            fieldType == 'date') &&
                                        !_fieldControllers
                                            .containsKey(fieldId)) {
                                      _fieldControllers[fieldId] =
                                          TextEditingController();
                                      _fieldControllers[fieldId]!
                                          .addListener(() {
                                        // Update field value and trigger validation check
                                        setState(() {
                                          _fieldValues[fieldId] =
                                              _fieldControllers[fieldId]!.text;
                                        });
                                      });
                                    }
                                  }

                                  if (fields.isEmpty) {
                                    print(
                                        '⚠️ No dynamic fields defined for serviceId: $_serviceId');
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFEEF6FF),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: const Text(
                                          'No documents required for this service',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF374151))),
                                    );
                                  }

                                  print(
                                      '✅ Rendering ${fields.length} dynamic fields');

                                  // Render dynamic fields based on type
                                  return Column(
                                    children: fields.map<Widget>((field) {
                                      final fieldId =
                                          field['id'] as String? ?? '';
                                      final fieldName =
                                          field['name'] as String? ?? 'Field';
                                      final fieldType =
                                          field['type'] as String? ?? 'text';
                                      final isRequired =
                                          field['required'] == true;
                                      final placeholder =
                                          field['placeholder'] as String? ?? '';

                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 16),
                                        child: _buildDynamicField(
                                          fieldId: fieldId,
                                          fieldName: fieldName,
                                          fieldType: fieldType,
                                          isRequired: isRequired,
                                          placeholder: placeholder,
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                            ],
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: const Color(0xFFFFEEEE),
                                borderRadius: BorderRadius.circular(8)),
                            child: const Text('Unable to load service details',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF9F1239))),
                          ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: (_canSubmit && !_isSubmitting)
                              ? _handleSubmit
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5b47c7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
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
                              : const Text('Submit Application',
                                  style: TextStyle(
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

  @override
  void dispose() {
    // Dispose dynamic field controllers
    for (var controller in _fieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
