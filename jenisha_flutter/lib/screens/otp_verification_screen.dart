import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class OTPVerificationScreen extends StatefulWidget {
  const OTPVerificationScreen({Key? key}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
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
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = ModalRoute.of(context)?.settings.arguments as String? ?? '';
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
                    onPressed: isOTPComplete
                        ? () async {
                            final userService = UserService();
                            userService.isAuthenticated = true;

                            // Route based on user type (matches React logic)
                            String nextRoute = '/home';
                            Map<String, dynamic>? routeArguments;

                            if (userService.userType == 'new') {
                              nextRoute = '/registration';
                              // No arguments needed for registration form
                            } else if (userService.userType == 'pending') {
                              nextRoute = '/registration-status';
                              routeArguments = userService.registrationStatus
                                  as Map<String, dynamic>?;
                            } else if (userService.userType == 'blocked') {
                              nextRoute = '/account-status';
                              routeArguments = {'status': 'blocked'};
                            }

                            Navigator.pushReplacementNamed(
                              context,
                              nextRoute,
                              arguments: routeArguments,
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOTPComplete
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFFCCCCCC),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
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
