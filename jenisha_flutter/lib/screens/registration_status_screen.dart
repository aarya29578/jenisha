import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class RegistrationStatusScreen extends StatefulWidget {
  const RegistrationStatusScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationStatusScreen> createState() =>
      _RegistrationStatusScreenState();
}

class _RegistrationStatusScreenState extends State<RegistrationStatusScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Stream<Map<String, dynamic>?> _statusStream;
  StreamSubscription<Map<String, dynamic>?>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _statusStream = _firestoreService.getCurrentUserStatusStream();
    // Auto-navigate to home as soon as admin approves the account
    _statusSubscription = _statusStream.listen((data) {
      if (!mounted) return;
      if (data != null && data['status'] == 'approved') {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  void _handleRejectionRetry(String rejectionReason) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Rejection reason: $rejectionReason\nPlease resubmit with corrections.'),
        backgroundColor: Theme.of(context).extension<CustomColors>()!.warning,
        duration: const Duration(seconds: 4),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: _statusStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(
                          Theme.of(context).primaryColor),
                    ),
                    const SizedBox(height: 16),
                    Text(
                        AppLocalizations.of(context)
                            .translate('loading_status'),
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF666666))),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                        AppLocalizations.of(context)
                            .translate('error_loading_status'),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1a1a1a))),
                    const SizedBox(height: 8),
                    Text(
                        AppLocalizations.of(context)
                            .translate('try_again_later'),
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF666666))),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                      ),
                      child: Text(
                          AppLocalizations.of(context).translate('go_back')),
                    ),
                  ],
                ),
              );
            }

            final userData = snapshot.data!;
            final status = userData['status'] ?? 'pending';
            final fullName = userData['fullName'] ?? 'User';
            final reviewedAt = userData['reviewedAt'];
            final reviewedBy = userData['reviewedBy'];
            final rejectionReason = userData['rejectionReason'];

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Text(
                        AppLocalizations.of(context)
                            .translate('registration_status'),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827))),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Status Card
                        if (status == 'pending')
                          _buildPendingCard(fullName)
                        else if (status == 'approved')
                          _buildApprovedCard(fullName, reviewedBy)
                        else if (status == 'rejected')
                          _buildRejectedCard(fullName, rejectionReason),

                        const SizedBox(height: 20),

                        // User Details
                        _buildUserDetailsSection(userData),

                        const SizedBox(height: 20),

                        // Action Buttons
                        if (status == 'approved')
                          ElevatedButton(
                            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                                context, '/home', (route) => false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                                AppLocalizations.of(context)
                                    .translate('continue_to_app'),
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                          )
                        else if (status == 'rejected')
                          Column(
                            children: [
                              ElevatedButton(
                                onPressed: () => _handleRejectionRetry(
                                    rejectionReason ?? ''),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(
                                    AppLocalizations.of(context)
                                        .translate('resubmit_registration'),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () async {
                                  await FirebaseAuth.instance.signOut();
                                  if (mounted) {
                                    Navigator.pushNamedAndRemoveUntil(
                                        context, '/login', (route) => false);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF3F4F6),
                                  foregroundColor: const Color(0xFF666666),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text(
                                    AppLocalizations.of(context)
                                        .translate('logout'),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              // Waiting indicator
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFF59E0B), width: 1),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                            Color(0xFFF59E0B)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Waiting for admin approval. You will be notified automatically.',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF92400E)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    side: BorderSide(
                                        color: Colors.grey.shade200)),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.phone,
                                          color: Color(0xFF374151)),
                                      const SizedBox(width: 8),
                                      Text(localizations.get('contact_support'))
                                    ]),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                  onPressed: () async {
                                    await FirebaseAuth.instance.signOut();
                                    if (mounted) {
                                      Navigator.pushNamedAndRemoveUntil(
                                          context, '/login', (route) => false);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF3F4F6),
                                      foregroundColor: const Color(0xFF666666),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10))),
                                  child: Text(localizations.get('logout'),
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600))),
                            ],
                          ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPendingCard(String fullName) {
    final localizations = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(localizations.get('pending'),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.schedule, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(localizations.get('pending_admin_approval'),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text('${localizations.get('hello')} $fullName!',
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF666666))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            localizations.get('registration_under_review'),
            style: const TextStyle(
                fontSize: 14, color: Color(0xFF666666), height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedCard(String fullName, dynamic reviewedBy) {
    final localizations = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(localizations.get('approved'),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(localizations.get('account_approved'),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16A34A))),
                    const SizedBox(height: 4),
                    Text('${localizations.get('welcome')}, $fullName!',
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF666666))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            localizations.get('account_approved_message'),
            style: const TextStyle(
                fontSize: 14, color: Color(0xFF666666), height: 1.6),
          ),
          if (reviewedBy != null) ...[
            const SizedBox(height: 12),
            Text(
              '${localizations.get('reviewed_by')}: $reviewedBy',
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF999999),
                  fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRejectedCard(String fullName, dynamic rejectionReason) {
    final localizations = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(localizations.get('rejected'),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cancel, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(localizations.get('registration_rejected'),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626))),
                    const SizedBox(height: 4),
                    Text(
                        '${localizations.get('please_review_feedback')}, $fullName',
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF666666))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFDC2626), width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.get('rejection_reason_label'),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    rejectionReason,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF1a1a1a), height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            localizations.get('resubmit_message'),
            style: const TextStyle(
                fontSize: 14, color: Color(0xFF666666), height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDetailsSection(Map<String, dynamic> userData) {
    final localizations = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.get('registration_details'),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1a1a1a))),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E5E5)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildDetailRow(localizations.get('full_name'),
                  userData['fullName'] ?? localizations.get('na')),
              _buildDetailRow(localizations.get('shop_name'),
                  userData['shopName'] ?? localizations.get('na')),
              _buildDetailRow(localizations.get('phone'),
                  userData['phone'] ?? localizations.get('na')),
              _buildDetailRow(localizations.get('email'),
                  userData['email'] ?? localizations.get('na')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE5E5E5), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF666666))),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1a1a1a))),
        ],
      ),
    );
  }
}
