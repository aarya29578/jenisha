import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import 'document_upload_widget.dart';
import '../theme/app_theme.dart';

class RegistrationDocumentsScreen extends StatefulWidget {
  const RegistrationDocumentsScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationDocumentsScreen> createState() =>
      _RegistrationDocumentsScreenState();
}

class _RegistrationDocumentsScreenState
    extends State<RegistrationDocumentsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  Map<String, dynamic>? _applicationData;
  bool _isLoading = true;

  // Streams initialized once, not recreated on rebuild
  Stream<Map<String, dynamic>>? _userDocumentsStream;
  Stream<List<Map<String, dynamic>>>? _documentRequirementsStream;

  @override
  void initState() {
    super.initState();
    _loadApplication();
  }

  Future<void> _loadApplication() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      // Get application data from navigation arguments or create placeholder
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null &&
          args.containsKey('serviceId') &&
          args.containsKey('applicationId')) {
        setState(() {
          _applicationData = args;
          _isLoading = false;
          // Initialize streams ONCE after data is loaded
          _initializeStreams(user.uid, args['serviceId'] as String);
        });
      } else {
        // Fallback: create a basic structure
        setState(() {
          _applicationData = {
            'id': '${user.uid}_default',
            'serviceId': 'default_service',
          };
          _isLoading = false;
          // Initialize streams ONCE after data is loaded
          _initializeStreams(user.uid, 'default_service');
        });
      }
    } catch (e) {
      print('Error loading application: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializeStreams(String userId, String serviceId) {
    print('🔄 [STREAMS] Initializing streams ONCE');
    print('   - userId: $userId');
    print('   - serviceId: $serviceId');

    // Create streams ONCE, they will not be recreated on rebuild
    _userDocumentsStream = _firestoreService.getUserDocumentsStream(userId);
    _documentRequirementsStream =
        _firestoreService.getDocumentRequirementsForService(serviceId);

    print('✅ [STREAMS] Streams initialized');
  }

  // Callback for upload completion (optional - Firestore write happens in widget)
  void _handleUploadSuccess(
      String documentId, String imageUrl, String documentName) {
    print('✅ [PARENT NOTIFIED] Document "$documentName" uploaded');
    // No Firestore write needed here - widget handles it
  }

  @override
  Widget build(BuildContext context) {
    final applicationId = _applicationData?['id'] as String?;
    final serviceId = _applicationData?['serviceId'] as String?;
    final user = FirebaseAuth.instance.currentUser;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Upload Documents'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (applicationId == null || serviceId == null || user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Upload Documents'),
        ),
        body: const Center(child: Text('No application found')),
      );
    }

    print('🏗️ [PARENT BUILD] Building with userId: ${user.uid}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Required Documents'),
      ),
      body: _userDocumentsStream == null || _documentRequirementsStream == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<Map<String, dynamic>>(
              // ✅ Use stream initialized ONCE in initState, not recreated
              stream: _userDocumentsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.hasError}'));
                }

                // FIRESTORE SINGLE SOURCE OF TRUTH - no local state overlay
                final uploadedDocs = snapshot.data ?? {};
                print(
                    '🗄️  [FIRESTORE STATE] Loaded ${uploadedDocs.length} uploaded documents from Firestore');

                return StreamBuilder<List<Map<String, dynamic>>>(
                  // ✅ Use stream initialized ONCE in initState, not recreated
                  stream: _documentRequirementsStream,
                  builder: (context, reqSnapshot) {
                    if (reqSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (reqSnapshot.hasError) {
                      return Center(child: Text('Error: ${reqSnapshot.error}'));
                    }

                    final documentRequirements = reqSnapshot.data ?? [];

                    if (documentRequirements.isEmpty) {
                      return const Center(
                        child: Text('No document requirements found'),
                      );
                    }

                    final requiredDocs = documentRequirements
                        .where((doc) => doc['photoRequired'] == true)
                        .toList();

                    final optionalDocs = documentRequirements
                        .where((doc) => doc['photoRequired'] != true)
                        .toList();

                    final allRequiredUploaded = requiredDocs.every((req) {
                      final docId = req['id'] as String?;
                      if (docId == null) return false;

                      final uploaded = uploadedDocs[docId];
                      final imageUrl = uploaded?['imageUrl'] as String?;
                      return imageUrl != null && imageUrl.isNotEmpty;
                    });

                    print(
                        '📋 [MATCHING LOGIC] Required docs: ${requiredDocs.length}, Uploaded in Firestore: ${uploadedDocs.length}');
                    print('   All required uploaded: $allRequiredUploaded');

                    return Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              if (requiredDocs.isNotEmpty) ...[
                                const Text(
                                  'Required Documents',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...requiredDocs.map((req) {
                                  final docId = req['id'] as String;
                                  final docName =
                                      req['documentName'] ?? 'Unknown';
                                  final found = uploadedDocs.containsKey(docId);

                                  print(
                                      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
                                  print('🔍 [MATCHING]');
                                  print('   UI Expecting ID: "$docId"');
                                  print('   Document Name: "$docName"');
                                  print(
                                      '   Found in Firestore: ${found ? "✅ YES" : "❌ NO"}');

                                  if (found) {
                                    final uploadedDoc = uploadedDocs[docId];
                                    print('   Match Details:');
                                    print(
                                        '     - imageUrl: ${uploadedDoc?['imageUrl']}');
                                    print(
                                        '     - status: ${uploadedDoc?['status']}');
                                    print(
                                        '     - uploadedAt: ${uploadedDoc?['uploadedAt']}');
                                  } else {
                                    print(
                                        '   ⚠️  MISMATCH: UI looking for "$docId" but not in Firestore uploadedDocs');
                                    print(
                                        '   Available Firestore IDs: ${uploadedDocs.keys.toList()}');
                                  }
                                  print(
                                      '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: DocumentUploadWidget(
                                      key: ValueKey('doc_$docId'),
                                      documentRequirement: req,
                                      userId: user.uid,
                                      existingImage: uploadedDocs[docId],
                                      onUploaded: (docId, imageUrl) {
                                        _handleUploadSuccess(docId, imageUrl,
                                            req['documentName']);
                                      },
                                    ),
                                  );
                                }).toList(),
                              ],
                              if (optionalDocs.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                const Text(
                                  'Optional Documents',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...optionalDocs.map((req) {
                                  final docId = req['id'] as String;
                                  print(
                                      '🔍 UI EXPECTING ID (optional) = $docId (looking in uploadedDocs)');
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: DocumentUploadWidget(
                                      key: ValueKey('doc_$docId'),
                                      documentRequirement: req,
                                      userId: user.uid,
                                      existingImage: uploadedDocs[docId],
                                      onUploaded: (docId, imageUrl) {
                                        _handleUploadSuccess(docId, imageUrl,
                                            req['documentName']);
                                      },
                                    ),
                                  );
                                }).toList(),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            child: ElevatedButton(
                              onPressed: allRequiredUploaded
                                  ? () {
                                      Navigator.pushReplacementNamed(
                                          context, '/registration-status');
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: allRequiredUploaded
                                    ? Colors.indigo
                                    : Colors.grey,
                              ),
                              child: const Text(
                                'Submit Application',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}
