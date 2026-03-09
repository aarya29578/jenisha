import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current Firebase Auth user
  User? get currentUser => _auth.currentUser;

  /// Check if user is authenticated in Firebase
  bool isAuthenticatedInFirebase() {
    return _auth.currentUser != null;
  }

  /// Get user document from Firestore
  /// Returns null if document doesn't exist
  Future<Map<String, dynamic>?> getUserDocument(String uid) async {
    try {
      print('🔍 Checking Firestore user document for UID: $uid');

      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        print('✅ User document found in Firestore');
        print('   Status: ${doc['status']}');
        print('   DocumentsCompleted: ${doc['documentsCompleted']}');
        print('   ApprovalStatus: ${doc['approvalStatus']}');
        return doc.data();
      } else {
        print('❌ No user document found - user needs to register');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching user document: $e');
      return null;
    }
  }

  /// Determine next navigation route based on auth state
  /// Returns the route the user should navigate to
  Future<String> getNextRoute() async {
    try {
      print('🚀 Determining next route...');

      // Step 1: Check Firebase Auth
      final fbUser = _auth.currentUser;

      if (fbUser == null) {
        print('📍 Route: /login (Not authenticated)');
        return '/login';
      }

      print('✅ Firebase Auth: User authenticated');
      print('   UID: ${fbUser.uid}');

      // Step 2: Check Firestore user document
      final userDoc = await getUserDocument(fbUser.uid);

      if (userDoc == null) {
        print('📍 Route: /registration (User document does NOT exist)');
        return '/registration';
      }

      // Step 3: Check user document fields
      final approvalStatus =
          userDoc['status'] ?? userDoc['approvalStatus'] ?? 'pending';
      final documentsCompleted = userDoc['documentsCompleted'] ?? false;

      print('✅ Firestore: User document exists');
      print('   ApprovalStatus: $approvalStatus');
      print('   DocumentsCompleted: $documentsCompleted');

      // Decision tree
      if (approvalStatus == 'approved') {
        print('📍 Route: /home (User APPROVED)');
        return '/home';
      } else if (approvalStatus == 'rejected') {
        print('📍 Route: /account-status (User REJECTED)');
        return '/account-status';
      } else if (approvalStatus == 'blocked') {
        print('📍 Route: /account-status (User BLOCKED)');
        return '/account-status';
      } else if (documentsCompleted == false) {
        print('📍 Route: /registration-documents (Documents INCOMPLETE)');
        return '/registration-documents';
      } else {
        print('📍 Route: /registration-status (Pending approval)');
        return '/registration-status';
      }
    } catch (e) {
      print('❌ Error determining next route: $e');
      return '/login';
    }
  }

  /// Check if user has completed registration (document exists)
  Future<bool> hasCompletedRegistration(String uid) async {
    try {
      final userDoc = await getUserDocument(uid);
      return userDoc != null;
    } catch (e) {
      print('❌ Error checking registration status: $e');
      return false;
    }
  }

  /// Check if user is trying to register with an email that already exists
  Future<bool> emailAlreadyRegistered(String email) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();

      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking email: $e');
      return false;
    }
  }

  /// Sign out user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('✅ User signed out');
    } catch (e) {
      print('❌ Error signing out: $e');
      rethrow;
    }
  }

  /// Listen to auth state changes
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}
