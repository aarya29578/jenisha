import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_storage_service.dart';

class SimpleDocumentUpload extends StatefulWidget {
  final String documentId;
  final String documentName;
  final String serviceId;
  final VoidCallback onUploadComplete;

  const SimpleDocumentUpload({
    Key? key,
    required this.documentId,
    required this.documentName,
    required this.serviceId,
    required this.onUploadComplete,
  }) : super(key: key);

  @override
  State<SimpleDocumentUpload> createState() => _SimpleDocumentUploadState();
}

class _SimpleDocumentUploadState extends State<SimpleDocumentUpload>
    with AutomaticKeepAliveClientMixin {
  final _imagePicker = ImagePicker();
  final _storageService = FirebaseStorageService();

  bool _isUploading = false;
  File? _selectedFile;
  String? _errorMessage;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    super.dispose();
  }

  /// Stream to listen to Firestore for uploaded imageUrl
  Stream<String?> _getImageUrlStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(null);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('documents')
        .doc(widget.documentId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data();
      final url = data?['imageUrl'] as String?;
      if (url != null && url.isNotEmpty) {
        print('📖 [FIRESTORE READ] ${widget.documentId}: $url');
      }
      return url;
    });
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    if (!mounted) return;

    print('🔵 [EDIT] _pickAndUpload called with source: $source');

    try {
      print('🔵 [EDIT] Opening image picker...');
      final pickedFile = await _imagePicker.pickImage(source: source);

      if (pickedFile == null) {
        print('⚠️ [EDIT] User cancelled image selection');
        return;
      }

      print('✅ [EDIT] Image selected: ${pickedFile.path}');

      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ [EDIT] User not authenticated');
        if (!mounted) return;
        setState(() => _errorMessage = 'User not authenticated');
        return;
      }

      print('🔵 [EDIT] Starting upload for user: ${user.uid}');

      if (!mounted) return;
      setState(() {
        _isUploading = true;
        _errorMessage = null;
      });

      // Create Firestore document BEFORE upload (imageUrl empty, status pending)
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .doc(widget.documentId);

      print('🔵 [EDIT] Updating Firestore status to pending...');
      await docRef.set({
        'name': widget.documentName,
        'imageUrl': '',
        'status': 'pending',
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      // Prepare file and upload
      final file = File(pickedFile.path);

      print('🔵 [EDIT] Uploading to backend...');
      final downloadUrl = await _storageService.uploadDocumentImage(
        file: file,
        userId: user.uid,
        serviceId: widget.serviceId,
        documentId: widget.documentId,
      );

      if (!mounted) return;

      if (downloadUrl == null) {
        print('❌ [EDIT] Upload failed - no URL returned');
        setState(() {
          _isUploading = false;
          _errorMessage = 'Upload failed';
        });
        return;
      }

      // Update Firestore subcollection document with final imageUrl
      print('✍️ [FIRESTORE WRITE] Saving ${widget.documentId}: $downloadUrl');
      await docRef.update({'imageUrl': downloadUrl, 'status': 'uploaded'});
      print(
          '✅ [FIRESTORE WRITE] Subcollection updated for ${widget.documentId}');

      // CRITICAL: Update parent document's documents.{documentId} field
      print('🔵 [EDIT] Updating parent document field...');
      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      // First, read existing document to preserve all fields
      final userDoc = await userDocRef.get();
      final existingDocs =
          userDoc.data()?['documents'] as Map<String, dynamic>? ?? {};

      // Merge new URL into existing documents map
      existingDocs[widget.documentId] = downloadUrl;

      // Write back with merge to preserve all other user fields
      await userDocRef.set({
        'documents': existingDocs,
      }, SetOptions(merge: true));

      print(
          '✅ [FIRESTORE WRITE] Parent document.documents.${widget.documentId} = $downloadUrl');
      print('   Full documents map: $existingDocs');

      if (!mounted) return;

      setState(() {
        _selectedFile = File(pickedFile.path);
        _isUploading = false;
        _errorMessage = null;
      });

      widget.onUploadComplete();
    } catch (e) {
      print('❌ [UPLOAD ERROR] ${widget.documentId}: $e');
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: _getImageUrlStream(),
      builder: (context, snapshot) {
        final imageUrl = snapshot.data;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: imageUrl != null && imageUrl.isNotEmpty
                  ? const Color(0xFF10B981)
                  : Colors.grey.shade300,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.documentName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        Text(
                          imageUrl != null && imageUrl.isNotEmpty
                              ? 'Uploaded'
                              : 'Required',
                          style: TextStyle(
                            fontSize: 11,
                            color: imageUrl != null && imageUrl.isNotEmpty
                                ? const Color(0xFF10B981)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    const Icon(Icons.check_circle,
                        color: Color(0xFF10B981), size: 20),
                ],
              ),
              const SizedBox(height: 12),
              if (_selectedFile != null &&
                  imageUrl != null &&
                  imageUrl.isNotEmpty)
                Column(
                  children: [
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.grey.shade200,
                      ),
                      child: Image.file(_selectedFile!, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _isUploading
                          ? null
                          : () async {
                              print(
                                  '🔵 [EDIT BUTTON] Tapped for ${widget.documentId} (local file)');
                              final source =
                                  await showModalBottomSheet<ImageSource>(
                                context: context,
                                builder: (modalContext) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text(
                                          'Choose Image Source',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      ListTile(
                                        leading: Icon(Icons.camera_alt,
                                            color:
                                                Theme.of(context).primaryColor),
                                        title: const Text('Camera'),
                                        onTap: () {
                                          print('🔵 [EDIT] Camera selected');
                                          Navigator.pop(
                                              modalContext, ImageSource.camera);
                                        },
                                      ),
                                      ListTile(
                                        leading: Icon(Icons.photo,
                                            color:
                                                Theme.of(context).primaryColor),
                                        title: const Text('Gallery'),
                                        onTap: () {
                                          print('🔵 [EDIT] Gallery selected');
                                          Navigator.pop(modalContext,
                                              ImageSource.gallery);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              print('🔵 [EDIT] Modal returned source: $source');
                              if (source != null) {
                                print('🔵 [EDIT] Calling _pickAndUpload...');
                                await _pickAndUpload(source);
                              } else {
                                print('⚠️ [EDIT] No source selected');
                              }
                            },
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Document'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).primaryColor,
                        side: BorderSide(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ],
                )
              else if (imageUrl != null &&
                  imageUrl.isNotEmpty &&
                  _selectedFile == null)
                Column(
                  children: [
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.grey.shade200,
                      ),
                      child: Image.network(imageUrl, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _isUploading
                          ? null
                          : () async {
                              print(
                                  '🔵 [EDIT BUTTON] Tapped for ${widget.documentId} (network image)');
                              final source =
                                  await showModalBottomSheet<ImageSource>(
                                context: context,
                                builder: (modalContext) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text(
                                          'Choose Image Source',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.camera_alt,
                                            color: Color(0xFF5b47c7)),
                                        title: const Text('Camera'),
                                        onTap: () {
                                          print('🔵 [EDIT] Camera selected');
                                          Navigator.pop(
                                              modalContext, ImageSource.camera);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.photo,
                                            color: Color(0xFF5b47c7)),
                                        title: const Text('Gallery'),
                                        onTap: () {
                                          print('🔵 [EDIT] Gallery selected');
                                          Navigator.pop(modalContext,
                                              ImageSource.gallery);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              print('🔵 [EDIT] Modal returned source: $source');
                              if (source != null) {
                                print('🔵 [EDIT] Calling _pickAndUpload...');
                                await _pickAndUpload(source);
                              } else {
                                print('⚠️ [EDIT] No source selected');
                              }
                            },
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Document'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5b47c7),
                        side: const BorderSide(color: Color(0xFF5b47c7)),
                      ),
                    ),
                  ],
                )
              else if (_isUploading)
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.grey.shade100,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                            Theme.of(context).primaryColor),
                      ),
                    ),
                  ),
                )
              else if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: const Color(0xFFFFEEEE),
                    border: Border.all(color: const Color(0xFFDC2626)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF9F1239)),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUploading
                            ? null
                            : () => _pickAndUpload(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUploading
                            ? null
                            : () => _pickAndUpload(ImageSource.gallery),
                        icon: const Icon(Icons.image),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
