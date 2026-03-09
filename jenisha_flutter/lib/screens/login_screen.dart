import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../services/google_auth_service.dart';
import '../services/firestore_service.dart';
import '../l10n/app_localizations.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  bool get _isValid =>
      _phoneController.text.length == 10 &&
      _phoneController.text.runes.every((r) => r >= 48 && r <= 57);

  void _handleGoogleSignIn() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _googleAuthService.signInWithGoogle();

      if (!mounted) return;

      if (user != null) {
        // User successfully authenticated with Google
        final userService = UserService();

        // Fetch user's email from Firebase Auth
        final userEmail = user.email ?? '';

        print('✅ User logged in via Google');
        print('   Email: $userEmail');
        print('   Firebase UID: ${user.uid}');

        // Check Firestore to determine next step
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          // User is registered - route based on approval status
          final userService = UserService();
          final status = userDoc['status'] ?? 'pending';

          userService.userType = 'existing';
          userService.registrationStatus = status;
          userService.userEmail = userEmail;
          userService.userName = userDoc['fullName'] ?? 'User';

          if (!mounted) return;

          if (status == 'approved') {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (route) => false,
            );
          } else if (status == 'rejected') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Your application has been rejected. Please contact support.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
            await _googleAuthService.signOut();
            setState(() {
              _isLoading = false;
            });
          } else if (status == 'blocked') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                    'Your account has been blocked. Please contact support.'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
            await _googleAuthService.signOut();
            setState(() {
              _isLoading = false;
            });
          } else if (status == 'incomplete') {
            // User started registration but never submitted - send back to form
            print(
                '⏸️ [RETURNING USER] Registration incomplete - redirecting to form');
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/registration',
              (route) => false,
            );
          } else {
            // Status is 'pending' - show pending approval screen
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/registration-status',
              (route) => false,
              arguments: 'pending',
            );
          }
        } else {
          // Not registered yet - CREATE USER DOCUMENT FIRST
          print('🆕 [NEW USER] Creating user document in Firestore');
          print('   UID: ${user.uid}');
          print('   Email: $userEmail');
          print('   DisplayName: ${user.displayName}');

          try {
            // Create a DRAFT document only (status: 'incomplete')
            // Status will be set to 'pending' ONLY when user clicks Submit on the form
            final firestoreService = FirestoreService();
            await firestoreService.createDraftUserDocument(
              fullName: user.displayName ?? '',
              email: userEmail,
              phoneNumber: user.phoneNumber ?? '',
            );

            print(
                '✅ [NEW USER] Draft user document created (status: incomplete)');
            print(
                '   Will become pending ONLY after user submits the full form');

            final userService = UserService();
            userService.userType = 'new';
            userService.registrationStatus = 'pending';
            userService.userEmail = userEmail;
            userService.userName = user.displayName ?? 'User';

            if (!mounted) return;

            // Navigate to registration form
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/registration',
              (route) => false,
            );
          } catch (e) {
            print('❌ [NEW USER] Failed to create user document: $e');
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Registration failed: $e'),
                backgroundColor: Colors.red,
              ),
            );

            await _googleAuthService.signOut();
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    } on Exception catch (e) {
      if (!mounted) return;

      String errorMessage = 'Google Sign-In failed';

      if (e.toString().contains('cancelled')) {
        // User cancelled the sign-in
        setState(() {
          _isLoading = false;
        });
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: SizedBox(
            height: MediaQuery.of(context).size.height -
                MediaQuery.of(context).padding.top -
                MediaQuery.of(context).padding.bottom,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          // Logo Section
                          Padding(
                            padding: const EdgeInsets.only(top: 32, bottom: 48),
                            child: Column(
                              children: [
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 200,
                                      maxHeight: 120,
                                    ),
                                    child: Container(
                                      // Match scaffold background so the area blends
                                      // seamlessly and any thin artifact line is hidden
                                      color: Theme.of(context)
                                          .scaffoldBackgroundColor,
                                      alignment: Alignment.center,
                                      child: Image.asset(
                                        'images/log.png',
                                        fit: BoxFit.contain,
                                        gaplessPlayback: true,
                                        filterQuality: FilterQuality.high,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  localizations.get('app_title'),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  localizations.get('app_subtitle'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF888888),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Login Form
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                localizations.get('login_to_account'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                localizations.get('enter_mobile_number'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Mobile Number Input
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localizations.get('mobile_number'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Stack(
                                    children: [
                                      TextField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.number,
                                        maxLength: 10,
                                        onChanged: (value) => setState(() {}),
                                        decoration: InputDecoration(
                                          counterText: '',
                                          filled: true,
                                          fillColor: Colors.white,
                                          hintText: localizations
                                              .get('enter_10_digit_mobile'),
                                          hintStyle: const TextStyle(
                                            color: Color(0xFFCCCCCC),
                                            fontSize: 14,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.fromLTRB(
                                                  48, 12, 16, 12),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                              color: Theme.of(context)
                                                  .primaryColor,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const Positioned(
                                        left: 12,
                                        top: 14,
                                        child: Text(
                                          '+91',
                                          style: TextStyle(
                                            color: Color(0xFF888888),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_phoneController.text.isNotEmpty &&
                                      !_isValid)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Please enter a valid 10-digit mobile number',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red[500],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Send OTP Button
                              ElevatedButton(
                                onPressed: _isValid
                                    ? () {
                                        // Initialize user service with default user type
                                        // In real app, this comes from backend after OTP validation
                                        final userService = UserService();
                                        userService.userType =
                                            'new'; // Default: new user needs registration (matches React demo 'login' mode)
                                        userService.registrationStatus =
                                            'pending';

                                        Navigator.pushNamed(
                                          context,
                                          '/otp',
                                          arguments: _phoneController.text,
                                        );
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isValid
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey.shade300,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                  disabledForegroundColor: Colors.white,
                                ),
                                child: Text(
                                  localizations.get('send_otp'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Helper Note
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  localizations.get('otp_note'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF333333),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Divider with text
                              Row(
                                children: [
                                  const Expanded(
                                    child: Divider(
                                      color: Color(0xFFDDDDDD),
                                      height: 1,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text(
                                      localizations.get('or'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF888888),
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    child: Divider(
                                      color: Color(0xFFDDDDDD),
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Google Sign-In Button
                              ElevatedButton.icon(
                                onPressed:
                                    _isLoading ? null : _handleGoogleSignIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF333333),
                                  side: const BorderSide(
                                    color: Color(0xFFDDDDDD),
                                    width: 1,
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                icon: _isLoading
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.grey[600]!,
                                          ),
                                        ),
                                      )
                                    : Image.asset(
                                        'assets/google_icon.png',
                                        width: 20,
                                        height: 20,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Icon(
                                            Icons.account_circle,
                                            size: 20,
                                            color: Colors.grey[700],
                                          );
                                        },
                                      ),
                                label: Text(
                                  _isLoading
                                      ? localizations.get('signing_in')
                                      : localizations
                                          .get('continue_with_google'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Footer
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        localizations.get('terms_agreement'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF888888),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizations.get('version_info'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFAAAAAA),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
