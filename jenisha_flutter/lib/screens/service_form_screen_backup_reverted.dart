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
  final _fullName = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _serviceId = '';
  String _serviceName = '';
  List<Map<String, dynamic>> _documentRequirements = [];

  /// Track uploaded documents: documentId -> imageUrl (legacy support)
  Map<String, String> _uploadedDocuments = {};
  bool _isSubmitting = false;
  bool _hasInitialized = false;
  bool _isCheckingApplication = true;
  String? _existingApplicationStatus;
  Map<String, dynamic>? _existingApplication;

  @override
  void initState() {
    super.initState();

    // Add listeners to text fields to trigger rebuild
    _fullName.addListener(() {
      setState(() {});
    });
    _mobile.addListener(() {
      setState(() {});
    });
    _email.addListener(() {
      setState(() {});
    });

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
        });

        final newCount = _uploadedDocuments.length;
        if (newCount > previousCount) {
          print(
              '✅ Document uploaded detected. Previous: $previousCount, Now: $newCount');
        }
      }
    });
  }

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
    final hasName = _fullName.text.trim().isNotEmpty;
    final hasMobile = _mobile.text.trim().isNotEmpty;

    final canSubmit = hasName && hasMobile;

    print(
        '🔵 [SUBMIT CHECK] Name: $hasName, Mobile: $hasMobile, CanSubmit: $canSubmit');

    return canSubmit;
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
      print('   Customer: ${_fullName.text}');
      print('   Mobile: ${_mobile.text}');

      // Create application document
      final applicationId = '${user.uid}_$_serviceId';
      await FirebaseFirestore.instance
          .collection('applications')
          .doc(applicationId)
          .set({
        'serviceId': _serviceId,
        'serviceName': _serviceName,
        'userId': user.uid,
        'fullName': _fullName.text.trim(),
        'mobile': _mobile.text.trim(),
        'email': _email.text.trim(),
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      // Update user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'documentsCompleted': true,
        'fullName': _fullName.text.trim(),
        'phone': _mobile.text.trim(),
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
                        const Text('Customer Details',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151))),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: _fullName,
                            decoration: _inputDecoration('Full Name *')),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: _mobile,
                            keyboardType: TextInputType.phone,
                            decoration: _inputDecoration('Mobile Number *')),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration('Email (Optional)')),
                        const SizedBox(height: 20),
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
    _fullName.dispose();
    _mobile.dispose();
    _email.dispose();
    super.dispose();
  }
}
