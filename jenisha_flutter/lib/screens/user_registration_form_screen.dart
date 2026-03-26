import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/firestore_service.dart';
import '../services/document_upload_service.dart';
import 'document_upload_widget.dart';
import 'registration_payment_screen.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class UserRegistrationFormScreen extends StatefulWidget {
  const UserRegistrationFormScreen({Key? key}) : super(key: key);

  @override
  State<UserRegistrationFormScreen> createState() =>
      _UserRegistrationFormScreenState();
}

class _UserRegistrationFormScreenState
    extends State<UserRegistrationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();

  // Form controllers
  final _fullNameController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _referralCodeController = TextEditingController();

  // Payment details collected during registration
  String _regPaymentMethod = 'upi';
  final _upiIdRegController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _bankHolderNameController = TextEditingController();

  // Referral code validation state
  bool _referralCodeChecking = false;
  String? _referralCodeStatus; // null=unchecked, 'valid', 'invalid'

  bool _isSubmitting = false;
  bool _submitConfirmed =
      false; // Guard: true only after user taps the Submit button
  int _currentStep = 0;

  // Profile photo (required)
  File? _profilePhotoFile;
  String? _profilePhotoUrl;
  bool _isUploadingPhoto = false;
  bool _profilePhotoError = false;

  // Document upload tracking
  Map<String, String> _uploadedDocuments = {};
  Stream<Map<String, dynamic>>? _userDocumentsStream;
  String? _userId; // resolved UID (Firebase or anonymous)

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
    _resolveUserId();
  }

  Future<void> _loadUserEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      setState(() {
        _emailController.text = user.email!;
      });
    }
    if (user != null && user.phoneNumber != null) {
      setState(() {
        _phoneController.text = user.phoneNumber!;
      });
    }
    if (user != null && user.displayName != null) {
      setState(() {
        _fullNameController.text = user.displayName!;
      });
    }
  }

  Future<void> _resolveUserId() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        // Phone-OTP new users have no Firebase Auth session — sign in
        // anonymously to get a real UID for document uploads.
        final cred = await FirebaseAuth.instance.signInAnonymously();
        user = cred.user;
        print('✅ [AUTH] Signed in anonymously: ${user?.uid}');
      } catch (e) {
        print('❌ [AUTH] Anonymous sign-in failed: $e');
      }
    }
    if (user != null && mounted) {
      setState(() {
        _userId = user!.uid;
        _userDocumentsStream =
            _firestoreService.getUserDocumentsStream(user.uid);
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _shopNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _referralCodeController.dispose();
    _upiIdRegController.dispose();
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _bankIfscController.dispose();
    _bankHolderNameController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto(ImageSource source) async {
    try {
      PermissionStatus status;
      if (source == ImageSource.camera) {
        status = await Permission.camera.request();
      } else {
        if (Platform.isAndroid) {
          status = await Permission.photos.request();
          if (!status.isGranted) status = await Permission.storage.request();
        } else {
          status = await Permission.photos.request();
        }
      }
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Permission denied. Please allow access in settings.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 75,
      );
      if (picked == null) return;

      final file = File(picked.path);
      setState(() {
        _profilePhotoFile = file;
        _profilePhotoUrl = null;
        _isUploadingPhoto = true;
        _profilePhotoError = false;
      });

      // Resolve Firebase user — await auth state to handle brief post-OTP delay
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        try {
          user = await FirebaseAuth.instance
              .authStateChanges()
              .where((u) => u != null)
              .first
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          // Still null after timeout — use a timestamp ID so the upload can proceed
        }
      }
      final String uploadUserId =
          user?.uid ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';

      // Upload to upload_profile.php (flat /profiles/ dir — no uid subdir needed)
      const String uploadUrl =
          'https://jenishaonlineservice.com/uploads/upload_profile.php';

      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.fields['userId'] = uploadUserId;
      request.files.add(await http.MultipartFile.fromPath(
        'profile',
        file.path,
        filename: 'profile_$uploadUserId.jpg',
      ));

      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode != 200) {
        throw Exception(
            'Server error ${response.statusCode}: ${response.body}');
      }

      final result = json.decode(response.body) as Map<String, dynamic>;
      if (result['success'] != true) {
        throw Exception(
            result['error'] ?? result['message'] ?? 'Upload failed');
      }

      final url = result['imageUrl'] as String?;
      if (url == null || url.isEmpty) {
        throw Exception('No imageUrl in server response');
      }

      setState(() {
        _profilePhotoUrl = url;
        _isUploadingPhoto = false;
      });

      if (mounted) {
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
      print('❌ Profile photo upload error: $e');
      setState(() {
        _profilePhotoFile = null;
        _profilePhotoUrl = null;
        _isUploadingPhoto = false;
        _profilePhotoError = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPhotoSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickProfilePhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickProfilePhoto(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a confirmation dialog. Only proceeds to submit if user explicitly taps "Submit".
  Future<void> _confirmAndSubmit() async {
    if (_isSubmitting) return;

    // Show confirmation dialog — user MUST tap Confirm to proceed
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).get('submit_registration')),
        content:
            Text(AppLocalizations.of(ctx).get('submit_registration_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(ctx).get('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.of(ctx).get('submit')),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      print('🚫 [SUBMIT] User cancelled the confirmation dialog.');
      return;
    }

    // User explicitly confirmed — set the guard and proceed
    setState(() {
      _submitConfirmed = true;
    });
    await _submitRegistration();
  }

  Future<void> _submitRegistration() async {
    if (!_submitConfirmed) {
      print('🚫 [SUBMIT] Blocked — _submitConfirmed is false. Ignoring call.');
      return;
    }

    // Aadhaar and PAN are required — double-check at submit time
    final hasAadhaar = _uploadedDocuments.containsKey('adhaar') &&
        _uploadedDocuments['adhaar']!.isNotEmpty;
    final hasPan = _uploadedDocuments.containsKey('pan') &&
        _uploadedDocuments['pan']!.isNotEmpty;
    if (!hasAadhaar || !hasPan) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!hasAadhaar && !hasPan
              ? 'Aadhaar Card and PAN Card are required'
              : !hasAadhaar
                  ? 'Aadhaar Card is required'
                  : 'PAN Card is required'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _currentStep = 3);
      return;
    }

    // Profile photo is required — must not allow empty URL in Firestore
    if (_profilePhotoUrl == null || _profilePhotoUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo is required'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _profilePhotoError = true;
        _currentStep = 0; // Go back to first step
      });
      return;
    }

    // Manual check instead of _formKey.currentState!.validate() which silently
    // fails on collapsed steps (e.g. phone-OTP users have no email on step 1)
    if (_fullNameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty ||
        _stateController.text.trim().isEmpty ||
        _pincodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.of(context).get('fill_all_required_fields')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final uid = _userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      // Save user registration data
      await _firestoreService.saveUserRegistration(
        fullName: _fullNameController.text.trim(),
        shopName: _shopNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        pincode: _pincodeController.text.trim(),
        profilePhotoUrl: _profilePhotoUrl,
        referredBy: _referralCodeController.text.trim().toUpperCase().isNotEmpty
            ? _referralCodeController.text.trim().toUpperCase()
            : null,
      );

      print('✅ User registration saved successfully');
      print('   Documents uploaded: ${_uploadedDocuments.length}');

      // Save payment method details (merge — never overwrites other fields)
      final Map<String, dynamic> paymentData = {
        'paymentMethod': _regPaymentMethod,
      };
      if (_regPaymentMethod == 'upi') {
        final upiVal = _upiIdRegController.text.trim();
        if (upiVal.isNotEmpty) paymentData['upiId'] = upiVal;
      } else {
        final bankMap = <String, String>{};
        final acc = _bankAccountController.text.trim();
        final ifsc = _bankIfscController.text.trim().toUpperCase();
        final bankNm = _bankNameController.text.trim();
        final holder = _bankHolderNameController.text.trim();
        if (acc.isNotEmpty) bankMap['accountNumber'] = acc;
        if (ifsc.isNotEmpty) bankMap['ifsc'] = ifsc;
        if (bankNm.isNotEmpty) bankMap['bankName'] = bankNm;
        if (holder.isNotEmpty) bankMap['holderName'] = holder;
        if (bankMap.isNotEmpty) paymentData['bankDetails'] = bankMap;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(paymentData, SetOptions(merge: true));

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)
              .get('registration_submitted_success')),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Navigate to registration status screen
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/registration-status',
        (route) => false,
        arguments: 'pending',
      );
    } catch (e) {
      print('❌ Registration submission failed: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${AppLocalizations.of(context).get('registration_failed')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitConfirmed =
              false; // Reset guard so it can't be triggered again accidentally
        });
      }
    }
  }

  Widget _buildPersonalDetailsStep() {
    final localizations = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            localizations.get('personal_details'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            localizations.get('provide_basic_info'),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 24),

          // ── Profile Photo (REQUIRED) ──────────────────────────────
          Center(
            child: Column(
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF333333),
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(text: localizations.get('profile_photo')),
                      const TextSpan(
                        text: ' *',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _isUploadingPhoto ? null : _showPhotoSourcePicker,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _profilePhotoError
                                ? Colors.red.shade400
                                : (_profilePhotoUrl != null
                                    ? Colors.green
                                    : Colors.grey.shade300),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 52,
                          backgroundColor: _profilePhotoError
                              ? Colors.red.shade50
                              : Colors.grey.shade100,
                          backgroundImage: _profilePhotoFile != null
                              ? FileImage(_profilePhotoFile!) as ImageProvider
                              : null,
                          child: _profilePhotoFile == null
                              ? Icon(
                                  Icons.person,
                                  size: 52,
                                  color: _profilePhotoError
                                      ? Colors.red.shade300
                                      : Colors.grey.shade400,
                                )
                              : null,
                        ),
                      ),
                      if (_isUploadingPhoto)
                        Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.45),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                      if (!_isUploadingPhoto)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_isUploadingPhoto)
                  Text(
                    'Uploading...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).primaryColor,
                    ),
                  )
                else if (_profilePhotoUrl != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle,
                          size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        'Photo uploaded',
                        style: TextStyle(
                            fontSize: 12, color: Colors.green.shade700),
                      ),
                    ],
                  )
                else if (_profilePhotoError)
                  Text(
                    'Profile photo is required',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  )
                else
                  Text(
                    'Tap to add photo',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // ── End Profile Photo ─────────────────────────────────────

          TextFormField(
            controller: _fullNameController,
            decoration: InputDecoration(
              labelText: localizations.get('full_name'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return localizations.get('enter_full_name');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _shopNameController,
            decoration: InputDecoration(
              labelText: localizations.get('shop_business_name'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.store),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return localizations.get('enter_shop_name');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: localizations.get('phone_number'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return localizations.get('enter_phone_number');
              }
              if (value.trim().length < 10) {
                return localizations.get('valid_phone_number');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: localizations.get('email_address'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              // Email is optional for phone-OTP users
              if (value != null &&
                  value.trim().isNotEmpty &&
                  !value.contains('@')) {
                return localizations.get('valid_email');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── Referral Code (Optional) ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _referralCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Referral Code (Optional)',
                    hintText: 'e.g. REF7TIQEDVX',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.card_giftcard),
                    suffixIcon: _referralCodeStatus == 'valid'
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : _referralCodeStatus == 'invalid'
                            ? const Icon(Icons.cancel, color: Colors.red)
                            : null,
                  ),
                  onChanged: (_) {
                    if (_referralCodeStatus != null) {
                      setState(() => _referralCodeStatus = null);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _referralCodeChecking ? null : _verifyReferralCode,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: _referralCodeChecking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Verify'),
                ),
              ),
            ],
          ),
          if (_referralCodeStatus == 'valid')
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text('✓ Referral code applied!',
                  style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
            ),
          if (_referralCodeStatus == 'invalid')
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text('Invalid referral code',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
            ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          // ── Payment Details ───────────────────────────────────
          Text(
            localizations.get('payment_details'),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            localizations.get('select_payment_method'),
            style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _regPaymentMethod = 'upi'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _regPaymentMethod == 'upi'
                          ? Theme.of(context).primaryColor
                          : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Theme.of(context).primaryColor),
                    ),
                    child: Text(
                      localizations.get('upi_transfer'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _regPaymentMethod == 'upi'
                            ? Colors.white
                            : Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _regPaymentMethod = 'bank'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _regPaymentMethod == 'bank'
                          ? Theme.of(context).primaryColor
                          : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Theme.of(context).primaryColor),
                    ),
                    child: Text(
                      localizations.get('bank_transfer'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _regPaymentMethod == 'bank'
                            ? Colors.white
                            : Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_regPaymentMethod == 'upi') ...[
            TextFormField(
              controller: _upiIdRegController,
              decoration: InputDecoration(
                labelText: localizations.get('upi_id'),
                hintText: localizations.get('enter_upi_id'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              ),
            ),
          ] else ...[
            TextFormField(
              controller: _bankNameController,
              decoration: InputDecoration(
                labelText: localizations.get('bank_name'),
                hintText: localizations.get('enter_bank_name'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.account_balance_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankHolderNameController,
              decoration: InputDecoration(
                labelText: localizations.get('account_holder_name'),
                hintText: localizations.get('enter_holder_name'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankAccountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: localizations.get('bank_account_number'),
                hintText: localizations.get('enter_account_number'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.credit_card),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankIfscController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: localizations.get('ifsc_code'),
                hintText: localizations.get('enter_ifsc'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.code),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _verifyReferralCode() async {
    final code = _referralCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _referralCodeChecking = true;
      _referralCodeStatus = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('referCode', isEqualTo: code)
          .limit(1)
          .get();
      if (mounted) {
        setState(() {
          _referralCodeStatus = snap.docs.isNotEmpty ? 'valid' : 'invalid';
          _referralCodeChecking = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _referralCodeChecking = false);
    }
  }

  Widget _buildAddressDetailsStep() {
    final localizations = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            localizations.get('address_details'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            localizations.get('provide_address'),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: localizations.get('address_line'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.location_on),
            ),
            maxLines: 2,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return localizations.get('enter_address');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cityController,
            decoration: InputDecoration(
              labelText: localizations.get('city'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.location_city),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return localizations.get('enter_city');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _stateController,
            decoration: InputDecoration(
              labelText: localizations.get('state'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.map),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return localizations.get('enter_state');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _pincodeController,
            decoration: InputDecoration(
              labelText: localizations.get('pincode'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.pin_drop),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return localizations.get('enter_pincode');
              }
              if (value.trim().length != 6) {
                return localizations.get('valid_pincode');
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPaymentStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: RegistrationPaymentScreen(
        onPaymentSuccess: () {
          // Payment successful, move to documents step
          setState(() {
            _currentStep = 3;
          });
        },
        onBack: () {
          // Go back to address step
          setState(() {
            _currentStep = 1;
          });
        },
      ),
    );
  }

  Widget _buildDocumentsStep() {
    if (_userId == null || _userDocumentsStream == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return _buildDocumentsContent(context, _userId!);
  }

  Widget _buildDocumentsContent(BuildContext context, String userId) {
    final localizations = AppLocalizations.of(context);

    // Create document requirement objects for Aadhaar and PAN (both required)
    final aadhaarRequirement = {
      'id': 'adhaar',
      'documentName': localizations.get('aadhaar_card'),
      'photoRequired': true,
      'required': true,
    };

    final panRequirement = {
      'id': 'pan',
      'documentName': localizations.get('pan_card'),
      'photoRequired': true,
      'required': true,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            localizations.get('upload_documents'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            localizations.get('upload_verification_docs'),
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.red.shade600, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Aadhaar Card and PAN Card are required to submit your application.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Document uploads with live stream
          if (_userDocumentsStream != null)
            StreamBuilder<Map<String, dynamic>>(
              stream: _userDocumentsStream,
              builder: (context, snapshot) {
                final uploadedDocs = snapshot.data ?? {};

                return Column(
                  children: [
                    // Aadhaar Card
                    DocumentUploadWidget(
                      key: const ValueKey('doc_adhaar'),
                      documentRequirement: aadhaarRequirement,
                      userId: userId,
                      existingImage: uploadedDocs['adhaar'],
                      onUploaded: (docId, imageUrl) {
                        print('✅ Aadhaar uploaded: $imageUrl');
                        setState(() {
                          _uploadedDocuments[docId] = imageUrl;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // PAN Card
                    DocumentUploadWidget(
                      key: const ValueKey('doc_pan'),
                      documentRequirement: panRequirement,
                      userId: userId,
                      existingImage: uploadedDocs['pan'],
                      onUploaded: (docId, imageUrl) {
                        print('✅ PAN uploaded: $imageUrl');
                        setState(() {
                          _uploadedDocuments[docId] = imageUrl;
                        });
                      },
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCustomStepIndicator() {
    final localizations = AppLocalizations.of(context);
    final steps = [
      {'number': 1, 'label': localizations.get('step_personal')},
      {'number': 2, 'label': localizations.get('step_address')},
      {'number': 3, 'label': localizations.get('step_payment')},
      {'number': 4, 'label': localizations.get('step_documents')},
    ];

    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: List.generate(steps.length * 2 - 1, (index) {
            if (index.isOdd) {
              // Connecting line
              return Container(
                width: 16,
                height: 1,
                color: Colors.grey[400],
                margin: const EdgeInsets.symmetric(horizontal: 4),
              );
            }

            final stepIndex = index ~/ 2;
            final step = steps[stepIndex];
            final isActive = _currentStep >= stepIndex;
            final isCompleted = _currentStep > stepIndex;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '${step['number']}',
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 60,
                  child: Text(
                    step['label'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      color: isActive
                          ? Theme.of(context).primaryColor
                          : Colors.grey[600],
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.get('agent_registration')),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomStepIndicator(),
            Expanded(
              child: Form(
                key: _formKey,
                child: Stepper(
                  type: StepperType.vertical,
                  currentStep: _currentStep,
                  margin: EdgeInsets.zero,
                  onStepContinue: () {
                    final localizations = AppLocalizations.of(context);
                    if (_currentStep == 0) {
                      // Validate personal details
                      if (_fullNameController.text.trim().isEmpty ||
                          _shopNameController.text.trim().isEmpty ||
                          _phoneController.text.trim().isEmpty ||
                          _emailController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                localizations.get('fill_all_required_fields')),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      // Profile photo is required
                      if (_isUploadingPhoto) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Please wait for photo upload to complete'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      if (_profilePhotoUrl == null) {
                        setState(() => _profilePhotoError = true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile photo is required'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _currentStep = 1;
                      });
                    } else if (_currentStep == 1) {
                      // Validate address details
                      if (_addressController.text.trim().isEmpty ||
                          _cityController.text.trim().isEmpty ||
                          _stateController.text.trim().isEmpty ||
                          _pincodeController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                localizations.get('fill_all_required_fields')),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _currentStep = 2; // Move to payment step
                      });
                    } else if (_currentStep == 2) {
                      // Payment step - handled by RegistrationPaymentScreen widget
                      // Do nothing here, the widget handles its own navigation
                    } else if (_currentStep == 3) {
                      // Documents step — validate Aadhaar and PAN before confirming
                      final hasAadhaar =
                          _uploadedDocuments.containsKey('adhaar') &&
                              _uploadedDocuments['adhaar']!.isNotEmpty;
                      final hasPan = _uploadedDocuments.containsKey('pan') &&
                          _uploadedDocuments['pan']!.isNotEmpty;

                      if (!hasAadhaar || !hasPan) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              !hasAadhaar && !hasPan
                                  ? 'Aadhaar Card and PAN Card are required'
                                  : !hasAadhaar
                                      ? 'Aadhaar Card is required'
                                      : 'PAN Card is required',
                            ),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                        return;
                      }
                      // Both documents uploaded — show confirmation dialog
                      _confirmAndSubmit();
                    }
                  },
                  onStepCancel: () {
                    if (_currentStep > 0) {
                      setState(() {
                        _currentStep--;
                      });
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  controlsBuilder: (context, details) {
                    final localizations = AppLocalizations.of(context);

                    // Payment step handles its own buttons
                    if (_currentStep == 2) {
                      return const SizedBox
                          .shrink(); // Hide default controls for payment step
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Row(
                        children: [
                          if (details.stepIndex > 0)
                            TextButton(
                              onPressed:
                                  _isSubmitting ? null : details.onStepCancel,
                              child: Text(localizations.get('back')),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _isSubmitting ? null : details.onStepContinue,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : Text(
                                      details.stepIndex == 3
                                          ? localizations.get('submit')
                                          : localizations.get('continue'),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  steps: [
                    Step(
                      title: const SizedBox.shrink(),
                      content: _buildPersonalDetailsStep(),
                      isActive: _currentStep >= 0,
                      state: _currentStep > 0
                          ? StepState.complete
                          : StepState.indexed,
                    ),
                    Step(
                      title: const SizedBox.shrink(),
                      content: _buildAddressDetailsStep(),
                      isActive: _currentStep >= 1,
                      state: _currentStep > 1
                          ? StepState.complete
                          : StepState.indexed,
                    ),
                    Step(
                      title: const SizedBox.shrink(),
                      content: _buildPaymentStep(),
                      isActive: _currentStep >= 2,
                      state: _currentStep > 2
                          ? StepState.complete
                          : StepState.indexed,
                    ),
                    Step(
                      title: const SizedBox.shrink(),
                      content: _buildDocumentsStep(),
                      isActive: _currentStep >= 3,
                      state: _currentStep > 3
                          ? StepState.complete
                          : StepState.indexed,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
