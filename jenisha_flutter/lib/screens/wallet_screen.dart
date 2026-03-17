import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Convert ASCII digits to Devanagari digits when in Marathi mode.
String _toDevanagari(String text, AppLocalizations loc) {
  if (!loc.isMarathi) return text;
  const digitMap = <String, String>{
    '0': '०',
    '1': '१',
    '2': '२',
    '3': '३',
    '4': '४',
    '5': '५',
    '6': '६',
    '7': '७',
    '8': '८',
    '9': '९',
  };
  return text.replaceAllMapped(RegExp(r'[0-9]'), (m) => digitMap[m.group(0)]!);
}

String _localizeDate(String date, AppLocalizations loc) {
  if (!loc.isMarathi) return date;
  const months = {
    'Jan': 'जाने',
    'Feb': 'फेब्रु',
    'Mar': 'मार्च',
    'Apr': 'एप्रिल',
    'May': 'मे',
    'Jun': 'जून',
    'Jul': 'जुलै',
    'Aug': 'ऑग',
    'Sep': 'सप्टें',
    'Oct': 'ऑक्टो',
    'Nov': 'नोव्हें',
    'Dec': 'डिसें',
  };
  String result = date;
  months.forEach((en, mr) => result = result.replaceAll(en, mr));
  return _toDevanagari(result, loc);
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;

  // Subscriptions for the two wallet_transaction queries.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _agentSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _referSub;

  // In-memory doc maps — keyed by Firestore doc ID to deduplicate.
  final _agentDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
  final _userDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

  // Plain state — rebuilt via setState so no broadcast-stream re-subscribe issue.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _mergedTxns = [];
  bool _txnLoading = true;
  int _totalReferredUsers = 0;

  @override
  void initState() {
    super.initState();
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      _userStream = _db.collection('users').doc(uid).snapshots();

      // ── Stream 1: records where this user is the agent ───────────────────
      _agentSub = _db
          .collection('wallet_transactions')
          .where('agentId', isEqualTo: uid)
          .snapshots()
          .listen(
        (qs) {
          for (final d in qs.docs) _agentDocs[d.id] = d;
          final ids = qs.docs.map((d) => d.id).toSet();
          _agentDocs.removeWhere((k, _) => !ids.contains(k));
          _publishMerged();
        },
        onError: (e) => debugPrint('⚠️ agentId txn stream error: $e'),
      );

      // ── Stream 2: records where this user is the paying customer ─────────
      // (only docs without agentId to avoid duplicates)
      _userSub = _db
          .collection('wallet_transactions')
          .where('userId', isEqualTo: uid)
          .snapshots()
          .listen(
        (qs) {
          for (final d in qs.docs) {
            final hasAgentId =
                ((d.data())['agentId'] as String? ?? '').isNotEmpty;
            if (!hasAgentId) _userDocs[d.id] = d;
          }
          final ids = qs.docs
              .where((d) => ((d.data())['agentId'] as String? ?? '').isEmpty)
              .map((d) => d.id)
              .toSet();
          _userDocs.removeWhere((k, _) => !ids.contains(k));
          _publishMerged();
        },
        onError: (e) => debugPrint('⚠️ userId txn stream error: $e'),
      );

      // ── Referred users count ─────────────────────────────────────────────
      _db.collection('users').doc(uid).get().then((doc) {
        if (!mounted) return;
        final code = (doc.data()?['referCode'] as String? ?? '').trim();
        if (code.isEmpty) return;
        _referSub = _db
            .collection('users')
            .where('referredBy', isEqualTo: code)
            .snapshots()
            .listen((qs) {
          if (mounted) setState(() => _totalReferredUsers = qs.size);
        });
      });
    } else {
      // Not logged in — stop loading immediately.
      _txnLoading = false;
    }
  }

  /// Merge _agentDocs + _userDocs, sort newest-first, push into state.
  void _publishMerged() {
    if (!mounted) return;
    final merged = <QueryDocumentSnapshot<Map<String, dynamic>>>[
      ..._agentDocs.values,
      ..._userDocs.values,
    ];
    merged.sort((a, b) {
      final aTs = a.data()['createdAt'] as Timestamp?;
      final bTs = b.data()['createdAt'] as Timestamp?;
      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return 1;
      if (bTs == null) return -1;
      return bTs.compareTo(aTs);
    });
    setState(() {
      _mergedTxns = merged;
      _txnLoading = false;
    });
  }

  @override
  void dispose() {
    _agentSub?.cancel();
    _userSub?.cancel();
    _referSub?.cancel();
    super.dispose();
  }

  Widget _buildEarningRow(
      String label, String amount, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(fontSize: 14, color: Color(0xFF666666))),
          ],
        ),
        Text(amount,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          loc.get('wallet'),
          style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: _userStream == null
          ? const Center(child: Text('Please log in to view your wallet.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _userStream,
              builder: (context, userSnap) {
                final walletBalance =
                    (userSnap.data?.data()?['walletBalance'] ?? 0).toDouble();
                final balanceStr =
                    _toDevanagari(walletBalance.toStringAsFixed(0), loc);

                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Wallet Balance Card ──────────────────────────────
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
                                  const Icon(Icons.account_balance_wallet,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(loc.get('wallet_balance'),
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              userSnap.connectionState ==
                                      ConnectionState.waiting
                                  ? const CircularProgressIndicator(
                                      color: Colors.white)
                                  : Text(
                                      '₹$balanceStr',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold),
                                    ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          content: Text(
                                              loc.get('add_money_upi_message')),
                                        ));
                                      },
                                      icon: const Icon(Icons.add),
                                      label: Text(loc.get('add_money')),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .secondary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {},
                                      icon: const Icon(Icons.arrow_upward),
                                      label: Text(loc.get('withdraw')),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Colors.white.withOpacity(0.2),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Earnings Report ──────────────────────────────────
                        Text(loc.get('earnings_report'),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF333333))),
                        const SizedBox(height: 12),
                        Builder(builder: (context) {
                          final earnDocs = _mergedTxns;
                          final commissions = earnDocs
                              .where((d) =>
                                  (d.data() as Map<String, dynamic>)['type'] ==
                                  'commission')
                              .toList();
                          final totalEarned = commissions.fold<double>(
                              0,
                              (sum, d) =>
                                  sum +
                                  (((d.data() as Map<String, dynamic>)[
                                              'amount'] ??
                                          0) as num)
                                      .toDouble());
                          final now = DateTime.now();
                          final todayEarned = commissions.where((d) {
                            final ts =
                                (d.data() as Map<String, dynamic>)['createdAt']
                                    as Timestamp?;
                            if (ts == null) return false;
                            final dt = ts.toDate();
                            return dt.year == now.year &&
                                dt.month == now.month &&
                                dt.day == now.day;
                          }).fold<double>(
                              0,
                              (sum, d) =>
                                  sum +
                                  (((d.data() as Map<String, dynamic>)[
                                              'amount'] ??
                                          0) as num)
                                      .toDouble());
                          final thisMonthEarned = commissions.where((d) {
                            final ts =
                                (d.data() as Map<String, dynamic>)['createdAt']
                                    as Timestamp?;
                            if (ts == null) return false;
                            final dt = ts.toDate();
                            return dt.year == now.year && dt.month == now.month;
                          }).fold<double>(
                              0,
                              (sum, d) =>
                                  sum +
                                  (((d.data() as Map<String, dynamic>)[
                                              'amount'] ??
                                          0) as num)
                                      .toDouble());
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x12000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2))
                              ],
                            ),
                            child: Column(
                              children: [
                                _buildEarningRow(
                                    loc.get('total_commission_earned'),
                                    '₹${_toDevanagari(totalEarned.toStringAsFixed(0), loc)}',
                                    Icons.trending_up,
                                    Theme.of(context)
                                        .extension<CustomColors>()!
                                        .success),
                                const Divider(height: 24),
                                _buildEarningRow(
                                    loc.get('today_earnings'),
                                    '₹${_toDevanagari(todayEarned.toStringAsFixed(0), loc)}',
                                    Icons.wb_sunny_outlined,
                                    const Color(0xFFF59E0B)),
                                const Divider(height: 24),
                                _buildEarningRow(
                                    loc.get('this_month'),
                                    '₹${_toDevanagari(thisMonthEarned.toStringAsFixed(0), loc)}',
                                    Icons.calendar_today,
                                    Theme.of(context).primaryColor),
                                const Divider(height: 24),
                                _buildEarningRow(
                                    loc.get('total_referred_users'),
                                    _toDevanagari('$_totalReferredUsers', loc),
                                    Icons.group_outlined,
                                    const Color(0xFF7B1FA2)),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 24),

                        // ── Transaction History ──────────────────────────────
                        Text(loc.get('transaction_history'),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF333333))),
                        const SizedBox(height: 12),
                        Builder(builder: (context) {
                          if (_txnLoading) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          final docs = _mergedTxns;
                          if (docs.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.only(top: 16),
                                child: Text(
                                  'No transactions yet.',
                                  style: TextStyle(color: Color(0xFF888888)),
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: docs.map((docSnap) {
                              final d = docSnap.data();
                              final txType = d['type'] as String? ?? '';
                              final isCommission = txType == 'commission';
                              final isCredit = isCommission ||
                                  txType == 'recharge' ||
                                  txType == 'credit';
                              final amt = (d['amount'] ?? 0).toDouble();
                              final ts = d['createdAt'] as Timestamp?;
                              final dateStr = ts != null
                                  ? () {
                                      final dt = ts.toDate();
                                      final months = [
                                        'Jan',
                                        'Feb',
                                        'Mar',
                                        'Apr',
                                        'May',
                                        'Jun',
                                        'Jul',
                                        'Aug',
                                        'Sep',
                                        'Oct',
                                        'Nov',
                                        'Dec'
                                      ];
                                      final h = dt.hour;
                                      final m =
                                          dt.minute.toString().padLeft(2, '0');
                                      final period = h >= 12 ? 'PM' : 'AM';
                                      final h12 = h % 12 == 0 ? 12 : h % 12;
                                      return _localizeDate(
                                          '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h12:$m $period',
                                          loc);
                                    }()
                                  : '—';

                              // Split into title + subtitle for clear display
                              String title;
                              String subtitle;
                              if (isCommission) {
                                final service =
                                    (d['serviceName'] as String? ?? '').trim();
                                final customer =
                                    (d['customerName'] as String? ??
                                            d['userName'] as String? ??
                                            '')
                                        .trim();
                                final pct = d['commissionPercentage'];
                                title = loc.get('commission_from') +
                                    (service.isNotEmpty ? ' – $service' : '');
                                final parts = <String>[];
                                if (customer.isNotEmpty) {
                                  parts.add(
                                      '${loc.get('customer_label')}: $customer');
                                }
                                if (pct != null) parts.add('@$pct%');
                                subtitle = parts.join(' · ');
                              } else if (txType == 'recharge') {
                                title = loc.get('wallet_recharge');
                                subtitle = loc.get('added_by_admin');
                              } else if (txType == 'service_payment') {
                                final svc =
                                    (d['serviceName'] as String? ?? '').trim();
                                title = loc.get('service_payment_label') +
                                    (svc.isNotEmpty ? ' – $svc' : '');
                                subtitle = '';
                              } else {
                                title = isCredit ? 'Credit' : 'Debit';
                                subtitle = '';
                              }

                              final creditColor = isCommission
                                  ? const Color(0xFF7B1FA2)
                                  : const Color(0xFF16A34A);
                              final creditBg = isCommission
                                  ? const Color(0xFFEDE7F6)
                                  : const Color(0xFFDCFCE7);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Color(0x12000000),
                                        blurRadius: 6,
                                        offset: Offset(0, 2))
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isCredit
                                            ? creditBg
                                            : const Color(0xFFFFEBEE),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isCommission
                                            ? Icons.trending_up
                                            : txType == 'recharge'
                                                ? Icons.account_balance_wallet
                                                : isCredit
                                                    ? Icons.arrow_downward
                                                    : Icons.arrow_upward,
                                        color: isCredit
                                            ? creditColor
                                            : const Color(0xFFDC2626),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(title,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF222222))),
                                          if (subtitle.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(subtitle,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF555555))),
                                          ],
                                          const SizedBox(height: 3),
                                          Text(dateStr,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF999999))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${isCredit ? '+' : '-'}₹${_toDevanagari(amt.toStringAsFixed(amt == amt.roundToDouble() ? 0 : 2), loc)}',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isCredit
                                            ? creditColor
                                            : const Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
