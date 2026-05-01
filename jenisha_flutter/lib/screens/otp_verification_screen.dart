import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String? phone;

  const OTPVerificationScreen(
      {Key? key, required this.verificationId, this.phone})
      : super(key: key);

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final List<FocusNode> _rawKeyFocusNodes =
      List.generate(6, (_) => FocusNode());
  int _timer = 30;
  Timer? _ticker;
  bool _canResend = false;
  String? _verificationId;
  int? _resendToken;
  bool _isSending = false;
  bool _isVerifying = false;
  String? _mobileArg;
  bool _sentOnce = false;

  @override
  void initState() {
    super.initState();
    // Initialize with verificationId passed via constructor (must come from codeSent)
    _verificationId = widget.verificationId;
    _mobileArg = widget.phone;
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_sentOnce) {
      // Do not trigger a new OTP send here. The verificationId must come from
      // Firebase's codeSent callback and be provided to this screen via the
      // constructor. Accept an optional phone passed in the constructor or via
      // route arguments as a fallback for display only.
      _mobileArg = widget.phone ??
          (ModalRoute.of(context)?.settings.arguments as String? ?? '');
      _sentOnce = true;
    }
  }

  void _startTimer() {
    _timer = 30;
    _canResend = false;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _timer--;
        if (_timer <= 0) {
          _canResend = true;
          _ticker?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    for (final f in _rawKeyFocusNodes) f.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) async {
    if (value.isEmpty) return;

    // If user pasted multiple digits into one field, distribute them
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '').split('');
      for (var i = 0; i < digits.length && i < 6; i++) {
        _controllers[i].text = digits[i];
      }
      final next = digits.length < 6 ? digits.length : 5;
      _focusNodes[next].requestFocus();
      setState(() {});
      return;
    }

    // Single digit entry
    if (!RegExp(r'^\d').hasMatch(value)) {
      _controllers[index].clear();
      return;
    }
    if (index < 5) _focusNodes[index + 1].requestFocus();
    setState(() {});
  }

  void _onKeyDown(int index, RawKeyEvent event) {
    if (event.isKeyPressed(LogicalKeyboardKey.backspace) &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _handleResend() {
    if (_canResend) {
      for (var c in _controllers) c.clear();
      _startTimer();
      _focusNodes[0].requestFocus();
      // Attempt resend
      if (_mobileArg != null && _mobileArg!.isNotEmpty) {
        _sendCode(_mobileArg!, forceResend: true);
      }
      setState(() {});
    }
  }

  Future<void> _sendCode(String mobile, {bool forceResend = false}) async {
    final phoneNumber = mobile.startsWith('+') ? mobile : '+91$mobile';

    // Basic validation: +91 followed by 10 digits
    final valid = RegExp(r'^\+91[6-9]\d{9}$').hasMatch(phoneNumber);
    print('PHONE NUMBER: $phoneNumber');
    if (!valid) {
      print('PHONE FORMAT INVALID: $phoneNumber');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid phone number format')),
        );
      }
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final auth = AuthService();
      await auth.sendOtp(mobile, forceResend: forceResend,
          onCodeSent: (vId, rToken) {
        setState(() {
          _verificationId = vId;
          _resendToken = rToken;
          _isSending = false;
          _canResend = false;
        });
        _startTimer();
      });

      // If AuthService already had verificationId available, copy it
      if (auth.verificationId != null) {
        setState(() {
          _verificationId = auth.verificationId;
          _resendToken = auth.resendToken;
        });
      }
    } catch (e) {
      print('verifyPhoneNumber threw: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send OTP: $e')),
        );
      }
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _postSignIn(User user) async {
    try {
      final userService = UserService();
      final userEmail = user.email ?? '';

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final status = (data['status'] as String?) ?? 'pending';

        userService.userType = 'existing';
        userService.registrationStatus = status;
        userService.userEmail = userEmail;
        userService.userName =
            (data['fullName'] as String?) ?? user.displayName ?? '';

        if (!mounted) return;

        if (status == 'approved') {
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        } else if (status == 'rejected') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Your application has been rejected. Please contact support.'),
                  backgroundColor: Colors.red),
            );
          }
          await FirebaseAuth.instance.signOut();
        } else if (status == 'blocked') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Your account has been blocked. Please contact support.'),
                  backgroundColor: Colors.red),
            );
          }
          await FirebaseAuth.instance.signOut();
        } else if (status == 'incomplete') {
          Navigator.pushNamedAndRemoveUntil(
              context, '/registration', (route) => false);
        } else {
          Navigator.pushNamedAndRemoveUntil(
              context, '/registration-status', (route) => false,
              arguments: 'pending');
        }
      } else {
        // New user - create draft document
        print(
            '🆕 [NEW USER] Creating draft user document for UID: ${user.uid}');
        final firestoreService = FirestoreService();
        await firestoreService.createDraftUserDocument(
          fullName: user.displayName ?? '',
          email: userEmail,
          phoneNumber: user.phoneNumber ?? '',
        );

        userService.userType = 'new';
        userService.registrationStatus = 'pending';
        userService.userEmail = userEmail;
        userService.userName = user.displayName ?? '';

        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
            context, '/registration', (route) => false);
      }
    } catch (e) {
      print('Post sign-in routing error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login succeeded but routing failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = widget.phone ?? _mobileArg ?? '';
    final displayPhone = mobile.startsWith('+')
        ? mobile
        : (mobile.isNotEmpty ? '+91 $mobile' : '');
    final localizations = AppLocalizations.of(context);
    final isOTPComplete = _otp.length == 6;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Back Button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back,
                          color: Color(0xFF666666), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        localizations.get('change_number'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Header Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.get('verify_otp'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localizations.get('enter_otp_sent_to'),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+91 $mobile',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // OTP Input Fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (i) {
                    return Container(
                      width: 48,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: RawKeyboardListener(
                        focusNode: _rawKeyFocusNodes[i],
                        onKey: (e) => _onKeyDown(i, e),
                        child: TextField(
                          controller: _controllers[i],
                          focusNode: _focusNodes[i],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: const Color(0xFFFAFAFA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFDDDDDD),
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFDDDDDD),
                                width: 2,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(8),
                          ),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                          onChanged: (v) => _onChanged(i, v),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),

                // Verify Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isOTPComplete && !_isVerifying
                        ? () async {
                            final activeVerId =
                                _verificationId ?? widget.verificationId;

                            // Safety: verificationId must be provided by the codeSent callback
                            if (activeVerId == null || activeVerId.isEmpty) {
                              print('ERROR: verificationId missing');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'No verification ID. Please resend OTP.')),
                                );
                              }
                              return;
                            }

                            print('VERIFYING OTP');
                            print('VERIFICATION ID: $activeVerId');

                            setState(() {
                              _isVerifying = true;
                            });

                            try {
                              final credential = PhoneAuthProvider.credential(
                                verificationId: activeVerId,
                                smsCode: _otp,
                              );

                              final result = await FirebaseAuth.instance
                                  .signInWithCredential(credential);
                              print('LOGIN SUCCESS uid=${result.user?.uid}');

                              if (result.user != null)
                                await _postSignIn(result.user!);
                            } on FirebaseAuthException catch (e) {
                              print('VERIFY ERROR: ${e.code}');
                              print('VERIFY ERROR MSG: ${e.message}');
                              String msg;
                              switch (e.code) {
                                case 'invalid-verification-code':
                                case 'invalid-verification-id':
                                  msg = 'Invalid OTP. Please try again.';
                                  break;
                                case 'session-expired':
                                  msg = 'OTP session expired. Please resend.';
                                  break;
                                case 'too-many-requests':
                                  msg = 'Too many attempts. Try again later.';
                                  break;
                                default:
                                  msg = e.message ?? 'Verification failed';
                              }
                              if (mounted)
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(content: Text(msg)));
                            } catch (e) {
                              print('VERIFY ERROR: $e');
                              if (mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text('Verification error: $e')));
                            } finally {
                              if (mounted) setState(() => _isVerifying = false);
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOTPComplete && !_isVerifying
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFFCCCCCC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            localizations.get('verify_otp'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Resend OTP Section
                Center(
                  child: !_canResend
                      ? Text(
                          '${localizations.get('resend_otp_in')} ${_timer}s',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF666666),
                          ),
                        )
                      : GestureDetector(
                          onTap: _handleResend,
                          child: Text(
                            localizations.get('resend_otp'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
