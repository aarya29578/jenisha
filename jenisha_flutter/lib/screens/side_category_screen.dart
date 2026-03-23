import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firestore_service.dart';
import '../l10n/app_localizations.dart';
import '../utils/firestore_helper.dart';
import '../providers/language_provider.dart';
import '../theme/app_theme.dart';

/// Screen that shows all categories (child) belonging to a specific side-category.
/// When the user taps a category it navigates to CategoryDetailScreen (services list).
class SideCategoryScreen extends StatelessWidget {
  const SideCategoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final sideCategoryId =
        (args is Map<String, dynamic>) ? args['id'] as String : '';
    final sideCategoryName =
        (args is Map<String, dynamic>) ? args['name'] as String : 'Categories';

    final firestoreService = FirestoreService();
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sideCategoryName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              AppLocalizations.of(context).get('services'),
              style: TextStyle(
                  color: Colors.white.withOpacity(0.75), fontSize: 12),
            ),
          ],
        ),
      ),
      body: sideCategoryId.isEmpty
          ? const Center(child: Text('Invalid category'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream:
                  firestoreService.getCategoriesBySideCategory(sideCategoryId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error loading categories: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final categories = snapshot.data ?? [];

                if (categories.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.category_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No categories yet',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                final languageProvider =
                    Provider.of<LanguageProvider>(context, listen: false);

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final categoryId = category['id'] as String;
                    final categoryName =
                        FirestoreHelper.getLocalizedFieldWithLanguage(
                      category,
                      'name',
                      languageProvider.languageCode,
                    );
                    final logoUrl =
                        (category['customLogoUrl']?.toString() ?? '').trim();

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/category-detail',
                          arguments: {
                            'id': categoryId,
                            'name': categoryName,
                          },
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: logoUrl.isNotEmpty
                                      ? Image.network(
                                          logoUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                          loadingBuilder: (_, child, progress) {
                                            if (progress == null) return child;
                                            return Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: primaryColor,
                                              ),
                                            );
                                          },
                                          errorBuilder: (_, __, ___) =>
                                              _PlaceholderIcon(
                                                  primaryColor: primaryColor),
                                        )
                                      : _PlaceholderIcon(
                                          primaryColor: primaryColor),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              categoryName.isEmpty ? 'Service' : categoryName,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  final Color primaryColor;
  const _PlaceholderIcon({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: primaryColor.withOpacity(0.07),
      child: Center(
        child: Icon(Icons.category_outlined,
            color: primaryColor.withOpacity(0.4), size: 32),
      ),
    );
  }
}
