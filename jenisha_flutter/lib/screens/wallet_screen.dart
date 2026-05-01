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

  // Debounce timer used by the transfer user search
  Timer? _transferSearchDebounce;

  // Optimistic UI: pending deduction while transfer is in-flight
  double _optimisticPendingDeduct = 0.0;
  double? _lastSeenBalance;

  // Plain state — rebuilt via setState so no broadcast-stream re-subscribe issue.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _mergedTxns = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _withdrawals = [];
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

  /// Merge _agentDocs + _userDocs, split withdrawals out, sort newest-first.
  void _publishMerged() {
    if (!mounted) return;
    final all = <QueryDocumentSnapshot<Map<String, dynamic>>>[
      ..._agentDocs.values,
      ..._userDocs.values,
    ];
    int cmp(QueryDocumentSnapshot<Map<String, dynamic>> a,
        QueryDocumentSnapshot<Map<String, dynamic>> b) {
      final aTs = a.data()['createdAt'] as Timestamp?;
      final bTs = b.data()['createdAt'] as Timestamp?;
      if (aTs == null && bTs == null) return 0;
      if (aTs == null) return 1;
      if (bTs == null) return -1;
      return bTs.compareTo(aTs);
    }

    final withdrawals = all
        .where((d) => (d.data()['type'] as String?) == 'withdrawal')
        .toList()
      ..sort(cmp);
    final regular = all
        .where((d) => (d.data()['type'] as String?) != 'withdrawal')
        .toList()
      ..sort(cmp);

    setState(() {
      _mergedTxns = regular;
      _withdrawals = withdrawals;
      _txnLoading = false;
    });
  }

  @override
  void dispose() {
    _agentSub?.cancel();
    _userSub?.cancel();
    _referSub?.cancel();
    _transferSearchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _showWithdrawSheet(double walletBalance) async {
    final loc = AppLocalizations.of(context);
    final user = _auth.currentUser;
    if (user == null) return;

    // Load payment details from profile
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data();

    // Read UPI and bank details from their actual Firestore paths
    final upiId = userData?['upiId'] as String? ?? '';
    final bankData = userData?['bankDetails'] as Map<String, dynamic>?;
    final accountNumber = bankData?['accountNumber'] as String? ?? '';

    if (!mounted) return;

    // Block withdraw only if BOTH UPI and bank details are missing
    if (upiId.isEmpty && accountNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.get('please_add_payment_details')),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
      return;
    }

    // Build a unified details map for the bottom sheet.
    // Prefer UPI if available, otherwise fall back to bank.
    final details = <String, dynamic>{
      'method': upiId.isNotEmpty ? 'upi' : 'bank',
      'upiId': upiId,
      'holderName': bankData?['holderName'] ?? '',
      'accountNumber': accountNumber,
      'ifscCode': bankData?['ifsc'] ?? '',
      'bankName': bankData?['bankName'] ?? '',
    };

    final amountController = TextEditingController();
    String errorText = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          final method = details['method'] as String? ?? 'upi';
          final isUpi = method == 'upi';

          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDDDDD),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    loc.get('withdrawal_request'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${loc.get('wallet_balance')}: ₹${walletBalance.toStringAsFixed(0)}',
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFF888888)),
                  ),
                  const SizedBox(height: 20),
                  // Payment method summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isUpi
                              ? Icons.account_balance_wallet_outlined
                              : Icons.account_balance_outlined,
                          size: 20,
                          color: const Color(0xFF555555),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUpi
                                    ? loc.get('upi_transfer')
                                    : loc.get('bank_transfer'),
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF888888)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isUpi
                                    ? (details['upiId'] as String? ?? '')
                                    : '${details['holderName'] ?? ''} · ${details['accountNumber'] ?? ''} · ${details['ifscCode'] ?? ''}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF222222)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Amount input
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: loc.get('withdraw_amount'),
                      prefixText: '₹ ',
                      hintText: loc.get('enter_amount'),
                      errorText: errorText.isNotEmpty ? errorText : null,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: Theme.of(context).primaryColor, width: 1.5),
                      ),
                    ),
                    onChanged: (_) {
                      if (errorText.isNotEmpty) {
                        setModalState(() => errorText = '');
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final amt =
                            double.tryParse(amountController.text.trim());
                        if (amt == null || amt <= 0) {
                          setModalState(
                              () => errorText = loc.get('enter_amount'));
                          return;
                        }
                        if (amt < 100) {
                          setModalState(
                              () => errorText = loc.get('min_withdrawal'));
                          return;
                        }
                        if (amt > walletBalance) {
                          setModalState(() =>
                              errorText = loc.get('insufficient_balance'));
                          return;
                        }
                        Navigator.pop(ctx);
                        await _submitWithdrawal(amt, details, userData);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: Text(loc.get('submit_request'),
                          style: const TextStyle(fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  /// Search users by name or ID (simple prefix-search + exact-id lookup).
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> _searchUsers(
      String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return [];
    final uid = _auth.currentUser?.uid;
    final results = <DocumentSnapshot<Map<String, dynamic>>>[];

    try {
      // Exact doc id match (fast path)
      final doc = await _db.collection('users').doc(trimmed).get();
      if (doc.exists && doc.id != uid) results.add(doc);
    } catch (_) {}

    try {
      // Prefix search on fullName
      final end = trimmed + '\uf8ff';
      final q1 = await _db
          .collection('users')
          .where('fullName', isGreaterThanOrEqualTo: trimmed)
          .where('fullName', isLessThanOrEqualTo: end)
          .limit(25)
          .get();
      results.addAll(q1.docs);
    } catch (_) {}

    try {
      // Prefix search on name (fallback)
      final end = trimmed + '\uf8ff';
      final q2 = await _db
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: trimmed)
          .where('name', isLessThanOrEqualTo: end)
          .limit(25)
          .get();
      results.addAll(q2.docs);
    } catch (_) {}

    // Deduplicate and exclude current user
    final map = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (final d in results) {
      if (d.id == uid) continue;
      map[d.id] = d;
    }

    return map.values.take(25).toList();
  }

  Future<void> _performTransfer(
    DocumentSnapshot<Map<String, dynamic>> receiverDoc,
    double amount,
  ) async {
    // Perform an atomic transfer using a Firestore transaction (client-side).
    final sender = _auth.currentUser;
    if (sender == null) throw Exception('User not logged in');
    if (receiverDoc.id.isEmpty) throw Exception('invalid_receiver');
    if (sender.uid == receiverDoc.id) throw Exception('cannot_transfer_to_self');
    if (amount.isNaN || amount <= 0) throw Exception('invalid_amount');

    final db = _db;

    // Debug: log transfer intent
    try {
      print('TRANSFER START: sender=${sender.uid}, receiver=${receiverDoc.id}, amount=$amount');
    } catch (_) {}

    try {
      await db.runTransaction((txn) async {
        final senderRef = db.collection('users').doc(sender.uid);
        final receiverRef = db.collection('users').doc(receiverDoc.id);

        final sSnap = await txn.get(senderRef);
        final rSnap = await txn.get(receiverRef);

        if (!sSnap.exists) throw Exception('sender_not_found');
        if (!rSnap.exists) throw Exception('receiver_not_found');

        final sData = sSnap.data() ?? <String, dynamic>{};
        final rData = rSnap.data() ?? <String, dynamic>{};

        double sBalance = 0.0;
        final sBalRaw = sData['walletBalance'];
        if (sBalRaw is num) sBalance = (sBalRaw as num).toDouble();
        else if (sBalRaw is String) sBalance = double.tryParse(sBalRaw) ?? 0.0;

        double rBalance = 0.0;
        final rBalRaw = rData['walletBalance'];
        if (rBalRaw is num) rBalance = (rBalRaw as num).toDouble();
        else if (rBalRaw is String) rBalance = double.tryParse(rBalRaw) ?? 0.0;

        // Debug: log balances before update
        try {
          print('TRANSFER TXN READ: senderBalance=$sBalance, receiverBalance=$rBalance');
        } catch (_) {}

        if (sBalance < amount) {
          throw Exception('insufficient_balance');
        }

        // Update balances
        txn.update(senderRef, {'walletBalance': sBalance - amount});
        txn.update(receiverRef, {'walletBalance': rBalance + amount});

        // Record transaction in `transactions` collection (per requirements)
        final txRef = db.collection('transactions').doc();
        txn.set(txRef, {
          'from': sender.uid,
          'to': receiverDoc.id,
          'amount': amount,
          'type': 'transfer',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Also write into existing `wallet_transactions` for UI compatibility
        final wtRef = db.collection('wallet_transactions').doc();
        final senderName = sData['fullName'] ?? sData['name'] ?? '';
        final receiverName = rData['fullName'] ?? rData['name'] ?? '';
        txn.set(wtRef, {
          'userId': sender.uid,
          'userName': senderName,
          'type': 'transfer',
          'toUserId': receiverDoc.id,
          'toUserName': receiverName,
          'amount': amount,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      try {
        print('TRANSFER SUCCESS: sender=${sender.uid}, receiver=${receiverDoc.id}, amount=$amount');
      } catch (_) {}
    } catch (e, st) {
      // Log failure and rethrow for UI handling
      try {
        print('TRANSFER ERROR: $e');
        print(st);
      } catch (_) {}
      rethrow;
    }
    return;
  }

  Future<void> _showTransferSheet(double serverBalance) async {
    final loc = AppLocalizations.of(context);
    final user = _auth.currentUser;
    if (user == null) return;

    final searchController = TextEditingController();
    final amountController = TextEditingController();
    DocumentSnapshot<Map<String, dynamic>>? selectedUserDoc;
    List<DocumentSnapshot<Map<String, dynamic>>> results = [];
    bool loading = false;
    bool submitting = false;
    String errorText = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          builder: (dctx, scrollController) {
            return StatefulBuilder(builder: (ctx, setModalState) {
              final parsedAmt = double.tryParse(amountController.text.trim());
              final canSubmit = !submitting &&
                  selectedUserDoc != null &&
                  parsedAmt != null &&
                  parsedAmt > 0 &&
                  parsedAmt <= serverBalance &&
                  selectedUserDoc!.id != user.uid;

              final displayBalance = (serverBalance - _optimisticPendingDeduct).clamp(0.0, double.infinity);

              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDDDDDD),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Text(
                          loc.get('transfer'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('${loc.get('wallet_balance')}: ₹${displayBalance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
                        const SizedBox(height: 8),
                        TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search user by name or ID',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            if (_transferSearchDebounce?.isActive ?? false) {
                              _transferSearchDebounce?.cancel();
                            }
                            _transferSearchDebounce = Timer(const Duration(milliseconds: 400), () async {
                              try {
                                setModalState(() {
                                  loading = true;
                                  results = [];
                                });
                                final res = await _searchUsers(v);
                                if (mounted) setModalState(() {
                                  results = res;
                                  loading = false;
                                });
                              } catch (_) {
                                if (mounted) setModalState(() {
                                  loading = false;
                                  results = [];
                                });
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        // Search results
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: loading
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              : results.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 18),
                                      child: Center(child: Text('No users found.')),
                                    )
                                  : Column(
                                      children: results.map((d) {
                                        final data = d.data() ?? {};
                                        final name = (data['fullName'] ?? data['name'] ?? '') as String;
                                        final id = d.id;
                                        final profileUrl = (data['profilePhotoUrl'] ?? data['profileImage'] ?? data['profileImageUrl'] ?? data['photoUrl']) as String?;
                                        final isSelected = selectedUserDoc?.id == d.id;
                                        // Debug image URL for troubleshooting
                                        try {
                                          print('User Image URL: $profileUrl');
                                        } catch (_) {}

                                        final Widget avatarWidget = (profileUrl != null && profileUrl.isNotEmpty)
                                            ? CircleAvatar(
                                                radius: 22,
                                                backgroundColor: Colors.grey.shade200,
                                                child: ClipOval(
                                                  child: SizedBox(
                                                    width: 44,
                                                    height: 44,
                                                    child: Image.network(
                                                      profileUrl,
                                                      fit: BoxFit.cover,
                                                      loadingBuilder: (context, child, loadingProgress) {
                                                        if (loadingProgress == null) return child;
                                                        return const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
                                                      },
                                                      errorBuilder: (context, error, stackTrace) {
                                                        final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
                                                        return Container(
                                                          color: Colors.grey.shade200,
                                                          child: Center(child: Text(letter, style: const TextStyle(fontWeight: FontWeight.bold))),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : CircleAvatar(radius: 22, backgroundColor: Colors.grey.shade200, child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.bold)));

                                        return InkWell(
                                          onTap: () => setModalState(() => selectedUserDoc = d),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.06) : Colors.white,
                                              border: isSelected ? Border.all(color: Theme.of(context).primaryColor, width: 1.0) : null,
                                            ),
                                            child: Row(
                                              children: [
                                                avatarWidget,
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                                      const SizedBox(height: 4),
                                                      Text(id, style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                                                    ],
                                                  ),
                                                ),
                                                if (isSelected) Icon(Icons.check_circle, color: Theme.of(context).primaryColor),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                        ),
                        const SizedBox(height: 12),
                        if (selectedUserDoc != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 6, offset: Offset(0, 2))],
                            ),
                            child: Row(
                              children: [
                                Builder(builder: (_) {
                                  final sData = selectedUserDoc!.data() ?? {};
                                  final sName = (sData['fullName'] ?? sData['name'] ?? '') as String;
                                  final sProfile = (sData['profilePhotoUrl'] ?? sData['profileImage'] ?? sData['profileImageUrl'] ?? sData['photoUrl']) as String?;

                                  try {
                                    print('User Image URL (selected): $sProfile');
                                  } catch (_) {}

                                  final Widget avatarWidget = (sProfile != null && sProfile.isNotEmpty)
                                      ? CircleAvatar(
                                          radius: 22,
                                          backgroundColor: Colors.grey.shade200,
                                          child: ClipOval(
                                            child: SizedBox(
                                              width: 44,
                                              height: 44,
                                              child: Image.network(
                                                sProfile,
                                                fit: BoxFit.cover,
                                                loadingBuilder: (context, child, loadingProgress) {
                                                  if (loadingProgress == null) return child;
                                                  return const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
                                                },
                                                errorBuilder: (context, error, stackTrace) {
                                                  final letter = sName.isNotEmpty ? sName[0].toUpperCase() : '?';
                                                  return Container(
                                                    color: Colors.grey.shade200,
                                                    child: Center(child: Text(letter, style: const TextStyle(fontWeight: FontWeight.bold))),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        )
                                      : CircleAvatar(radius: 22, backgroundColor: Colors.grey.shade200, child: Text(sName.isNotEmpty ? sName[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.bold)));

                                  return avatarWidget;
                                }),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(selectedUserDoc!.data()?['fullName'] ?? selectedUserDoc!.data()?['name'] ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text(selectedUserDoc!.id, style: const TextStyle(color: Color(0xFF666666))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        // Amount
                        TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: loc.get('enter_amount'),
                            prefixText: '₹ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (_) {
                            // Rebuild so the button enablement updates live
                            setModalState(() {
                              if (errorText.isNotEmpty) errorText = '';
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        if (errorText.isNotEmpty) ...[
                          Text(errorText, style: const TextStyle(color: Color(0xFFE53935))),
                          const SizedBox(height: 8),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: canSubmit
                                ? () async {
                                    final amt = parsedAmt!;
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dctx) => AlertDialog(
                                        title: Text(loc.get('confirm')),
                                        content: Text('Transfer ₹${amt.toStringAsFixed(0)} to ${selectedUserDoc!.data()?['fullName'] ?? selectedUserDoc!.data()?['name'] ?? selectedUserDoc!.id}?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(dctx, false), child: Text(loc.get('cancel'))),
                                          TextButton(onPressed: () => Navigator.pop(dctx, true), child: Text(loc.get('confirm'))),
                                        ],
                                      ),
                                    );

                                    if (confirmed != true) return;

                                    setModalState(() {
                                      submitting = true;
                                      errorText = '';
                                    });

                                    try {
                                      // Optimistic UI: deduct locally while request is in-flight
                                      if (mounted) setState(() => _optimisticPendingDeduct += amt);
                                      await _performTransfer(selectedUserDoc!, amt);
                                      if (mounted) Navigator.pop(ctx);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Transferred ₹${amt.toStringAsFixed(0)} successfully'), backgroundColor: const Color(0xFF4CAF50)),
                                        );
                                      }
                                    } catch (e) {
                                      // Log error
                                      try {
                                        print('TRANSFER ERROR: $e');
                                      } catch (_) {}

                                      // Revert optimistic deduction
                                      if (mounted) setState(() => _optimisticPendingDeduct = (_optimisticPendingDeduct - amt).clamp(0.0, double.infinity));

                                      // Show snackbar with clean message
                                      final isInsufficient = e.toString().contains('insufficient_balance');
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(isInsufficient ? loc.get('insufficient_balance') : 'Transfer failed'),
                                            backgroundColor: const Color(0xFFE53935),
                                          ),
                                        );
                                      }

                                      setModalState(() {
                                        submitting = false;
                                        final raw = e.toString();
                                        if (raw.contains('insufficient_balance')) {
                                          errorText = loc.get('insufficient_balance');
                                        } else {
                                          // Strip generic Exception prefix if present
                                          errorText = raw.replaceFirst('Exception: ', '');
                                        }
                                      });
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: submitting
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(loc.get('transfer')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            });
          },
        );
      },
    );

    _transferSearchDebounce?.cancel();
  }

  Future<void> _submitWithdrawal(
    double amount,
    Map<String, dynamic> paymentDetails,
    Map<String, dynamic>? userData,
  ) async {
    final loc = AppLocalizations.of(context);
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db.runTransaction((txn) async {
        final userRef = _db.collection('users').doc(user.uid);
        final snap = await txn.get(userRef);
        final currentBalance =
            ((snap.data()?['walletBalance'] ?? 0) as num).toDouble();
        if (currentBalance < amount) {
          throw Exception('insufficient_balance');
        }
        // Deduct from wallet
        txn.update(userRef, {'walletBalance': currentBalance - amount});
        // Record withdrawal request in wallet_transactions
        // (uses existing 'allow create: if isAuthenticated()' rule)
        txn.set(_db.collection('wallet_transactions').doc(), {
          'agentId': user.uid,
          'agentName': userData?['fullName'] ?? userData?['name'] ?? 'Unknown',
          'userId': user.uid,
          'userName': userData?['fullName'] ?? userData?['name'] ?? 'Unknown',
          'userPhone': userData?['phone'] ?? '',
          'amount': amount,
          'type': 'withdrawal',
          'withdrawalStatus': 'pending',
          'paymentMethod': paymentDetails['method'] ?? 'upi',
          'paymentDetails': paymentDetails,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.get('withdrawal_submitted')),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } on Exception catch (e) {
      final msg = e.toString().contains('insufficient_balance')
          ? loc.get('insufficient_balance')
          : 'Failed to submit withdrawal. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(msg), backgroundColor: const Color(0xFFE53935)),
        );
      }
    }
  }

  Widget _buildWithdrawalStatusBadge(String status) {
    Color bg, fg;
    String label;
    switch (status) {
      case 'processing':
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1E88E5);
        label = AppLocalizations.of(context).get('withdrawal_processing');
        break;
      case 'approved':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF4CAF50);
        label = AppLocalizations.of(context).get('withdrawal_approved');
        break;
      case 'rejected':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFF44336);
        label = AppLocalizations.of(context).get('withdrawal_rejected');
        break;
      default:
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFFF9800);
        label = AppLocalizations.of(context).get('withdrawal_pending');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
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
      resizeToAvoidBottomInset: true,
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
                final serverBalance =
                  (userSnap.data?.data()?['walletBalance'] ?? 0).toDouble();
                // Reset optimistic deduction when server balance changes
                if (_lastSeenBalance == null) _lastSeenBalance = serverBalance;
                if (_lastSeenBalance != serverBalance) {
                  _optimisticPendingDeduct = 0.0;
                  _lastSeenBalance = serverBalance;
                }
                final walletBalance = (serverBalance - _optimisticPendingDeduct).clamp(0.0, double.infinity);
                final balanceStr = _toDevanagari(walletBalance.toStringAsFixed(0), loc);

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
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _showTransferSheet(walletBalance),
                                      icon: const Icon(Icons.send),
                                      label: Text(loc.get('transfer')),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Colors.white.withOpacity(0.12),
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
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _showWithdrawSheet(walletBalance),
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
                              } else if (txType == 'transfer') {
                                final toName = (d['toUserName'] as String? ?? '').trim();
                                title = toName.isNotEmpty ? 'Transfer to $toName' : 'Transfer';
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
                        const SizedBox(height: 24),

                        // ── Withdrawal History ───────────────────────────────
                        Text(loc.get('withdrawal_history'),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF333333))),
                        const SizedBox(height: 12),
                        if (_withdrawals.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              child: Text(
                                loc.get('no_withdrawals'),
                                style:
                                    const TextStyle(color: Color(0xFF888888)),
                              ),
                            ),
                          )
                        else
                          Column(
                            children: _withdrawals.map((docSnap) {
                              final d = docSnap.data();
                              final amt =
                                  ((d['amount'] ?? 0) as num).toDouble();
                              final status =
                                  d['withdrawalStatus'] as String? ?? 'pending';
                              final method =
                                  d['paymentMethod'] as String? ?? 'upi';
                              final ts = d['createdAt'] as Timestamp?;
                              final payDetails =
                                  d['paymentDetails'] as Map<String, dynamic>?;
                              final payInfo = method == 'upi'
                                  ? (payDetails?['upiId'] as String? ?? '')
                                  : (payDetails?['accountNumber'] as String? ??
                                      '');
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
                              final rejectionReason =
                                  d['rejectionReason'] as String?;

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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF3E0),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.arrow_upward,
                                            color: Color(0xFFFF9800),
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${loc.get('withdraw')} · ${method == 'upi' ? loc.get('upi_transfer') : loc.get('bank_transfer')}',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF222222)),
                                              ),
                                              if (payInfo.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(payInfo,
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            Color(0xFF555555))),
                                              ],
                                              const SizedBox(height: 3),
                                              Text(dateStr,
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Color(0xFF999999))),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '-₹${_toDevanagari(amt.toStringAsFixed(0), loc)}',
                                              style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFDC2626)),
                                            ),
                                            const SizedBox(height: 4),
                                            _buildWithdrawalStatusBadge(status),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (status == 'rejected' &&
                                        rejectionReason != null &&
                                        rejectionReason.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFEBEE),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.info_outline,
                                                size: 14,
                                                color: Color(0xFFF44336)),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                '${loc.get('rejection_reason')}: $rejectionReason',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFFB71C1C)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
