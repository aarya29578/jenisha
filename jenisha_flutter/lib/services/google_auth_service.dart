import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';

class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();

  factory GoogleAuthService() {
    return _instance;
  }

  GoogleAuthService._internal();

  // Single global GoogleSignIn instance
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: [
    'email',
    'profile',
  ]);

  // Access FirebaseAuth via instance getter - no re-initialization
  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;

  /// Sign in with Google - Forces account chooser every time
  /// ✅ STABLE IMPLEMENTATION - No disconnect(), only signOut() + signIn()
  Future<User?> signInWithGoogle() async {
    try {
      // 1️⃣ Clear previous Google session to force account chooser
      // signOut() is reliable on Android, doesn't throw exceptions
      await _googleSignIn.signOut();
      print('✓ Previous Google session cleared');

      // 2️⃣ Trigger the Google authentication flow with account chooser
      // Account chooser will appear because no cached session exists
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // Handle user cancellation
      if (googleUser == null) {
        print('ℹ️ User cancelled Google sign-in');
        return null;
      }

      print('✓ User selected Google account: ${googleUser.email}');

      // Obtain the auth details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create credential for Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      // Log user data for verification
      final user = userCredential.user;
      if (user != null) {
        print('✅ Firebase User Created Successfully');
        print('   UID: ${user.uid}');
        print('   Email: ${user.email}');
        print('   Display Name: ${user.displayName}');
        print(
            '   Sign-in Provider: ${user.providerData.isNotEmpty ? user.providerData.first.providerId : 'unknown'}');
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('❌ Sign-in Error: $e');
      rethrow;
    }
  }

  /// Sign out from Google and Firebase
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      try {
        await _firebaseAuth.signOut();
      } catch (e) {
        print('Firebase sign out error: $e');
      }
    } catch (e) {
      print('Error during sign out: $e');
    }
  }

  /// Get current user
  User? getCurrentUser() {
    try {
      return _firebaseAuth.currentUser;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  /// Check if user is already signed in
  Future<bool> isUserSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  /// Get user's name and email from Google Sign-In
  Future<Map<String, String?>> getUserInfo() async {
    try {
      final GoogleSignInAccount? googleUser = _googleSignIn.currentUser;
      if (googleUser != null) {
        return {
          'name': googleUser.displayName,
          'email': googleUser.email,
          'uid': _firebaseAuth.currentUser?.uid,
        };
      }
      return {'name': null, 'email': null, 'uid': null};
    } catch (e) {
      print('Error getting user info: $e');
      return {'name': null, 'email': null, 'uid': null};
    }
  }
}
