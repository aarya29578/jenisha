import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

/// Centralized document upload service
///
/// SINGLE SOURCE OF TRUTH for all document uploads.
/// NO Firebase Storage, NO base64 in Firestore.
/// ONLY uploads to PHP server and returns imageUrl.
class DocumentUploadService {
  static final DocumentUploadService _instance =
      DocumentUploadService._internal();

  factory DocumentUploadService() => _instance;

  DocumentUploadService._internal();

  /// Upload image to Hostinger PHP server with retry logic
  ///
  /// Returns:
  /// - imageUrl (String) on success
  /// - null on failure
  ///
  /// Server stores files as: /uploads/users/{userId}/{documentId}.jpg
  Future<String?> uploadDocument({
    required String userId,
    required String documentId,
    required File imageFile,
  }) async {
    const maxRetries = 3;
    const timeoutSeconds = 60;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        const apiUrl = 'https://jenishaonlineservice.com/uploads/upload.php';

        print('📤 [UPLOAD] Attempt $attempt/$maxRetries');
        print('   URL: $apiUrl');
        print('   User: $userId');
        print('   Document: $documentId');
        print('   File: ${imageFile.path}');
        print('   Size: ${imageFile.lengthSync() ~/ 1024} KB');

        // Create multipart request
        final request = http.MultipartRequest('POST', Uri.parse(apiUrl));

        // Add form fields
        request.fields['userId'] = userId;
        request.fields['documentId'] = documentId;

        // Add file with timeout
        print('📦 Reading file...');
        final fileSize = await imageFile.length();
        print('✅ File size: $fileSize bytes');

        final multipartFile = await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          filename: '$documentId.jpg',
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException('File read timeout'),
        );

        request.files.add(multipartFile);

        print('📤 Sending to server...');

        // Send request with timeout
        final streamedResponse = await request.send().timeout(
              Duration(seconds: timeoutSeconds),
              onTimeout: () => throw TimeoutException(
                  'Upload timeout after $timeoutSeconds seconds'),
            );

        print('📥 Response received: ${streamedResponse.statusCode}');

        final response =
            await http.Response.fromStream(streamedResponse).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException('Response read timeout'),
        );

        print('📊 Status: ${response.statusCode}');
        print('   Body: ${response.body}');

        // Parse response
        if (response.statusCode == 200 || response.statusCode == 201) {
          try {
            final jsonResponse =
                jsonDecode(response.body) as Map<String, dynamic>;

            if (jsonResponse['success'] == true) {
              final imageUrl = jsonResponse['imageUrl'] as String?;

              if (imageUrl != null && imageUrl.isNotEmpty) {
                print('✅ [UPLOAD] Success on attempt $attempt!');
                print('   URL: $imageUrl');
                return imageUrl;
              } else {
                throw Exception('No imageUrl in response');
              }
            } else {
              final errorMsg =
                  jsonResponse['message'] ?? 'Unknown server error';
              throw Exception('Server error: $errorMsg');
            }
          } catch (parseError) {
            print('❌ Failed to parse JSON: $parseError');
            print('   Raw body: ${response.body}');
            throw Exception('Invalid server response: $parseError');
          }
        } else if (response.statusCode == 408 ||
            response.statusCode == 504 ||
            response.statusCode == 502) {
          // Transient errors - retry
          print('⏱️ Transient error (${response.statusCode}) - retrying...');
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: 2 * attempt));
            continue;
          }
          throw Exception(
              'Server error ${response.statusCode} after $maxRetries attempts');
        } else {
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }
      } on TimeoutException catch (e) {
        print('❌ [UPLOAD] Timeout on attempt $attempt: $e');
        if (attempt < maxRetries) {
          print('   Retrying in ${2 * attempt} seconds...');
          await Future.delayed(Duration(seconds: 2 * attempt));
          continue;
        }
        print('❌ [UPLOAD] Failed after $maxRetries attempts: $e');
        return null;
      } catch (e, stackTrace) {
        print('❌ [UPLOAD] Error on attempt $attempt: $e');
        print('   Stack: $stackTrace');

        if (attempt < maxRetries) {
          final isNetworkError = e.toString().contains('Connection') ||
              e.toString().contains('SocketException') ||
              e.toString().contains('reset');

          if (isNetworkError) {
            print('   Network error detected - retrying...');
            await Future.delayed(Duration(seconds: 2 * attempt));
            continue;
          }
        }

        if (attempt == maxRetries) {
          return null;
        }
      }
    }

    print('❌ [UPLOAD] All $maxRetries attempts failed');
    return null;
  }

  /// Batch upload multiple documents
  ///
  /// Returns Map<documentId, imageUrl> for successful uploads
  Future<Map<String, String>> uploadMultipleDocuments({
    required String userId,
    required Map<String, File> documents,
  }) async {
    final results = <String, String>{};

    for (final entry in documents.entries) {
      final documentId = entry.key;
      final file = entry.value;

      final imageUrl = await uploadDocument(
        userId: userId,
        documentId: documentId,
        imageFile: file,
      );

      if (imageUrl != null) {
        results[documentId] = imageUrl;
      }
    }

    return results;
  }
}
