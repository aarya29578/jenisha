import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';

class ReferScreen extends StatefulWidget {
  const ReferScreen({Key? key}) : super(key: key);

  @override
  State<ReferScreen> createState() => _ReferScreenState();
}

class _ReferScreenState extends State<ReferScreen> {
  bool _copied = false;
  String _referralCode = '';
  bool _loading = true;
  bool _statsLoading = true;
  int _totalReferrals = 0;
  double _totalEarnings = 0.0;

  @override
  void initState() {
    super.initState();
    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    try {
      // Resolve Firebase user — phone-OTP users may have only an anonymous session
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // No Firebase session at all; can't load referral data
        if (mounted) {
          setState(() {
            _referralCode = '';
            _loading = false;
            _statsLoading = false;
          });
        }
        return;
      }

      final docRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await docRef.get();

      String code;
      if (doc.exists &&
          (doc.data()?['referCode'] as String? ?? '').isNotEmpty) {
        code = doc.data()!['referCode'] as String;
      } else {
        // Generate deterministic unique code and save it
        code = 'JENISHA${user.uid.substring(0, 8).toUpperCase()}';
        try {
          await docRef.set({'referCode': code}, SetOptions(merge: true));
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _referralCode = code;
        _loading = false;
      });

      // Count referred users and sum commission earnings in parallel
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .where('referredBy', isEqualTo: code)
            .get(),
        FirebaseFirestore.instance
            .collection('wallet_transactions')
            .where('agentId', isEqualTo: user.uid)
            .where('type', isEqualTo: 'commission')
            .get(),
      ]);

      final referredSnap = results[0];
      final commissionSnap = results[1];

      final earnings = commissionSnap.docs.fold<double>(
          0, (sum, d) => sum + ((d.data()['amount'] ?? 0) as num).toDouble());

      if (!mounted) return;
      setState(() {
        _totalReferrals = referredSnap.docs.length;
        _totalEarnings = earnings;
        _statsLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading referral data: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _statsLoading = false;
        });
      }
    }
  }

  void _copyCode() async {
    if (_referralCode.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _referralCode));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).get('code_copied'))));
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _shareWhatsApp() async {
    if (_referralCode.isEmpty) return;
    final localizations = AppLocalizations.of(context);
    const appLink =
        'https://play.google.com/store/apps/details?id=com.example.jenisha_flutter';
    final message = localizations
        .get('referral_share_message')
        .replaceAll('{code}', _referralCode)
        .replaceAll('{link}', appLink);
    final uri =
        Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not open WhatsApp for uri: $uri');
    }
  }

  Future<void> _shareSms() async {
    if (_referralCode.isEmpty) return;
    final localizations = AppLocalizations.of(context);
    const appLink =
        'https://play.google.com/store/apps/details?id=com.example.jenisha_flutter';
    final message = localizations
        .get('referral_share_message')
        .replaceAll('{code}', _referralCode)
        .replaceAll('{link}', appLink);
    final uri = Uri(scheme: 'sms', queryParameters: {'body': message});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not open SMS app for uri: $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        title: Text(
          localizations.get('refer_and_earn'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                localizations.get('refer_and_earn'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 16),
              // Referral Code Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.card_giftcard,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          localizations.get('your_referral_code'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _loading
                        ? const Center(
                            child: SizedBox(
                              height: 28,
                              width: 28,
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          )
                        : Text(
                            _referralCode.isEmpty ? '—' : _referralCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _copyCode,
                        icon: Icon(
                          _copied ? Icons.check : Icons.content_copy,
                          size: 18,
                        ),
                        label: Text(_copied
                            ? localizations.get('code_copied')
                            : localizations.get('copy_code')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Share Buttons
              Text(
                localizations.get('share_via'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _shareWhatsApp,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF9F3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.share,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              localizations.get('whatsapp'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _shareSms,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4a90e2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.sms,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              localizations.get('sms'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Earnings Summary
              Text(
                localizations.get('earnings_summary'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.people,
                                  color: Color(0xFF888888), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                localizations.get('total_referrals'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF888888),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _statsLoading
                              ? const SizedBox(
                                  height: 28,
                                  width: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF888888),
                                  ),
                                )
                              : Text(
                                  '$_totalReferrals',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.card_giftcard,
                                  color: Color(0xFF888888), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                localizations.get('total_earnings'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF888888),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _statsLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Color(0xFF333333)))
                              : Text(
                                  '₹${_totalEarnings.toStringAsFixed(_totalEarnings == _totalEarnings.roundToDouble() ? 0 : 2)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // How it works
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.get('how_it_works'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• ${localizations.get('share_referral_code')}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                        height: 1.6,
                      ),
                    ),
                    Text(
                      '• ${localizations.get('earn_on_first_service')}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                        height: 1.6,
                      ),
                    ),
                    Text(
                      '• ${localizations.get('no_limit_referrals')}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF666666),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
