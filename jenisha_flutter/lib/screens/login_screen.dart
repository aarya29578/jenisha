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
                              const SizedBox(height: 12),

                              // ID & Password Sign-In Button
                              ElevatedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (_) =>
                                              const _IdPasswordSheet(),
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF0F4FF),
                                  foregroundColor: const Color(0xFF1E40AF),
                                  side: const BorderSide(
                                    color: Color(0xFFBFCFFF),
                                    width: 1,
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                ),
                                icon:
                                    const Icon(Icons.badge_outlined, size: 20),
                                label: const Text(
                                  'Continue with ID & Password',
                                  style: TextStyle(
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

// ─────────────────────────────────────────────────────────────────────────────
// ID & Password bottom-sheet
// ─────────────────────────────────────────────────────────────────────────────

class _IdPasswordSheet extends StatefulWidget {
  const _IdPasswordSheet();

  @override
  State<_IdPasswordSheet> createState() => _IdPasswordSheetState();
}

class _IdPasswordSheetState extends State<_IdPasswordSheet> {
  /// null = mode-selection screen, 'new' = register, 'old' = login
  String? _mode;

  final _idController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _idController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _handleSubmit() async {
    final id = _idController.text.trim();
    final password = _passController.text;

    if (id.isEmpty) {
      _showError('Please enter your ID.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }
    if (_mode == 'new' && password != _confirmPassController.text) {
      _showError('Passwords do not match.');
      return;
    }

    // Synthetic email so Firebase Auth email/password flow works
    final syntheticEmail = '${id.toLowerCase()}@jenisha.app';

    setState(() => _isLoading = true);

    try {
      if (_mode == 'new') {
        // ── REGISTER ──────────────────────────────────────────────────
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: syntheticEmail,
          password: password,
        );
        final user = cred.user!;

        final firestoreService = FirestoreService();
        await firestoreService.createDraftUserDocument(
          fullName: '',
          email: syntheticEmail,
          phoneNumber: '',
        );

        // Store the human-readable custom ID alongside the document
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'customId': id,
          'authMethod': 'id_password',
        }, SetOptions(merge: true));

        final userService = UserService();
        userService.userType = 'new';
        userService.registrationStatus = 'incomplete';
        userService.userEmail = syntheticEmail;

        if (!mounted) return;
        Navigator.of(context).pop();
        Navigator.pushNamedAndRemoveUntil(
            context, '/registration', (route) => false);
      } else {
        // ── LOGIN ──────────────────────────────────────────────────────
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: syntheticEmail,
          password: password,
        );
        final user = cred.user!;

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!mounted) return;

        if (!userDoc.exists) {
          _showError('No account found for this ID. Please register first.');
          await FirebaseAuth.instance.signOut();
          setState(() => _isLoading = false);
          return;
        }

        final data = userDoc.data()!;
        final status = (data['status'] as String?) ?? 'pending';

        final userService = UserService();
        userService.userType = 'existing';
        userService.registrationStatus = status;
        userService.userEmail = syntheticEmail;
        userService.userName = (data['fullName'] as String?) ?? 'User';

        Navigator.of(context).pop();

        if (status == 'approved') {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        } else if (status == 'rejected' || status == 'blocked') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Your account has been blocked or rejected. Please contact support.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
          await FirebaseAuth.instance.signOut();
        } else if (status == 'incomplete') {
          Navigator.pushNamedAndRemoveUntil(
              context, '/registration', (route) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(
              context, '/registration-status', (route) => false,
              arguments: 'pending');
        }
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'This ID is already registered. Use "Old User" to sign in.';
          break;
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'Invalid ID or password.';
          break;
        case 'weak-password':
          msg = 'Password is too weak. Use at least 6 characters.';
          break;
        case 'too-many-requests':
          msg = 'Too many attempts. Please try again later.';
          break;
        default:
          msg = 'Authentication failed. ${e.message ?? ''}';
      }
      if (mounted) {
        _showError(msg);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        _showError('Error: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: _mode == null ? _buildModeSelection() : _buildForm(),
      ),
    );
  }

  Widget _buildModeSelection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dragHandle(),
        const SizedBox(height: 20),
        const Text(
          'Continue with ID & Password',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select your account type to continue',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 28),
        _ModeCard(
          icon: Icons.person_add_alt_1_outlined,
          title: 'New User',
          subtitle: 'Create a new account with ID & password',
          color: const Color(0xFF1E40AF),
          onTap: () => setState(() => _mode = 'new'),
        ),
        const SizedBox(height: 12),
        _ModeCard(
          icon: Icons.login_rounded,
          title: 'Old User',
          subtitle: 'Sign in with your existing ID & password',
          color: const Color(0xFF065F46),
          onTap: () => setState(() => _mode = 'old'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildForm() {
    final isNew = _mode == 'new';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _dragHandle(),
        const SizedBox(height: 16),
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() {
                _mode = null;
                _idController.clear();
                _passController.clear();
                _confirmPassController.clear();
              }),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Color(0xFF374151)),
            ),
            const SizedBox(width: 12),
            Text(
              isNew ? 'New User Registration' : 'Sign In',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _label('User ID'),
        const SizedBox(height: 6),
        TextField(
          controller: _idController,
          textInputAction: TextInputAction.next,
          decoration: _inputDeco(
              hint: 'Enter your unique ID', icon: Icons.badge_outlined),
        ),
        const SizedBox(height: 16),
        _label('Password'),
        const SizedBox(height: 6),
        TextField(
          controller: _passController,
          obscureText: _obscurePass,
          textInputAction: isNew ? TextInputAction.next : TextInputAction.done,
          onSubmitted: isNew ? null : (_) => _handleSubmit(),
          decoration: _inputDeco(
            hint: 'Enter password (min 6 chars)',
            icon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: Colors.grey.shade500,
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
        ),
        if (isNew) ...[
          const SizedBox(height: 16),
          _label('Confirm Password'),
          const SizedBox(height: 6),
          TextField(
            controller: _confirmPassController,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleSubmit(),
            decoration: _inputDeco(
              hint: 'Re-enter password',
              icon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: Colors.grey.shade500,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isNew ? const Color(0xFF1E40AF) : const Color(0xFF065F46),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    isNew ? 'Register & Continue' : 'Sign In',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _dragHandle() => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151)),
      );

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1E40AF), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Mode selection card widget
// ─────────────────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: color)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
