import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../l10n/app_localizations.dart';
import '../utils/firestore_helper.dart';
import '../providers/language_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/translated_text.dart';

class CategoryDetailScreen extends StatelessWidget {
  const CategoryDetailScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final categoryId =
        (args is Map<String, dynamic>) ? args['id'] as String : '';

    // Get localized category name from arguments
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final categoryName = (args is Map<String, dynamic>)
        ? FirestoreHelper.getLocalizedFieldWithLanguage(
            args,
            'name',
            languageProvider.languageCode,
          )
        : 'Category';

    final firestoreService = FirestoreService();
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).get('services')),
            TranslatedText(categoryName,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimary
                        .withOpacity(0.7))),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: categoryId.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        localizations.get('unable_to_load_category'),
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF9F1239)),
                      ),
                    ),
                  )
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: firestoreService
                        .getActiveServicesForCategory(categoryId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: SizedBox(
                            height: 50,
                            width: 50,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.grey.shade300),
                            ),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.red.shade400, size: 40),
                                const SizedBox(height: 12),
                                Text(
                                  '${localizations.get('error_loading_services')}: ${snapshot.error}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xFF9F1239)),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final services = snapshot.data ?? [];

                      if (services.isEmpty) {
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox_outlined,
                                    color: Colors.grey.shade400, size: 40),
                                const SizedBox(height: 12),
                                Text(
                                  AppLocalizations.of(context)
                                      .get('no_services_available'),
                                  style: const TextStyle(
                                      fontSize: 14, color: Color(0xFF6B7280)),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ListView.separated(
                          itemCount: services.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final service = services[i];
                            final serviceId = service['id'] as String;

                            // Get localized service name
                            final languageProvider =
                                Provider.of<LanguageProvider>(context,
                                    listen: false);
                            final serviceName =
                                FirestoreHelper.getLocalizedFieldWithLanguage(
                              service,
                              'name',
                              languageProvider.languageCode,
                            );

                            final servicePrice = service['price'] != null
                                ? '₹${service['price']}'
                                : localizations.get('free');

                            // Logo from Hostinger (stored as logoUrl in Firestore)
                            final logoUrl =
                                (service['logoUrl']?.toString() ?? '').trim();

                            debugPrint(
                                '🖼️  [ServiceLogo] $serviceName → "$logoUrl"');

                            return InkWell(
                              onTap: () async {
                                final redirectUrl =
                                    (service['redirectUrl']?.toString() ?? '')
                                        .trim();

                                // Only redirect if a URL is set AND the service
                                // has no dynamic fields configured in the admin panel.
                                if (redirectUrl.isNotEmpty) {
                                  final fieldsDoc = await FirebaseFirestore
                                      .instance
                                      .collection('service_document_fields')
                                      .doc(serviceId)
                                      .get();

                                  final hasFields = fieldsDoc.exists &&
                                      (fieldsDoc.data()?['fields'] as List?)
                                              ?.isNotEmpty ==
                                          true;

                                  if (!hasFields) {
                                    final uri = Uri.tryParse(redirectUrl);
                                    if (uri != null &&
                                        await canLaunchUrl(uri)) {
                                      await launchUrl(
                                        uri,
                                        mode: LaunchMode.externalApplication,
                                      );
                                      return;
                                    }
                                  }
                                }

                                // Default: open the service form
                                Navigator.pushNamed(
                                  context,
                                  '/service-form',
                                  arguments: {
                                    'serviceId': serviceId,
                                    'serviceName': serviceName,
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // ── Service logo ─────────────────────
                                    logoUrl.isNotEmpty
                                        ? ClipOval(
                                            child: Image.network(
                                              logoUrl,
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              // Show a small spinner while loading
                                              loadingBuilder: (context, child,
                                                  loadingProgress) {
                                                if (loadingProgress == null) {
                                                  return child;
                                                }
                                                return Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Theme.of(context)
                                                        .primaryColor
                                                        .withOpacity(0.08),
                                                  ),
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor:
                                                          AlwaysStoppedAnimation(
                                                        Theme.of(context)
                                                            .primaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                              errorBuilder:
                                                  (context, error, _) {
                                                debugPrint(
                                                    '❌ [ServiceLogo] failed to load: $logoUrl — $error');
                                                return _ServiceLogoFallback();
                                              },
                                            ),
                                          )
                                        : _ServiceLogoFallback(),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          TranslatedText(
                                              serviceName.isEmpty
                                                  ? localizations
                                                      .get('services')
                                                  : serviceName,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF111827))),
                                          const SizedBox(height: 4),
                                          Text(servicePrice,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF6B7280))),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right,
                                        color: Color(0xFF9CA3AF)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Default 40-px circular placeholder shown when a service has no logo or
/// when the Hostinger image fails to load.
class _ServiceLogoFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).primaryColor.withOpacity(0.12),
      ),
      child: Icon(
        Icons.description,
        size: 20,
        color: Theme.of(context).primaryColor,
      ),
    );
  }
}
