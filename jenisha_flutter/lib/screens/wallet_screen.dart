import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class _Txn {
  final String id;
  final String type;
  final int amount;
  final String description;
  final String date;
  const _Txn(this.id, this.type, this.amount, this.description, this.date);
}

const List<_Txn> _transactions = [
  _Txn('1', 'credit', 500, 'commission_income_cert', '24 Jan 2026'),
  _Txn('2', 'credit', 400, 'commission_domicile_cert', '24 Jan 2026'),
  _Txn('3', 'debit', 200, 'withdrawal_to_bank', '23 Jan 2026'),
  _Txn('4', 'credit', 350, 'commission_caste_cert', '22 Jan 2026'),
];

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
  return text.replaceAllMapped(
    RegExp(r'[0-9]'),
    (m) => digitMap[m.group(0)]!,
  );
}

/// Replace English month abbreviations with Marathi equivalents when in
/// Marathi mode, also converting digits to Devanagari.
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

class WalletScreen extends StatelessWidget {
  const WalletScreen({Key? key}) : super(key: key);

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
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final balance = 2450;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        title: Text(
          localizations.get('wallet'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wallet Balance Card
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
                        Text(
                          localizations.get('wallet_balance'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '₹${_toDevanagari(balance.toString(), localizations)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Implement UPI/QR code add money
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(localizations
                                      .get('add_money_upi_message')),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: Text(localizations.get('add_money')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.arrow_upward),
                            label: Text(localizations.get('withdraw')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
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
              // Earnings Report Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    localizations.get('earnings_report'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF333333),
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      localizations.get('view_all'),
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    _buildEarningRow(
                        localizations.get('total_commission_earned'),
                        _toDevanagari('₹3,450', localizations),
                        Icons.trending_up,
                        Theme.of(context).extension<CustomColors>()!.success),
                    const Divider(height: 24),
                    _buildEarningRow(
                        localizations.get('this_month'),
                        _toDevanagari('₹1,250', localizations),
                        Icons.calendar_today,
                        Theme.of(context).primaryColor),
                    const Divider(height: 24),
                    _buildEarningRow(
                        localizations.get('avg_per_application'),
                        _toDevanagari('₹410', localizations),
                        Icons.analytics_outlined,
                        Theme.of(context).extension<CustomColors>()!.warning),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Transaction History
              Text(
                localizations.get('transaction_history'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),
              Column(
                children: List.generate(
                  _transactions.length,
                  (i) {
                    final t = _transactions[i];
                    final isCredit = t.type == 'credit';
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isCredit
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    isCredit
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: isCredit
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFDC2626),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        localizations.get(t.description),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF333333),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _localizeDate(t.date, localizations),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF888888),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${isCredit ? '+' : '-'}₹${_toDevanagari(t.amount.toString(), localizations)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isCredit
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
