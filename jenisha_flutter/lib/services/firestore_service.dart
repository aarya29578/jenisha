import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream user documents from users/{userId}.documents field
  Stream<Map<String, dynamic>> getUserDocumentsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return {};
      final data = snapshot.data();
      if (data == null) return {};

      // Extract documents field (e.g., documents.adhaar, documents.pan)
      final documents = data['documents'] as Map<String, dynamic>?;
      if (documents == null) return {};

      // Convert to format expected by UI: {documentId: {imageUrl: url}}
      final result = <String, dynamic>{};
      documents.forEach((key, value) {
        result[key] = {'imageUrl': value, 'id': key};
      });
      return result;
    });
  }

  /// Save user document URL to Firestore
  /// CRITICAL: Uses explicit server-side write with full audit trail
  Future<void> saveUserDocumentUrl({
    required String uid,
    required String documentId,
    required String imageUrl,
  }) async {
    // 🚨 CRITICAL DEBUG: Entry point assertion
    debugPrint('🚨🚨🚨 WRITE FUNCTION ENTERED 🚨🚨🚨');
    debugPrint('   Called at: ${DateTime.now().toIso8601String()}');
    debugPrint('   uid: $uid');
    debugPrint('   documentId: $documentId');
    debugPrint('   imageUrl: $imageUrl');

    try {
      print('═══════════════════════════════════════════════════════════');
      print('🔥 [FIRESTORE AUDIT - START]');
      print('   Timestamp: ${DateTime.now().toIso8601String()}');

      // STEP 1: UID CONSISTENCY CHECK
      final authUser = _auth.currentUser;
      print('   [UID CHECK]');
      print('   - FirebaseAuth.currentUser.uid: ${authUser?.uid ?? "NULL"}');
      print('   - Parameter uid: $uid');
      print('   - Document ID: $documentId');
      print('   - Image URL: $imageUrl');

      if (authUser == null) {
        throw Exception('❌ CRITICAL: User not authenticated!');
      }

      if (authUser.uid != uid) {
        throw Exception(
            '❌ CRITICAL: UID MISMATCH! Auth=${authUser.uid}, Param=$uid');
      }
      print('   ✅ UID verified: $uid');

      // STEP 2: FORCE SERVER READ
      final ref = _firestore.collection('users').doc(uid);
      print('   [SERVER READ - BEFORE]');
      print('   - Path: users/$uid');

      DocumentSnapshot<Map<String, dynamic>> beforeSnap;
      try {
        beforeSnap = await ref.get(GetOptions(source: Source.server));
        print('   - Document exists: ${beforeSnap.exists}');

        if (!beforeSnap.exists) {
          // New user in registration flow — create a minimal document so the
          // upload can be saved. Full registration happens at submit.
          print('   ⚠️  User document missing — creating stub for new user');
          await ref.set({
            'uid': uid,
            'documents': {},
            'status': 'incomplete',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          // Re-read after creation
          beforeSnap = await ref.get(GetOptions(source: Source.server));
          print('   ✅ Stub document created');
        }

        final data = beforeSnap.data();
        final docs = data?['documents'];
        print('   - Current documents field: $docs');

        // Initialize documents field if it doesn't exist
        if (data == null || !data.containsKey('documents')) {
          print('   ⚠️  Documents field missing - initializing empty map');
          await ref.set({'documents': {}}, SetOptions(merge: true));
          print('   ✅ Documents field initialized');
        }
      } catch (e) {
        print('   ❌ SERVER READ FAILED: $e');
        rethrow;
      }

      // STEP 3: PREPARE WRITE - Build complete documents map preserving existing uploads
      final existingDocs =
          beforeSnap.data()?['documents'] as Map<String, dynamic>? ?? {};

      // Preserve ALL existing values (including nulls for not-yet-uploaded docs)
      // Only update the current document being uploaded
      final updatedDocs = Map<String, dynamic>.from(existingDocs);
      updatedDocs[documentId] = imageUrl;

      print('   [WRITE PREPARATION]');
      print('   - Existing documents map: $existingDocs');
      print('   - Updating field: $documentId = $imageUrl');
      print('   - Final documents map to write: $updatedDocs');
      print('   - Method: set() with merge:true (safe overwrite)');

      // STEP 4: EXECUTE WRITE with set(merge:true) - MANDATORY for null map override
      print('   [FIRESTORE WRITE - EXECUTING]');
      debugPrint('🚨 ATTEMPTING FIRESTORE WRITE NOW...');
      debugPrint('   Path: users/$uid');
      debugPrint('   Data: {documents: $updatedDocs}');

      try {
        // CRITICAL: Use set() with merge - update() does NOT work on null nested maps
        await ref.set({
          'documents': updatedDocs,
        }, SetOptions(merge: true));

        debugPrint('✅ FIRESTORE WRITE COMPLETED SUCCESSFULLY!');
        print('   ✅ Write command sent successfully');
        print('   - Method: set({documents: map}, merge:true)');
        print('   - Wrote documents map: $updatedDocs');

        // CRITICAL: Immediate verification read to confirm persistence
        debugPrint('🔍 Reading back from Firestore to verify...');
        final immediateSnap = await ref.get(GetOptions(source: Source.server));
        final immediateData = immediateSnap.data();

        debugPrint('🔥 POST-WRITE SNAPSHOT:');
        debugPrint('   Full document data: $immediateData');
        debugPrint('   documents field: ${immediateData?['documents']}');
        debugPrint(
            '   documents.$documentId = ${immediateData?['documents']?[documentId]}');

        print('   🔥 FIRESTORE IMMEDIATELY AFTER WRITE:');
        print('      Full document: $immediateData');
        print('      documents field: ${immediateData?['documents']}');

        // Assert the write actually persisted
        if (immediateData?['documents']?[documentId] != imageUrl) {
          debugPrint('❌❌❌ VERIFICATION FAILED! URL DID NOT PERSIST!');
          debugPrint('   Expected: $imageUrl');
          debugPrint('   Got: ${immediateData?['documents']?[documentId]}');
          throw Exception('FIRESTORE WRITE VERIFICATION FAILED');
        }

        debugPrint('✅✅✅ VERIFICATION PASSED - URL PERSISTED CORRECTLY');
      } catch (e, stackTrace) {
        debugPrint('❌ FIRESTORE WRITE FAILED: $e');
        debugPrint('Stack trace:');
        debugPrint(stackTrace.toString());

        if (e is FirebaseException) {
          debugPrint('❌ FirebaseException Details:');
          debugPrint('   Code: ${e.code}');
          debugPrint('   Message: ${e.message}');
          debugPrint('   Plugin: ${e.plugin}');

          print('   ❌ FIRESTORE EXCEPTION:');
          print('   - Code: ${e.code}');
          print('   - Message: ${e.message}');
          print('   - Details: ${e.toString()}');

          if (e.code == 'permission-denied') {
            debugPrint('🚨 FIRESTORE RULES BLOCKING WRITE!');
            debugPrint('   Go to Firebase Console → Firestore → Rules');
            debugPrint('   Temporarily set: allow read, write: if true;');
            print('   🚨 FIRESTORE RULES BLOCKING WRITE!');
            print('   - Required: allow update: if request.auth.uid == uid');
          } else if (e.code == 'not-found') {
            print('   🚨 DOCUMENT NOT FOUND!');
            print('   - This should never happen due to guard check above');
          }
        }
        rethrow;
      }

      // STEP 5: FINAL VERIFICATION WITH SERVER READ
      print('   [SERVER READ - FINAL VERIFICATION]');
      await Future.delayed(Duration(milliseconds: 300));

      DocumentSnapshot<Map<String, dynamic>> afterSnap;
      try {
        afterSnap = await ref.get(GetOptions(source: Source.server));

        if (!afterSnap.exists) {
          throw Exception('❌ CRITICAL: Document not found after write!');
        }

        final afterData = afterSnap.data();
        final afterDocs = afterData?['documents'] as Map<String, dynamic>?;

        print('   - Full document snapshot after write:');
        print('     ${afterSnap.data()}');
        print('   - Server documents field: $afterDocs');
        print('   - All document IDs: ${afterDocs?.keys.toList()}');

        if (afterDocs == null) {
          throw Exception('❌ CRITICAL: documents field is NULL after write!');
        }

        final actualValue = afterDocs[documentId];
        print('   - documents.$documentId = $actualValue');

        if (actualValue == imageUrl) {
          print('   ✅✅✅ VERIFIED: Write persisted on server!');
          print('   - URL stored correctly: $actualValue');
        } else if (actualValue == null) {
          throw Exception(
              '❌ VERIFICATION FAILED: Field is still NULL! Check Firestore console manually.');
        } else {
          throw Exception(
              '❌ VERIFICATION FAILED: Expected=$imageUrl, Actual=$actualValue');
        }
      } catch (e) {
        print('   ❌ VERIFICATION READ FAILED: $e');
        rethrow;
      }

      print('🎉 [FIRESTORE AUDIT - SUCCESS]');
      print('═══════════════════════════════════════════════════════════');
    } catch (e, stackTrace) {
      print('═══════════════════════════════════════════════════════════');
      print('❌ [FIRESTORE AUDIT - FAILED]');
      print('   Error Type: ${e.runtimeType}');
      print('   Error: $e');
      print('   UID: $uid');
      print('   Document: $documentId');
      print('   Stack: $stackTrace');
      print('═══════════════════════════════════════════════════════════');
      rethrow;
    }
  }

  /// Get user documents from subcollection (returns list of document data)
  Future<List<Map<String, dynamic>>> getUserDocuments(String userId) async {
    try {
      final docsSnap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('documents')
          .get();
      return docsSnap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ Error fetching user documents: $e');
      return [];
    }
  }

  /// Update document status (approved/rejected) in subcollection
  Future<void> updateDocumentStatus({
    required String userId,
    required String docName,
    required String status,
    String? rejectionReason,
    String? reviewedBy,
  }) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('documents')
          .doc(docName);
      final docSnap = await docRef.get();
      if (!docSnap.exists) throw Exception('Document not found');
      await docRef.update({
        'status': status,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': reviewedBy,
        'rejectionReason': rejectionReason,
      });
      print('✅ Document "$docName" status updated for user $userId');
    } catch (e) {
      print('❌ Error updating document status: $e');
      rethrow;
    }
  }

  static final FirestoreService _instance = FirestoreService._internal();

  factory FirestoreService() {
    return _instance;
  }

  FirestoreService._internal();

  /// Create a minimal draft document when user first signs in.
  /// Status is 'incomplete' - NOT 'pending'.
  /// Status only becomes 'pending' when user explicitly submits the full form.
  Future<void> createDraftUserDocument({
    required String fullName,
    required String email,
    required String phoneNumber,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if document already exists (e.g., user re-opened app before submitting)
      final existing = await _firestore.collection('users').doc(user.uid).get();
      if (existing.exists) {
        final existingStatus =
            (existing.data() as Map<String, dynamic>)['status'] as String?;
        // Only re-create if status is truly absent or incomplete; never overwrite pending/approved
        if (existingStatus != null && existingStatus != 'incomplete') {
          print(
              '⏭️ [DRAFT] Document already exists with status=$existingStatus — skipping draft creation');
          return;
        }
        print('✏️ [DRAFT] Updating incomplete draft document');
      } else {
        print('🆕 [DRAFT] Creating new draft document');
      }

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'fullName': fullName,
        'email': email.toLowerCase().trim(),
        'phone': phoneNumber,
        'shopName': '',
        'address': {'line1': '', 'city': '', 'state': '', 'pincode': ''},
        'documents': {},
        'status': 'incomplete', // ← NOT 'pending'. Only submit sets 'pending'.
        'createdAt': FieldValue.serverTimestamp(),
        'registrationSubmittedAt': null,
      }, SetOptions(merge: true));

      print('✅ [DRAFT] Draft document created with status=incomplete');
    } catch (e) {
      print('❌ [DRAFT] Failed to create draft: $e');
      rethrow;
    }
  }

  /// Save complete user registration data to Firestore (no document URLs)
  /// Sets status to 'pending' ONLY when called from the explicit Submit button.
  /// IMPORTANT: Uses merge: false to ensure we NEVER overwrite existing registrations
  Future<void> saveUserRegistration({
    required String fullName,
    required String shopName,
    required String phoneNumber,
    required String email,
    required String address,
    required String pincode,
    required String city,
    required String state,
    String? registrationStatus,
    String? profilePhotoUrl,
    String? referredBy,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Allow re-submission unless already approved.
      final existingDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (existingDoc.exists) {
        final existingData = existingDoc.data() as Map<String, dynamic>;
        final existingStatus = existingData['status'] as String?;

        // Only block if already approved — allow re-submission of incomplete/pending/rejected
        if (existingStatus == 'approved') {
          print('🛑 SUBMIT BLOCKED: Account already approved.');
          return;
        }

        print(
            '✅ SUBMITTING: Updating registration (current status: $existingStatus)');
      } else {
        print('✅ SUBMITTING: Creating new registration document');
      }

      // Normalize email for consistent querying
      final normalizedEmail = email.toLowerCase().trim();

      final userData = {
        'uid': user.uid,
        'fullName': fullName,
        'shopName': shopName,
        'phone': phoneNumber,
        'email': normalizedEmail,
        if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty)
          'profilePhotoUrl': profilePhotoUrl,
        // Only set referredBy on first submission (don't overwrite if already set)
        if (referredBy != null &&
            referredBy.isNotEmpty &&
            !(existingDoc.exists &&
                (existingDoc.data()?['referredBy'] as String? ?? '')
                    .isNotEmpty))
          'referredBy': referredBy,
        'address': {
          'line1': address,
          'pincode': pincode,
          'city': city,
          'state': state,
        },
        // Never overwrite documents — they may have been uploaded already
        'status': 'pending', // ← Set to 'pending' ONLY at explicit submit time
        'documentsCompleted': false,
        'registrationSubmittedAt': FieldValue.serverTimestamp(),
        'createdAt': existingDoc.exists
            ? existingDoc['createdAt']
            : FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewedBy': null,
        'rejectionReason': null,
      };

      // merge: true to avoid wiping the documents field
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));

      print('✅ Registration SUBMITTED — status set to pending');
      print('   UID: ${user.uid}');
      print('   Email: $normalizedEmail');
      print('   Status: pending (awaiting admin approval)');
    } catch (e) {
      print('❌ Error saving user registration: $e');
      rethrow;
    }
  }

  /// Upload a document for the user to the documents subcollection
  /// ONLY stores imageUrl - NO base64/image/bytes allowed
  Future<void> uploadUserDocument({
    required String userId,
    required String docName,
    required String imageUrl,
  }) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('documents')
          .doc(docName);

      await docRef.set({
        'name': docName,
        'imageUrl': imageUrl,
        'status': 'uploaded',
        'uploadedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Document "$docName" uploaded for user $userId');
      print('   imageUrl: $imageUrl');
    } catch (e) {
      print('❌ Error uploading user document: $e');
      rethrow;
    }
  }

  /// Update user status (pending/approved/rejected)
  /// Only for admin use - updates status, timestamp, and reviewer info
  Future<void> updateUserStatus({
    required String uid,
    required String status,
    String? reviewedBy,
    String? rejectionReason,
  }) async {
    try {
      final updates = {
        'status': status,
        'reviewedAt': FieldValue.serverTimestamp(),
        if (reviewedBy != null) 'reviewedBy': reviewedBy,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      };

      await _firestore.collection('users').doc(uid).update(updates);

      print('✅ User status updated to: $status');
      if (rejectionReason != null) {
        print('   Rejection reason: $rejectionReason');
      }
    } catch (e) {
      print('❌ Error updating user status: $e');
      rethrow;
    }
  }

  /// Get user data
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  /// Get current user data
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      return await getUserData(user.uid);
    } catch (e) {
      print('❌ Error getting current user data: $e');
      return null;
    }
  }

  /// Check if user document exists
  Future<bool> userDocumentExists(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (e) {
      print('❌ Error checking user document: $e');
      return false;
    }
  }

  /// Stream listener for current user's approval status (real-time)
  Stream<Map<String, dynamic>?> getCurrentUserStatusStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
      if (doc.exists) {
        return doc.data();
      }
      return null;
    }).handleError((e) {
      print('❌ Error listening to user status: $e');
      return null;
    });
  }

  /// Stream listener for all pending users (for admin panel)
  Stream<List<Map<String, dynamic>>> getPendingUsersStream() {
    return _firestore
        .collection('users')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => {...doc.data(), 'uid': doc.id})
          .toList();
    }).handleError((e) {
      print('❌ Error listening to pending users: $e');
      return [];
    });
  }

  /// Check if user exists by email (case-insensitive)
  /// Returns user data if found, null otherwise
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();

      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return {...doc.data(), 'uid': doc.id};
      }

      return null;
    } catch (e) {
      print('❌ Error checking user by email: $e');
      return null;
    }
  }

  // ============= CATEGORY & SERVICE MANAGEMENT =============
  // NEW FLAT COLLECTION STRUCTURE:
  // - side_categories: {id, name, icon, order, isActive, createdAt}  ← parent
  // - categories: {id, name, sideCategoryId, icon, order, isActive, createdAt} ← child
  // - services: {id, categoryId, name, price, isActive, createdAt}

  /// Get all active side-categories (parent) from 'side_categories' collection
  Stream<List<Map<String, dynamic>>> getActiveSideCategoriesStream() {
    return _firestore
        .collection('side_categories')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final items =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
      items.sort((a, b) {
        final orderA = (a['order'] ?? 0) as int;
        final orderB = (b['order'] ?? 0) as int;
        if (orderA != orderB) return orderA.compareTo(orderB);
        final createdAtA = a['createdAt'] as Timestamp?;
        final createdAtB = b['createdAt'] as Timestamp?;
        if (createdAtA != null && createdAtB != null) {
          return createdAtB.compareTo(createdAtA);
        }
        return 0;
      });
      return items;
    }).handleError((e) {
      print('❌ Error listening to side_categories: $e');
      return <Map<String, dynamic>>[];
    });
  }

  /// Get categories (child) belonging to a specific side-category
  Stream<List<Map<String, dynamic>>> getCategoriesBySideCategory(
      String sideCategoryId) {
    return _firestore
        .collection('categories')
        .where('sideCategoryId', isEqualTo: sideCategoryId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .where((item) => item['isActive'] == true)
          .toList();
      items.sort((a, b) {
        final orderA = (a['order'] ?? 0) as int;
        final orderB = (b['order'] ?? 0) as int;
        if (orderA != orderB) return orderA.compareTo(orderB);
        final createdAtA = a['createdAt'] as Timestamp?;
        final createdAtB = b['createdAt'] as Timestamp?;
        if (createdAtA != null && createdAtB != null) {
          return createdAtB.compareTo(createdAtA);
        }
        return 0;
      });
      return items;
    }).handleError((e) {
      print('❌ Error listening to categories by side_category: $e');
      return <Map<String, dynamic>>[];
    });
  }

  /// Get all active categories with real-time listener (from 'categories' collection)
  Stream<List<Map<String, dynamic>>> getActiveCategoriesStream() {
    return _firestore
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final categories =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();

      // Sort in memory: by order field first, then by createdAt
      categories.sort((a, b) {
        final orderA = (a['order'] ?? 0) as int;
        final orderB = (b['order'] ?? 0) as int;

        if (orderA != orderB) {
          return orderA.compareTo(orderB);
        }

        // If order is same, sort by createdAt descending
        final createdAtA = a['createdAt'] as Timestamp?;
        final createdAtB = b['createdAt'] as Timestamp?;

        if (createdAtA != null && createdAtB != null) {
          return createdAtB.compareTo(createdAtA);
        }

        return 0;
      });

      return categories;
    }).handleError((e) {
      print('❌ Error listening to categories: $e');
      return [];
    });
  }

  /// Get services for a specific category with real-time listener (from flat 'services' collection)
  Stream<List<Map<String, dynamic>>> getActiveServicesForCategory(
      String categoryId) {
    return _firestore
        .collection('services')
        .where('categoryId', isEqualTo: categoryId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final services =
          snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();

      // Sort by createdAt descending (most recent first)
      services.sort((a, b) {
        final createdAtA = a['createdAt'] as Timestamp?;
        final createdAtB = b['createdAt'] as Timestamp?;

        if (createdAtA != null && createdAtB != null) {
          return createdAtB.compareTo(createdAtA);
        }

        return 0;
      });

      return services;
    }).handleError((e) {
      print('❌ Error listening to services for category: $e');
      return [];
    });
  }

  /// Get document requirements for a specific service with real-time listener
  /// (from flat 'document_requirements' collection)
  Stream<List<Map<String, dynamic>>> getDocumentRequirementsForService(
      String serviceId) {
    try {
      return _firestore
          .collection('document_requirements')
          .where('serviceId', isEqualTo: serviceId)
          .where('isActive', isEqualTo: true)
          .orderBy('order', descending: false)
          .snapshots()
          .map((snapshot) {
        final results = snapshot.docs.map((doc) {
          final data = doc.data();
          // Create human-readable ID from documentName
          final documentName = data['documentName'] as String?;
          String id;
          if (documentName != null && documentName.isNotEmpty) {
            // Convert "adhaar card" -> "adhaar", "PAN Card" -> "pan"
            id = documentName
                .toLowerCase()
                .replaceAll(RegExp(r'\s+card$'), '') // Remove " card" suffix
                .replaceAll(
                    RegExp(r'\s+'), '_') // Replace spaces with underscore
                .trim();
          } else {
            id = doc.id; // Fallback to Firestore ID
          }
          print(
              '📋 Document Requirement: Firestore doc.id="${doc.id}", documentName="$documentName", using id="$id"');
          return {...data, 'id': id};
        }).toList();
        return results;
      }).handleError((e) {
        print('⚠️ Composite index error, falling back to unordered query: $e');

        // Fallback: query without orderBy and sort client-side
        return _firestore
            .collection('document_requirements')
            .where('serviceId', isEqualTo: serviceId)
            .where('isActive', isEqualTo: true)
            .snapshots()
            .map((snapshot) {
          final docs = snapshot.docs.map((doc) {
            final data = doc.data();
            // Create human-readable ID from documentName
            final documentName = data['documentName'] as String?;
            String id;
            if (documentName != null && documentName.isNotEmpty) {
              // Convert "adhaar card" -> "adhaar", "PAN Card" -> "pan"
              id = documentName
                  .toLowerCase()
                  .replaceAll(RegExp(r'\s+card$'), '') // Remove " card" suffix
                  .replaceAll(
                      RegExp(r'\s+'), '_') // Replace spaces with underscore
                  .trim();
            } else {
              id = doc.id; // Fallback to Firestore ID
            }
            return {...data, 'id': id};
          }).toList();
          // Sort by order field client-side
          docs.sort((a, b) =>
              ((a['order'] ?? 0) as num).compareTo((b['order'] ?? 0) as num));
          return docs;
        }).handleError((fallbackError) {
          print(
              '❌ Error listening to document requirements (fallback): $fallbackError');
          return [];
        });
      });
    } catch (e) {
      print('❌ Error in getDocumentRequirementsForService: $e');
      return Stream.value([]);
    }
  }

  /// Ensure a service application document exists for a user/service pair
  /// Returns the deterministic applicationId used across the app
  Future<String> ensureServiceApplication({
    required String userId,
    required String serviceId,
    String? serviceName,
    String? userDisplayName,
  }) async {
    try {
      final applicationId = '${userId}_$serviceId';
      final docRef =
          _firestore.collection('serviceApplications').doc(applicationId);
      final snapshot = await docRef.get();

      final data = {
        'applicationId': applicationId,
        'userId': userId,
        'serviceId': serviceId,
        if (serviceName != null) 'serviceName': serviceName,
        if (userDisplayName != null) 'userName': userDisplayName,
        if (!snapshot.exists) 'status': 'draft',
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(data, SetOptions(merge: true));
      return applicationId;
    } catch (e) {
      print('❌ Error ensuring service application: $e');
      rethrow;
    }
  }

  /// Save uploaded document image metadata for a user
  /// Saves to user_documents collection with structure:
  /// {
  ///   serviceId: "...",
  ///   userId: "...",
  ///   documents: {
  ///     "documentId": {
  ///       "imageUrl": "...",
  ///       "uploadedAt": timestamp
  ///     }
  ///   }
  /// }
  Future<void> saveUserDocumentImage({
    required String userId,
    required String serviceId,
    required String documentId,
    required String imageUrl,
  }) async {
    try {
      final docId = '${userId}_$serviceId';

      await _firestore.collection('user_documents').doc(docId).set(
        {
          'userId': userId,
          'serviceId': serviceId,
          'documents.$documentId': {
            'imageUrl': imageUrl,
            'uploadedAt': FieldValue.serverTimestamp(),
          }
        },
        SetOptions(merge: true),
      );

      print(
          '✅ Document image saved: $documentId for user $userId, service $serviceId');
    } catch (e) {
      print('❌ Error saving document image: $e');
      rethrow;
    }
  }

  /// Persist uploaded document metadata under serviceApplications
  Future<void> saveServiceApplicationDocument({
    required String applicationId,
    required String userId,
    required String serviceId,
    required String documentId,
    required String documentName,
    required String imageUrl,
  }) async {
    try {
      final applicationRef =
          _firestore.collection('serviceApplications').doc(applicationId);

      print('🔥 [FIRESTORE WRITE]');
      print(
          '   path: serviceApplications/$applicationId/documents/$documentId');
      print('   imageUrl: $imageUrl');

      await applicationRef.collection('documents').doc(documentId).set({
        'documentId': documentId,
        'imageUrl': imageUrl,
        'uploaded': true,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Firestore write completed successfully');
      print('   Document: $documentId');
      print('   Application: $applicationId');

      // Keep legacy user_documents collection in sync (non-blocking)
      try {
        await saveUserDocumentImage(
          userId: userId,
          serviceId: serviceId,
          documentId: documentId,
          imageUrl: imageUrl,
        );
      } catch (e) {
        print('⚠️  Legacy user_documents sync failed (non-critical): $e');
      }
    } catch (e) {
      print('❌ Error saving service application document: $e');
      rethrow;
    }
  }

  /// Remove uploaded document image
  Future<void> removeUserDocumentImage({
    required String userId,
    required String serviceId,
    required String documentId,
  }) async {
    try {
      final docId = '${userId}_$serviceId';

      await _firestore.collection('user_documents').doc(docId).update({
        'documents.$documentId': FieldValue.delete(),
      });

      print('✅ Document image removed: $documentId for user $userId');
    } catch (e) {
      print('❌ Error removing document image: $e');
      rethrow;
    }
  }

  /// Remove document metadata from service application + legacy stores
  Future<void> removeServiceApplicationDocument({
    required String applicationId,
    required String userId,
    required String serviceId,
    required String documentId,
  }) async {
    try {
      await removeUserDocumentImage(
        userId: userId,
        serviceId: serviceId,
        documentId: documentId,
      );

      final applicationRef =
          _firestore.collection('serviceApplications').doc(applicationId);

      await applicationRef.collection('documents').doc(documentId).delete();

      print('✅ Removed $documentId from application $applicationId');
    } catch (e) {
      print('❌ Error removing service application document: $e');
      rethrow;
    }
  }

  /// Get user's uploaded document images for a service
  Future<Map<String, dynamic>?> getUserDocumentImages(
    String userId,
    String serviceId,
  ) async {
    try {
      final docId = '${userId}_$serviceId';
      final doc =
          await _firestore.collection('user_documents').doc(docId).get();

      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('❌ Error fetching user document images: $e');
      return null;
    }
  }

  /// Get stream of user's uploaded document images for a service
  Stream<Map<String, dynamic>?> getUserDocumentImagesStream(
    String userId,
    String serviceId,
  ) {
    try {
      final docId = '${userId}_$serviceId';
      return _firestore
          .collection('user_documents')
          .doc(docId)
          .snapshots()
          .map((doc) {
        if (doc.exists) {
          return doc.data() as Map<String, dynamic>?;
        }
        return null;
      });
    } catch (e) {
      print('❌ Error in getUserDocumentImagesStream: $e');
      return Stream.value(null);
    }
  }

  /// Stream documents stored under serviceApplications/{applicationId}
  Stream<Map<String, dynamic>> getServiceApplicationDocumentsStream(
      String applicationId) {
    try {
      return _firestore
          .collection('serviceApplications')
          .doc(applicationId)
          .collection('documents')
          .snapshots()
          .map((snapshot) {
        print('══════════════════════════════════════════════════════════════');
        print('📖 [FIRESTORE READ]');
        print('   Path: serviceApplications/$applicationId/documents');
        print('   Found: ${snapshot.docs.length} document(s)');

        final data = <String, dynamic>{};
        for (final doc in snapshot.docs) {
          final docData = doc.data();
          data[doc.id] = {...docData, 'id': doc.id};
          print('   ✓ Document ID: "${doc.id}"');
          print('     - documentName: "${docData['documentName']}"');
          print('     - status: ${docData['status']}');
          print('     - imageUrl: ${docData['imageUrl']}');
        }

        if (data.isEmpty) {
          print('   ⚠️  No uploaded documents found in Firestore');
        }
        print('══════════════════════════════════════════════════════════════');
        return data;
      });
    } catch (e) {
      print('❌ Error in getServiceApplicationDocumentsStream: $e');
      return Stream.value({});
    }
  }

  /// Fetch documents for an application once (non-stream)
  Future<Map<String, dynamic>> getServiceApplicationDocuments(
      String applicationId) async {
    try {
      final snapshot = await _firestore
          .collection('serviceApplications')
          .doc(applicationId)
          .collection('documents')
          .get();

      final map = <String, dynamic>{};
      for (final doc in snapshot.docs) {
        map[doc.id] = {...doc.data(), 'id': doc.id};
      }
      return map;
    } catch (e) {
      print('❌ Error fetching service application documents: $e');
      return {};
    }
  }

  /// Update parent application status (submitted/approved/rejected)
  Future<void> updateServiceApplicationStatus({
    required String applicationId,
    required String status,
    String? rejectionReason,
  }) async {
    try {
      final updates = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      };

      await _firestore
          .collection('serviceApplications')
          .doc(applicationId)
          .set(updates, SetOptions(merge: true));
    } catch (e) {
      print('❌ Error updating service application status: $e');
      rethrow;
    }
  }

  /// Returns a list of documentIds that are still missing uploads
  Future<List<String>> validateRequiredDocumentsUploaded({
    required String userId,
    required String serviceId,
    required String applicationId,
    required List<Map<String, dynamic>> documentRequirements,
  }) async {
    try {
      final uploadedDocs = await getServiceApplicationDocuments(applicationId);
      final missing = <String>[];

      for (final doc in documentRequirements) {
        final isPhotoRequired = doc['photoRequired'] ?? false;
        final documentId = doc['id'] as String? ?? '';

        if (!isPhotoRequired || documentId.isEmpty) continue;

        final docData = uploadedDocs[documentId] as Map<String, dynamic>?;
        final hasImage = docData != null &&
            (docData['imageUrl'] as String?)?.isNotEmpty == true;

        if (!hasImage) {
          missing.add(documentId);
          print(
              '❌ Required document missing for $userId/$serviceId: $documentId');
        }
      }

      if (missing.isEmpty) {
        print('✅ All required documents uploaded for $userId/$serviceId');
      }

      return missing;
    } catch (e) {
      print('❌ Error validating required documents: $e');
      return documentRequirements
          .where((doc) => (doc['photoRequired'] ?? false) == true)
          .map((doc) => doc['id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    }
  }

  /// Create and submit a service application for admin review
  /// This creates the application document that appears in the admin verification panel
  Future<void> createServiceApplication({
    required String userId,
    required String serviceId,
    String? serviceName,
    required String fullName,
    required String mobile,
    required String email,
    required List<Map<String, dynamic>> documentRequirements,
  }) async {
    try {
      final applicationId = '${userId}_$serviceId';
      final user = _auth.currentUser;

      if (user == null || user.uid != userId) {
        throw Exception('User not authenticated');
      }

      // Get user document to fetch uploaded document URLs
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final documents = userData?['documents'] as Map<String, dynamic>? ?? {};

      print('📝 Creating service application:');
      print('   Application ID: $applicationId');
      print('   User: $fullName ($userId)');
      print('   Service: ${serviceName ?? serviceId} ($serviceId)');
      print('   Documents: $documents');

      // Create application document for admin verification
      await _firestore
          .collection('serviceApplications')
          .doc(applicationId)
          .set({
        'applicationId': applicationId,
        'userId': userId,
        'serviceId': serviceId,
        if (serviceName != null) 'serviceName': serviceName,
        'fullName': fullName,
        'phone': mobile,
        'email': email,
        'documents': documents, // URLs from users/{uid}.documents
        'status': 'pending', // pending, approved, rejected
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewedBy': null,
        'rejectionReason': null,
      }, SetOptions(merge: true));

      print('✅ Service application created: $applicationId');
      print('   Status: pending (awaiting admin review)');

      // VERIFICATION: Read back the document to confirm it was written
      final verifyDoc = await _firestore
          .collection('serviceApplications')
          .doc(applicationId)
          .get();
      if (verifyDoc.exists) {
        print('✅ VERIFICATION: Document exists in Firestore');
        print('   Data: ${verifyDoc.data()}');
      } else {
        print('❌ VERIFICATION FAILED: Document not found in Firestore!');
      }
    } catch (e) {
      print('❌ Error creating service application: $e');
      rethrow;
    }
  }

  // ============= BANNER MANAGEMENT =============

  /// Get active banners stream (real-time)
  Stream<List<Map<String, dynamic>>> getActiveBannersStream() {
    return _firestore.collection('banners').snapshots().map((snapshot) {
      debugPrint(
          '🎨 Banner stream update: ${snapshot.docs.length} total banners found');
      final List<Map<String, dynamic>> banners = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Include banner if it's active OR if active field doesn't exist (for backwards compatibility)
        final isActive =
            data['active'] != false; // Default to true if not specified

        if (isActive) {
          debugPrint('  - Banner ID: ${doc.id} (ACTIVE)');
          debugPrint('    imageUrl: ${data['imageUrl']}');
          debugPrint('    order: ${data['order']}');

          // Ensure imageUrl exists
          final imageUrl = (data['imageUrl'] ?? '') as String;

          // Fallback order: prefer explicit 'order', else use createdAt timestamp, else 0
          int orderVal = 0;
          try {
            if (data.containsKey('order') && data['order'] != null) {
              orderVal = (data['order'] as num).toInt();
            } else if (data['createdAt'] != null) {
              final created = data['createdAt'];
              // created could be a Timestamp or int
              if (created is int) {
                orderVal = created;
              } else if (created is DateTime) {
                orderVal = created.millisecondsSinceEpoch;
              } else if (created is Map && created['_seconds'] != null) {
                orderVal = (created['_seconds'] as int) * 1000;
              } else {
                try {
                  // cloud_firestore Timestamp
                  orderVal = (created as dynamic).millisecondsSinceEpoch as int;
                } catch (_) {
                  orderVal = 0;
                }
              }
            }
          } catch (_) {
            orderVal = 0;
          }

          banners.add({
            'id': doc.id,
            'imageUrl': imageUrl,
            'active': data['active'] ?? true,
            'order': orderVal,
            'linkUrl': data['linkUrl'],
            'createdAt': data['createdAt'],
          });
        } else {
          debugPrint('  - Banner ID: ${doc.id} (INACTIVE - skipped)');
        }
      }

      // Ensure sorted by order
      banners.sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
      debugPrint(
          '🎨 Final banner list: ${banners.length} banners after sorting');
      return banners;
    }).handleError((e) {
      debugPrint('❌ Error listening to banners: $e');
      return <Map<String, dynamic>>[];
    });
  }

  // ============= DYNAMIC DOCUMENT FIELDS =============

  /// Get service document fields from services/{serviceId} with real-time listener
  /// Returns a stream that updates instantly when admin modifies fields
  Stream<List<Map<String, dynamic>>> getServiceDocumentFieldsStream(
      String serviceId) {
    debugPrint('📋 Subscribing to document fields for service: $serviceId');

    return _firestore
        .collection('services')
        .doc(serviceId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        debugPrint('⚠️ Service document not found: $serviceId');
        return <Map<String, dynamic>>[];
      }

      final data = snapshot.data();
      if (data == null) {
        debugPrint('⚠️ Service data is null for: $serviceId');
        return <Map<String, dynamic>>[];
      }

      // Extract documentFields array
      final documentFields = data['documentFields'] as List<dynamic>?;

      if (documentFields == null || documentFields.isEmpty) {
        debugPrint('📄 No document fields defined for service: $serviceId');
        return <Map<String, dynamic>>[];
      }

      // Convert to List<Map<String, dynamic>> and sort by display order (if exists)
      final fields =
          documentFields.map((field) => field as Map<String, dynamic>).toList();

      debugPrint('✅ Document fields loaded: ${fields.length} fields');
      fields.asMap().forEach((index, field) {
        debugPrint('   Field $index: ${field['name']} (${field['type']})');
      });

      return fields;
    }).handleError((e) {
      debugPrint('❌ Error listening to document fields: $e');
      return <Map<String, dynamic>>[];
    });
  }
}
