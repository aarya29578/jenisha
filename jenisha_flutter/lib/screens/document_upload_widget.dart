import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/document_upload_service.dart';
import '../services/firestore_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class DocumentUploadWidget extends StatefulWidget {
  final Map<String, dynamic> documentRequirement;
  final String userId;
  final Map<String, dynamic>? existingImage;
  final void Function(String documentId, String imageUrl) onUploaded;

  const DocumentUploadWidget({
    Key? key,
    required this.documentRequirement,
    required this.userId,
    this.existingImage,
    required this.onUploaded,
  }) : super(key: key);

  @override
  State<DocumentUploadWidget> createState() => _DocumentUploadWidgetState();
}

class _DocumentUploadWidgetState extends State<DocumentUploadWidget> {
  final DocumentUploadService _uploadService = DocumentUploadService();
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  bool _isUploading = false;
  String? _error;

  /// Request permissions for image picker
  Future<bool> _requestPermissions(ImageSource source) async {
    try {
      PermissionStatus status;

      if (source == ImageSource.camera) {
        status = await Permission.camera.request();
      } else {
        // For gallery
        if (Platform.isAndroid) {
          status = await Permission.photos.request();
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }
        } else {
          status = await Permission.photos.request();
        }
      }

      if (status.isDenied) {
        print(
            '❌ Permission denied for ${source == ImageSource.camera ? "camera" : "gallery"}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Permission denied to access ${source == ImageSource.camera ? "camera" : "gallery"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      if (status.isPermanentlyDenied) {
        print('❌ Permission permanently denied - opening app settings');
        openAppSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Permission permanently denied. Please enable in app settings.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }

      return status.isGranted;
    } catch (e) {
      print('❌ Error requesting permission: $e');
      return false;
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      print(
          '📸 Attempting to pick image from: ${source == ImageSource.gallery ? "Gallery" : "Camera"}');

      // Request permissions first
      final hasPermission = await _requestPermissions(source);
      if (!hasPermission) {
        print('❌ Permissions not granted');
        return;
      }

      setState(() => _error = null);

      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (picked == null) {
        print(
            '❌ Image picker returned null - user cancelled or error occurred');
        return;
      }

      print('✅ Image picked successfully: ${picked.path}');
      final file = File(picked.path);

      setState(() {
        _isUploading = true;
        _error = null;
      });

      final documentId = widget.documentRequirement['id'] as String;
      final documentName =
          widget.documentRequirement['documentName'] ?? 'Unknown';

      print('UPLOAD ID = $documentId');
      print('📤 [UPLOAD START] Document: "$documentName"');

      final imageUrl = await _uploadService.uploadDocument(
        userId: widget.userId,
        documentId: documentId,
        imageFile: file,
      );

      if (imageUrl == null) {
        throw Exception('Upload failed - no URL returned');
      }

      print('✅ [API UPLOAD SUCCESS] ImageUrl: $imageUrl');

      // 🔥 SAVE TO FIRESTORE via FirestoreService
      await _firestoreService.saveUserDocumentUrl(
        uid: widget.userId,
        documentId: documentId,
        imageUrl: imageUrl,
      );

      print('FIRESTORE UPDATED FOR = $documentId');

      // Notify parent for any additional logic
      widget.onUploaded(documentId, imageUrl);

      if (mounted) {
        setState(() => _error = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context).get('document_uploaded_success')),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Error in _pickAndUpload: $e');
      setState(() => _error =
          '${AppLocalizations.of(context).get('upload_failed')}: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${AppLocalizations.of(context).get('upload_failed')}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final docName = widget.documentRequirement['documentName'] ??
        localizations.get('documents');
    final isRequired = widget.documentRequirement['required'] == true;
    final imageUrl = widget.existingImage?['imageUrl'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                docName,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            if (imageUrl != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  localizations.get('file_uploaded'),
                  style: const TextStyle(fontSize: 11, color: Colors.green),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isRequired
              ? localizations.get('required')
              : localizations.get('optional'),
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        if (imageUrl == null)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _isUploading
                      ? null
                      : () => _pickAndUpload(ImageSource.gallery),
                  child: Container(
                    height: 80,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
                    ),
                    child: _isUploading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 8),
                              Text(localizations.get('uploading'),
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_upload_outlined,
                                  size: 32, color: Colors.grey),
                              const SizedBox(height: 4),
                              Text(localizations.get('tap_to_upload'),
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                  ),
                ),
                Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _isUploading
                            ? null
                            : () => _pickAndUpload(ImageSource.camera),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(localizations.get('camera'),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Container(
                        width: 1, height: 30, color: Colors.grey.shade300),
                    Expanded(
                      child: InkWell(
                        onTap: _isUploading
                            ? null
                            : () => _pickAndUpload(ImageSource.gallery),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_library,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(localizations.get('gallery'),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          GestureDetector(
            onTap: () {
              // Show full image or allow re-upload
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.network(imageUrl, fit: BoxFit.contain),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(localizations.get('close')),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.error_outline, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(_error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.red, fontSize: 11)),
        ],
      ],
    );
  }
}
