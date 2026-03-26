import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/translated_text.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Stream<DocumentSnapshot> _userStream;
  bool _notificationsEnabled = false;
  bool _isUploading = false;

  // Payment details edit state
  bool _editingUpi = false;
  bool _editingBank = false;
  bool _savingUpi = false;
  bool _savingBank = false;
  final _upiEditController = TextEditingController();
  final _bankNameEditController = TextEditingController();
  final _bankAccountEditController = TextEditingController();
  final _bankIfscEditController = TextEditingController();
  final _bankHolderEditController = TextEditingController();

  @override
  void dispose() {
    _upiEditController.dispose();
    _bankNameEditController.dispose();
    _bankAccountEditController.dispose();
    _bankIfscEditController.dispose();
    _bankHolderEditController.dispose();
    super.dispose();
  }

  Future<void> _saveUpi() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _savingUpi = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'upiId': _upiEditController.text.trim()});
      if (mounted) {
        setState(() => _editingUpi = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context).get('withdrawal_details_saved')),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingUpi = false);
    }
  }

  Future<void> _saveBank() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _savingBank = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'bankDetails': {
          'bankName': _bankNameEditController.text.trim(),
          'holderName': _bankHolderEditController.text.trim(),
          'accountNumber': _bankAccountEditController.text.trim(),
          'ifsc': _bankIfscEditController.text.trim().toUpperCase(),
        },
      });
      if (mounted) {
        setState(() => _editingBank = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context).get('withdrawal_details_saved')),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingBank = false);
    }
  }

  Future<void> pickProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final XFile? pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      const String uploadUrl =
          'https://jenishaonlineservice.com/uploads/upload_profile.php';

      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.fields['userId'] = user.uid;
      request.files.add(await http.MultipartFile.fromPath(
        'profile',
        pickedFile.path,
        filename: 'profile_${user.uid}.jpg',
      ));

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = json.decode(response.body) as Map<String, dynamic>;
        if (result['success'] == true) {
          final String imageUrl = result['imageUrl'] as String;
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'profilePhotoUrl': imageUrl});
        } else {
          throw Exception(result['error'] ?? 'Upload failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Text(localizations.get('no_user_logged_in')),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        title: Text(
          localizations.get('profile'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation(Theme.of(context).primaryColor),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                  '${localizations.get('error_loading_profile')}: ${snapshot.error}'),
            );
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final fullName = userData?['fullName'] ?? 'User';
          final phone = userData?['phone'] ?? 'N/A';
          final email = userData?['email'] ?? 'N/A';
          final profilePhotoUrl = userData?['profilePhotoUrl'] as String?;
          final walletBalance =
              (userData?['walletBalance'] as num?)?.toDouble() ?? 0.0;
          final upiId = userData?['upiId'] as String?;
          final bankDetails = userData?['bankDetails'] as Map<String, dynamic>?;

          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _isUploading ? null : pickProfileImage,
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.18),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.4),
                                            width: 2),
                                      ),
                                      child: _isUploading
                                          ? const Center(
                                              child: SizedBox(
                                                width: 28,
                                                height: 28,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation(
                                                          Colors.white),
                                                ),
                                              ),
                                            )
                                          : ClipOval(
                                              child: profilePhotoUrl != null &&
                                                      profilePhotoUrl.isNotEmpty
                                                  ? Image.network(
                                                      profilePhotoUrl,
                                                      width: 64,
                                                      height: 64,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context,
                                                              error,
                                                              stackTrace) =>
                                                          const Icon(
                                                        Icons.person,
                                                        color: Colors.white,
                                                        size: 32,
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.person,
                                                      color: Colors.white,
                                                      size: 32,
                                                    ),
                                            ),
                                    ),
                                    if (!_isUploading)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt,
                                            size: 14,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TranslatedText(
                                    fullName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID: ${user.uid.substring(0, 8)}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context)
                                          .extension<CustomColors>()
                                          ?.success ??
                                      const Color(0xFF4CAF50),
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  localizations.get('kyc_verified'),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // ── Wallet Balance ────────────────────────────────
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.account_balance_wallet,
                                      color: Colors.white70,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      localizations.get('wallet_balance'),
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 13),
                                    ),
                                  ],
                                ),
                                Text(
                                  '\u20b9${walletBalance.toStringAsFixed(walletBalance == walletBalance.roundToDouble() ? 0 : 2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Contact Information
                    Text(
                      localizations.get('contact_information'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context)
                                .extension<CustomColors>()
                                ?.textPrimary ??
                            Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                                .extension<CustomColors>()
                                ?.cardBackground ??
                            const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.phone,
                              color: Theme.of(context)
                                      .extension<CustomColors>()
                                      ?.textTertiary ??
                                  Colors.grey.shade600,
                              size: 20),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localizations.get('phone'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                          .extension<CustomColors>()
                                          ?.textTertiary ??
                                      Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                phone,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context)
                                          .extension<CustomColors>()
                                          ?.textPrimary ??
                                      Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                                .extension<CustomColors>()
                                ?.cardBackground ??
                            const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.email,
                              color: Theme.of(context)
                                      .extension<CustomColors>()
                                      ?.textTertiary ??
                                  Colors.grey.shade600,
                              size: 20),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localizations.get('email'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                          .extension<CustomColors>()
                                          ?.textTertiary ??
                                      Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context)
                                          .extension<CustomColors>()
                                          ?.textPrimary ??
                                      Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildPaymentDetailsSection(
                        upiId, bankDetails, localizations),
                    const SizedBox(height: 24),
                    const SizedBox(height: 24),
                    // Downloads
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(
                            context, '/downloaded-certificates');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.download,
                                color: Theme.of(context).primaryColor,
                                size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                localizations.get('downloads'),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF333333),
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: Color(0xFF888888), size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Settings
                    Text(
                      localizations.get('settings'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SwitchListTile(
                        title: Text(
                          localizations.get('notifications'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF333333),
                          ),
                        ),
                        value: _notificationsEnabled,
                        onChanged: (val) {
                          setState(() {
                            _notificationsEnabled = val;
                          });
                        },
                        activeColor: Theme.of(context).primaryColor,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 24),
                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(localizations.get('logout')),
                              content: Text.rich(
                                TextSpan(
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  children: [
                                    TextSpan(
                                        text:
                                            '${localizations.get('logout')}? '),
                                    TextSpan(
                                      text:
                                          (localizations.get('are_you_sure') ??
                                                  'are_you_sure')
                                              .replaceAll('_', ' '),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: Text(localizations.get('no') ?? 'No'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child:
                                      Text(localizations.get('yes') ?? 'Yes'),
                                ),
                              ],
                            ),
                          );

                          if (confirm != true) return;

                          try {
                            await AuthService().signOut();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Logout failed: $e')),
                              );
                            }
                            return;
                          }

                          if (!mounted) return;
                          Navigator.of(context, rootNavigator: true)
                              .pushNamedAndRemoveUntil('/login', (r) => false);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: Text(localizations.get('logout')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _maskAccountNumber(String acc) {
    if (acc.length <= 4) return acc;
    return '${'X' * (acc.length - 4)}${acc.substring(acc.length - 4)}';
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            color: Theme.of(context).extension<CustomColors>()?.textTertiary ??
                Colors.grey.shade600,
            size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                          .extension<CustomColors>()
                          ?.textTertiary ??
                      Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
                          .extension<CustomColors>()
                          ?.textPrimary ??
                      Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentDetailsSection(
    String? upiId,
    Map<String, dynamic>? bankDetails,
    AppLocalizations loc,
  ) {
    final hasUpi = upiId != null && upiId.isNotEmpty;
    final hasBank = bankDetails != null &&
        ((bankDetails['accountNumber'] as String?) ?? '').isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.get('payment_details'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).extension<CustomColors>()?.textPrimary ??
                Colors.black87,
          ),
        ),
        const SizedBox(height: 12),

        // UPI block
        if (hasUpi || _editingUpi) ...[
          _buildPaymentCard(
            icon: Icons.account_balance_wallet_outlined,
            typeLabel: 'UPI',
            accentColor: const Color(0xFF4C4CFF),
            isEditing: _editingUpi,
            viewContent: _buildInfoRow(
              icon: Icons.account_balance_wallet_outlined,
              label: loc.get('upi_id'),
              value: upiId ?? '—',
            ),
            editContent: _buildProfileTextField(
              controller: _upiEditController,
              label: loc.get('upi_id'),
              hint: loc.get('enter_upi_id'),
              icon: Icons.account_balance_wallet_outlined,
            ),
            onEdit: () {
              _upiEditController.text = upiId ?? '';
              setState(() => _editingUpi = true);
            },
            onCancel: () => setState(() => _editingUpi = false),
            onSave: _saveUpi,
            isSaving: _savingUpi,
          ),
          const SizedBox(height: 10),
        ],

        // Bank block
        if (hasBank || _editingBank) ...[
          _buildPaymentCard(
            icon: Icons.account_balance_outlined,
            typeLabel: loc.get('bank_transfer'),
            accentColor: const Color(0xFF4CAF50),
            isEditing: _editingBank,
            viewContent: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  icon: Icons.account_balance_outlined,
                  label: loc.get('bank_name'),
                  value:
                      (bankDetails?['bankName'] as String?)?.isNotEmpty == true
                          ? bankDetails!['bankName'] as String
                          : '—',
                ),
                const Divider(height: 20),
                _buildInfoRow(
                  icon: Icons.person_outline,
                  label: loc.get('account_holder_name'),
                  value: (bankDetails?['holderName'] as String?)?.isNotEmpty ==
                          true
                      ? bankDetails!['holderName'] as String
                      : '—',
                ),
                const Divider(height: 20),
                _buildInfoRow(
                  icon: Icons.credit_card,
                  label: loc.get('bank_account_number'),
                  value: () {
                    final acc = bankDetails?['accountNumber'] as String?;
                    return (acc != null && acc.isNotEmpty)
                        ? _maskAccountNumber(acc)
                        : '—';
                  }(),
                ),
                const Divider(height: 20),
                _buildInfoRow(
                  icon: Icons.code,
                  label: loc.get('ifsc_code'),
                  value: (bankDetails?['ifsc'] as String?)?.isNotEmpty == true
                      ? bankDetails!['ifsc'] as String
                      : '—',
                ),
              ],
            ),
            editContent: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileTextField(
                  controller: _bankNameEditController,
                  label: loc.get('bank_name'),
                  hint: loc.get('enter_bank_name'),
                  icon: Icons.account_balance_outlined,
                ),
                const SizedBox(height: 10),
                _buildProfileTextField(
                  controller: _bankHolderEditController,
                  label: loc.get('account_holder_name'),
                  hint: loc.get('enter_holder_name'),
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 10),
                _buildProfileTextField(
                  controller: _bankAccountEditController,
                  label: loc.get('bank_account_number'),
                  hint: loc.get('enter_account_number'),
                  icon: Icons.credit_card,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _buildProfileTextField(
                  controller: _bankIfscEditController,
                  label: loc.get('ifsc_code'),
                  hint: loc.get('enter_ifsc'),
                  icon: Icons.account_balance_wallet,
                  textCapitalization: TextCapitalization.characters,
                ),
              ],
            ),
            onEdit: () {
              _bankNameEditController.text =
                  bankDetails?['bankName'] as String? ?? '';
              _bankHolderEditController.text =
                  bankDetails?['holderName'] as String? ?? '';
              _bankAccountEditController.text =
                  bankDetails?['accountNumber'] as String? ?? '';
              _bankIfscEditController.text =
                  bankDetails?['ifsc'] as String? ?? '';
              setState(() => _editingBank = true);
            },
            onCancel: () => setState(() => _editingBank = false),
            onSave: _saveBank,
            isSaving: _savingBank,
          ),
          const SizedBox(height: 10),
        ],

        // Empty state
        if (!hasUpi && !hasBank && !_editingUpi && !_editingBank) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey.shade500, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc.get('no_payment_details'),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Add buttons (shown when a method is missing)
        if (!hasUpi && !_editingUpi || !hasBank && !_editingBank)
          Row(
            children: [
              if (!hasUpi && !_editingUpi)
                Expanded(
                  child: _buildAddButton(
                    label: 'Add UPI',
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () {
                      _upiEditController.clear();
                      setState(() => _editingUpi = true);
                    },
                  ),
                ),
              if (!hasUpi && !_editingUpi && !hasBank && !_editingBank)
                const SizedBox(width: 8),
              if (!hasBank && !_editingBank)
                Expanded(
                  child: _buildAddButton(
                    label: 'Add Bank',
                    icon: Icons.account_balance_outlined,
                    onTap: () {
                      _bankNameEditController.clear();
                      _bankHolderEditController.clear();
                      _bankAccountEditController.clear();
                      _bankIfscEditController.clear();
                      setState(() => _editingBank = true);
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildAddButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Theme.of(context).primaryColor),
        foregroundColor: Theme.of(context).primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildPaymentCard({
    required IconData icon,
    required String typeLabel,
    required Color accentColor,
    required bool isEditing,
    required Widget viewContent,
    required Widget editContent,
    required VoidCallback onEdit,
    required VoidCallback onCancel,
    required Future<void> Function() onSave,
    required bool isSaving,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isEditing
              ? Theme.of(context).primaryColor.withOpacity(0.4)
              : const Color(0xFFEEEEEE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 16, color: accentColor),
                ),
                const SizedBox(width: 10),
                Text(
                  typeLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const Spacer(),
                if (!isEditing)
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: isEditing
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      editContent,
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSaving ? null : onCancel,
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(7)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSaving ? null : onSave,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(7)),
                                elevation: 0,
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : Text(AppLocalizations.of(context)
                                      .get('save_details')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : viewContent,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF555555),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF888888)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide:
                  BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
