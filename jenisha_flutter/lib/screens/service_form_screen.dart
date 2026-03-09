import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Dynamic fields from admin panel
  List<Map<String, dynamic>> _dynamicFields = [];
  Map<String, TextEditingController> _textControllers = {};
  Map<String, String> _dynamicFieldValues =
      {}; // Store all field values including images

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
          if (sData != null && sData['formTemplateUrl'] != null) {
            setState(() {
              _formTemplateUrl = sData['formTemplateUrl'] as String? ?? '';
            });
            print('✅ Form template URL loaded: $_formTemplateUrl');
          }
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
              final fieldName = field['fieldName'] as String? ?? '';
              final fieldType = field['fieldType'] as String? ?? 'text';

              if (fieldType == 'text' || fieldType == 'number') {
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
      final isRequired = field['isRequired'] == true;
      if (!isRequired) continue;

      final fieldName = field['fieldName'] as String? ?? '';
      final fieldType = field['fieldType'] as String? ?? 'text';

      if (fieldType == 'text' || fieldType == 'number') {
        final controller = _textControllers[fieldName];
        if (controller == null || controller.text.trim().isEmpty) {
          return false;
        }
      } else if (fieldType == 'image' || fieldType == 'pdf') {
        final value = _dynamicFieldValues[fieldName];
        if (value == null || value.isEmpty) {
          return false;
        }
      }
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

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    // Validate required fields — show errors if anything is missing
    if (!_canSubmit) {
      setState(() => _showValidationErrors = true);
      // Build list of missing field names
      final missing = <String>[];
      for (var field in _dynamicFields) {
        if (field['isRequired'] != true) continue;
        final name = field['fieldName'] as String? ?? '';
        final type = field['fieldType'] as String? ?? 'text';
        if (type == 'text' || type == 'number') {
          if (_textControllers[name]?.text.trim().isEmpty ?? true) {
            missing.add(name);
          }
        } else if (type == 'image' || type == 'pdf') {
          if (_dynamicFieldValues[name]?.isEmpty ?? true) missing.add(name);
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
        final fieldName = field['fieldName'] as String? ?? '';
        final fieldType = field['fieldType'] as String? ?? 'text';

        if (fieldType == 'text' || fieldType == 'number') {
          final controller = _textControllers[fieldName];
          if (controller != null) {
            fieldData[fieldName] = controller.text.trim();
          }
        } else if (fieldType == 'image' || fieldType == 'pdf') {
          final value = _dynamicFieldValues[fieldName];
          if (value != null) {
            fieldData[fieldName] = value;
          }
        }
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
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Application submitted successfully');

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
                                .translateText(_serviceName),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600)),
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
                          // 📄 Download Form Template card — always show when template exists
                          if (_formTemplateUrl.isNotEmpty) ...[
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
                          // 📎 Attach Filled Form section
                          const SizedBox(height: 16),
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
                                            color: Color(0xFF4C4CFF), size: 20),
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
                                    icon:
                                        const Icon(Icons.attach_file, size: 18),
                                    label:
                                        const Text('Attach Form (PDF / DOC)'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF4C4CFF),
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
                        ],
                        const SizedBox(height: 20),
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
      final fieldName = field['fieldName'] as String? ?? '';
      final fieldType = field['fieldType'] as String? ?? 'text';
      final placeholder = field['placeholder'] as String? ?? '';
      final isRequired = field['isRequired'] == true;

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
      if (fieldType == 'text' || fieldType == 'number') {
        widgets.add(
            _buildTextField(fieldName, fieldType, placeholder, isRequired));
      } else if (fieldType == 'image' || fieldType == 'pdf') {
        widgets.add(_buildFileUploadField(fieldName, fieldType, isRequired));
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

  /// Build file upload field (image/pdf)
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
        children: [
          if (hasFile)
            Row(
              children: [
                Icon(
                  fieldType == 'image' ? Icons.image : Icons.picture_as_pdf,
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
                      : Icons.upload_file),
              label: Text(_uploadingFields.contains(fieldName)
                  ? AppLocalizations.of(context).get('uploading')
                  : fieldType == 'image'
                      ? AppLocalizations.of(context).get('upload_image')
                      : AppLocalizations.of(context).get('upload_pdf')),
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
      } else {
        // For PDF, we'll use image picker for now (you may need a file picker package)
        file = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 70,
          maxWidth: 1280,
          maxHeight: 1280,
        );
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
