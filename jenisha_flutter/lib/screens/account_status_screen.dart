import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class AccountStatusScreen extends StatelessWidget {
  const AccountStatusScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final statusType =
        ModalRoute.of(context)?.settings.arguments as String? ?? 'blocked';
    final isBlocked = statusType == 'blocked';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Icon(Icons.arrow_back,
                          color: Theme.of(context)
                              .extension<CustomColors>()!
                              .textPrimary,
                          size: 24),
                    ),
                  ),
                  Text(localizations.get('account_status'),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .extension<CustomColors>()!
                              .textPrimary)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .error
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .error
                                      .withOpacity(0.2))),
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Column(children: [
                            Icon(Icons.warning_amber_outlined,
                                size: 56,
                                color: Theme.of(context).colorScheme.error),
                            const SizedBox(height: 12),
                            Text(
                                isBlocked
                                    ? localizations.get('account_blocked')
                                    : localizations.get('account_inactive'),
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isBlocked
                                        ? Theme.of(context).colorScheme.error
                                        : Theme.of(context)
                                            .extension<CustomColors>()!
                                            .warning)),
                            const SizedBox(height: 8),
                            Text(
                                isBlocked
                                    ? localizations.get('account_blocked_msg')
                                    : localizations.get('account_inactive_msg'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .extension<CustomColors>()!
                                        .textSecondary)),
                          ]),
                        ),
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      isBlocked
                                          ? localizations
                                              .get('reason_for_blocking')
                                          : localizations.get('why_inactive'),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF111827))),
                                  const SizedBox(height: 8),
                                  if (isBlocked) ...[
                                    Text(
                                        localizations
                                            .get('account_blocked_because'),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF6B7280))),
                                    const SizedBox(height: 8),
                                    Text(localizations.get('violation_terms'),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF6B7280))),
                                    const SizedBox(height: 6),
                                    Text(
                                        localizations
                                            .get('fraudulent_activity'),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF6B7280))),
                                    const SizedBox(height: 6),
                                    Text(localizations.get('invalid_kyc'),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF6B7280))),
                                    const SizedBox(height: 6),
                                    Text(
                                        localizations
                                            .get('multiple_complaints'),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF6B7280))),
                                  ] else ...[
                                    Text(
                                        localizations
                                            .get('account_inactive_because'),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF6B7280))),
                                    const SizedBox(height: 8),
                                    Text(
                                        localizations
                                            .get('no_applications_6months'),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF6B7280))),
                                    const SizedBox(height: 6),
                                    Text(localizations.get('no_login_activity'),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF6B7280))),
                                  ]
                                ])),
                        const SizedBox(height: 12),
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      isBlocked
                                          ? localizations.get('how_to_resolve')
                                          : localizations
                                              .get('how_to_reactivate'),
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF111827))),
                                  const SizedBox(height: 8),
                                  if (isBlocked) ...[
                                    Text(
                                        localizations.get('to_unblock_account'),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF6B7280))),
                                    const SizedBox(height: 6),
                                    Text(
                                        localizations
                                            .get('contact_support_message_1'),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF6B7280))),
                                  ] else ...[
                                    Text(
                                        localizations
                                            .get('to_reactivate_account'),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF6B7280))),
                                    const SizedBox(height: 6),
                                    Text(
                                        localizations
                                            .get('reactivate_message_1'),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF6B7280))),
                                  ]
                                ])),
                        const SizedBox(height: 12),
                        if (!isBlocked)
                          ElevatedButton(
                              onPressed: () {},
                              child: Text(
                                  localizations.get('request_reactivation'))),
                        const SizedBox(height: 8),
                        OutlinedButton(
                            onPressed: () {},
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.phone,
                                      color: Theme.of(context)
                                          .extension<CustomColors>()!
                                          .textPrimary),
                                  const SizedBox(width: 8),
                                  Text(localizations.get('contact_support'))
                                ])),
                        const SizedBox(height: 12),
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(10)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(localizations.get('support_contact'),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF374151))),
                                  const SizedBox(height: 8),
                                  Text(localizations.get('toll_free_number'),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF6B7280))),
                                  const SizedBox(height: 6),
                                  Text(localizations.get('support_email'),
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF6B7280))),
                                ])),
                      ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
