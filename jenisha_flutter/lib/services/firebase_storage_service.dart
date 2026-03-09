import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseStorageService {
  static final FirebaseStorageService _instance =
      FirebaseStorageService._internal();

  factory FirebaseStorageService() {
    return _instance;
  }

  FirebaseStorageService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Upload image via HTTP multipart to custom API endpoint
  /// Replaces Firebase Storage with: https://cyan-llama-839264.hostingersite.com/uploads/upload.php
  ///
  /// Expected API behavior:
  /// - POST multipart/form-data
  /// - Fields: userId, documentId, file
  /// - Response: JSON with 'imageUrl' field containing uploaded image URL
  ///
  /// Returns the imageUrl from API response, or null if upload fails
  Future<String?> uploadDocumentImage({
    required File file,
    required String userId,
    required String serviceId,
    required String documentId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      if (user.uid != userId) {
        throw Exception('Authenticated user does not match provided userId');
      }

      const apiUrl =
          'https://cyan-llama-839264.hostingersite.com/uploads/upload.php';

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Add form fields
      request.fields['userId'] = userId;
      request.fields['documentId'] = documentId;

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: '$documentId.jpg',
        ),
      );

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      // DEBUG: Log upload details
      print('📤 [UPLOAD DEBUG]');
      print('   URL: $apiUrl');
      print('   Method: POST');
      print('   Fields: userId=$userId, documentId=$documentId');
      print('   File field: file');
      print('   Status Code: ${response.statusCode}');
      print('   Response Body: ${response.body}');

      // Handle response
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final jsonResponse =
              jsonDecode(response.body) as Map<String, dynamic>;

          if (jsonResponse['success'] == true &&
              jsonResponse.containsKey('imageUrl')) {
            final imageUrl = jsonResponse['imageUrl'] as String;

            print('✅ Document uploaded via custom API');
            print('   User UID: $userId');
            print('   Document ID: $documentId');
            print('   Image URL: $imageUrl');

            return imageUrl;
          } else {
            final errorMsg = jsonResponse['message'] ?? 'Unknown error';
            print('❌ API response indicates failure: $errorMsg');
            print('   Full response: ${response.body}');
            return null;
          }
        } catch (parseError) {
          print('❌ Failed to parse JSON response: $parseError');
          print('   Response body: ${response.body}');
          return null;
        }
      } else {
        print('❌ API upload failed with status ${response.statusCode}');
        print('   Response: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Error uploading document via API: $e');
      return null;
    }
  }

  /// Delete a document - Deprecated (custom API handles deletion)
  /// No longer applicable since uploads are handled by custom API
  @deprecated
  Future<bool> deleteDocument({
    required String uid,
    required String serviceId,
    required String documentId,
  }) async {
    print('⚠️  deleteDocument() is deprecated');
    print('   Document deletion should be handled by custom API or Firestore');
    return false;
  }

  /// Get download URL for a document - Deprecated
  /// URLs are returned directly from upload API response
  @deprecated
  Future<String?> getDocumentUrl({
    required String uid,
    required String serviceId,
    required String documentId,
  }) async {
    print('⚠️  getDocumentUrl() is deprecated');
    print('   Document URLs are retrieved during upload via custom API');
    return null;
  }

  /// Check if document exists - Deprecated
  /// Use Firestore documentSnapshots stream instead
  @deprecated
  Future<bool> documentExists({
    required String uid,
    required String serviceId,
    required String documentId,
  }) async {
    print('⚠️  documentExists() is deprecated');
    print('   Check document existence via Firestore instead');
    return false;
  }

  /// Get user's document storage usage - Deprecated
  /// Storage usage is now managed by custom API backend
  @deprecated
  Future<int> getUserStorageSize(String uid) async {
    print('⚠️  getUserStorageSize() is deprecated');
    print('   Storage usage is managed by custom API backend');
    return 0;
  }
}
