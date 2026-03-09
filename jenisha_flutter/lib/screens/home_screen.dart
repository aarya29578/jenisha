import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/banner_slider.dart';
import '../widgets/language_toggle.dart';
import '../services/firestore_service.dart';
import '../l10n/app_localizations.dart';
import '../utils/firestore_helper.dart';
import '../providers/language_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/announcement_banner.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  String? _userStatus = 'pending';
  List<Map<String, dynamic>> _userDocuments = [];
  bool _statusLoaded = false;
  String _searchQuery = '';
  String? _profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserStatusAndDocuments();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
  }

  Future<void> _loadUserStatusAndDocuments() async {
    final userData = await _firestoreService.getCurrentUserData();
    if (userData != null && mounted) {
      setState(() {
        _userStatus = userData['status'] ?? 'pending';
        _profilePhotoUrl = userData['profilePhotoUrl'] as String?;
      });

      // Also load documents to check approval
      final uid = userData['uid'];
      if (uid != null) {
        final docs = await _firestoreService.getUserDocuments(uid);
        if (mounted) {
          setState(() {
            _userDocuments = docs;
            _statusLoaded = true;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🏠 HOME SCREEN LOCK (FINAL RULE)
    if (_statusLoaded && _userStatus != 'approved') {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Lock icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .extension<CustomColors>()!
                        .warning
                        .withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.lock_outline,
                      size: 60,
                      color:
                          Theme.of(context).extension<CustomColors>()!.warning,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Status title
                Text(
                  _userStatus == 'rejected'
                      ? AppLocalizations.of(context)
                          .translate('account_blocked')
                      : AppLocalizations.of(context)
                          .translate('waiting_approval'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context)
                        .extension<CustomColors>()!
                        .textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Status message
                Text(
                  _userStatus == 'rejected'
                      ? AppLocalizations.of(context)
                          .translate('registration_rejected_msg')
                      : AppLocalizations.of(context)
                          .translate('documents_under_review'),
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context)
                        .extension<CustomColors>()!
                        .textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Action button
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/account-status',
                        arguments: _userStatus);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).translate('check_status'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        title: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              AppLocalizations.of(context).translate('app_title'),
              textAlign: TextAlign.left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.white.withOpacity(0.4), width: 2),
              ),
              child: ClipOval(
                child: _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                    ? Image.network(
                        _profilePhotoUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 32,
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
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
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Bar Section with Language Toggle
            Container(
              color: Theme.of(context).primaryColor,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)
                            .translate('search_placeholder'),
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon:
                            Icon(Icons.search, color: Colors.grey.shade500),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const LanguageToggle(),
                ],
              ),
            ),

            // Banner Slider Section
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firestoreService.getActiveBannersStream(),
              builder: (context, snapshot) {
                List<Map<String, dynamic>> banners = [];

                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  // Use Firestore banners
                  banners = snapshot.data!;
                }

                // If no banners from Firestore, show dummy banners
                if (banners.isEmpty) {
                  banners = [
                    {
                      'imageUrl':
                          'https://via.placeholder.com/800x300/1E40AF/FFFFFF?text=Welcome+to+Jenisha+Online+Service',
                      'linkUrl': null,
                    },
                    {
                      'imageUrl':
                          'https://via.placeholder.com/800x300/10B981/FFFFFF?text=Fast+%26+Reliable+Document+Services',
                      'linkUrl': null,
                    },
                    {
                      'imageUrl':
                          'https://via.placeholder.com/800x300/F59E0B/FFFFFF?text=Get+Your+Documents+Today',
                      'linkUrl': null,
                    },
                  ];
                }

                return BannerSlider(banners: banners);
              },
            ),

            // Announcement Banner (Firestore-driven, hidden when empty)
            const AnnouncementBanner(),

            // Main Services Section Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context).translate('services'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _firestoreService.getActiveCategoriesStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        AppLocalizations.of(context)
                            .translate('error_loading_categories'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    );
                  }

                  final categories = snapshot.data ?? [];

                  // Apply search filter
                  final filteredCategories = _searchQuery.isEmpty
                      ? categories
                      : categories.where((category) {
                          final languageProvider =
                              Provider.of<LanguageProvider>(context,
                                  listen: false);
                          final categoryName =
                              FirestoreHelper.getLocalizedFieldWithLanguage(
                            category,
                            'name',
                            languageProvider.languageCode,
                          );
                          return categoryName
                              .toLowerCase()
                              .contains(_searchQuery);
                        }).toList();

                  if (filteredCategories.isEmpty) {
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                                _searchQuery.isNotEmpty
                                    ? Icons.search_off
                                    : Icons.category_outlined,
                                size: 48,
                                color: Theme.of(context)
                                    .extension<CustomColors>()!
                                    .textTertiary),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? AppLocalizations.of(context)
                                      .translate('no_services_found')
                                  : AppLocalizations.of(context)
                                      .translate('no_categories_available'),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (_searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${AppLocalizations.of(context).translate('no_results_for')} "$_searchQuery"',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: () {
                                  _searchController.clear();
                                },
                                icon: const Icon(Icons.clear),
                                label: Text(AppLocalizations.of(context)
                                    .translate('clear_search')),
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: filteredCategories.length,
                    itemBuilder: (context, index) {
                      final category = filteredCategories[index];
                      final categoryId = category['id'] as String;

                      // Get localized category name (name_en or name_mr)
                      final languageProvider =
                          Provider.of<LanguageProvider>(context, listen: false);
                      final categoryName =
                          FirestoreHelper.getLocalizedFieldWithLanguage(
                        category,
                        'name',
                        languageProvider.languageCode,
                      );

                      final customLogoUrl =
                          category['customLogoUrl'] as String?;

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
                              AspectRatio(
                                aspectRatio: 1,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    customLogoUrl ?? '',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: const Color(0xFFEEEEEE),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                categoryName.isEmpty
                                    ? AppLocalizations.of(context)
                                        .translate('service')
                                    : categoryName,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
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
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                AppLocalizations.of(context).translate('quick_actions'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      Theme.of(context).extension<CustomColors>()!.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/refer'),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .extension<CustomColors>()!
                            .shadowColor,
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.share,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).translate('refer_earn'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .extension<CustomColors>()!
                                .textPrimary,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color: Theme.of(context)
                              .extension<CustomColors>()!
                              .textMuted),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
