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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _userStatus = 'pending';
  List<Map<String, dynamic>> _userDocuments = [];
  bool _statusLoaded = false;
  String _searchQuery = '';
  String? _profilePhotoUrl;
  String? _selectedCategoryId; // null = show all

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
      key: _scaffoldKey,
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white, size: 26),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          tooltip: 'Menu',
        ),
        title: Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            AppLocalizations.of(context).translate('app_title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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

            // Horizontal Category Chips
            _buildCategoryChips(),

            const SizedBox(height: 12),
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

                  // Apply search filter + side-category chip filter
                  final filteredCategories = categories.where((category) {
                    // Side-category chip filter: match by sideCategoryId
                    if (_selectedCategoryId != null &&
                        category['sideCategoryId'] != _selectedCategoryId) {
                      return false;
                    }
                    if (_searchQuery.isEmpty) return true;
                    final languageProvider =
                        Provider.of<LanguageProvider>(context, listen: false);
                    final categoryName =
                        FirestoreHelper.getLocalizedFieldWithLanguage(
                      category,
                      'name',
                      languageProvider.languageCode,
                    );
                    return categoryName.toLowerCase().contains(_searchQuery);
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
                      childAspectRatio: 0.70,
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

  // ── Drawer — shows side_categories (parent) ────────────────────────────────
  Widget _buildDrawer(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Drawer(
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.getActiveSideCategoriesStream(),
        builder: (context, snapshot) {
          final sideCategories = snapshot.data ?? [];
          final languageProvider =
              Provider.of<LanguageProvider>(context, listen: false);

          return Column(
            children: [
              // ── Header ───────────────────────────────────────────
              Container(
                width: double.infinity,
                color: primaryColor,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 20,
                  right: 20,
                  bottom: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.5), width: 2),
                      ),
                      child: const Icon(Icons.storefront,
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Jenisha Online Service',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Browse Categories',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // ── "All" tile ────────────────────────────────────────
              ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: _selectedCategoryId == null
                      ? primaryColor
                      : Colors.grey.shade200,
                  child: Icon(Icons.apps,
                      size: 18,
                      color: _selectedCategoryId == null
                          ? Colors.white
                          : Colors.grey.shade600),
                ),
                title: Text(
                  'All Services',
                  style: TextStyle(
                    fontWeight: _selectedCategoryId == null
                        ? FontWeight.w700
                        : FontWeight.normal,
                    color: _selectedCategoryId == null
                        ? primaryColor
                        : Colors.black87,
                  ),
                ),
                selected: _selectedCategoryId == null,
                selectedTileColor: primaryColor.withOpacity(0.06),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                onTap: () {
                  setState(() => _selectedCategoryId = null);
                  Navigator.pop(context);
                },
              ),

              const Divider(height: 1, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Text(
                  'CATEGORIES',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Colors.grey.shade500),
                ),
              ),

              // ── Side category list ────────────────────────────────
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting &&
                        sideCategories.isEmpty
                    ? Center(
                        child: CircularProgressIndicator(color: primaryColor))
                    : sideCategories.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('No categories configured.',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 13)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: sideCategories.length,
                            itemBuilder: (context, index) {
                              final sc = sideCategories[index];
                              final scId = sc['id'] as String;
                              final scName =
                                  FirestoreHelper.getLocalizedFieldWithLanguage(
                                sc,
                                'name',
                                languageProvider.languageCode,
                              );
                              final logoUrl =
                                  (sc['customLogoUrl']?.toString() ?? '')
                                      .trim();

                              return StreamBuilder<List<Map<String, dynamic>>>(
                                stream: _firestoreService
                                    .getCategoriesBySideCategory(scId),
                                builder: (context, childSnap) {
                                  final children = childSnap.data ?? [];
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent,
                                    ),
                                    child: ExpansionTile(
                                      tilePadding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 2),
                                      childrenPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        radius: 18,
                                        backgroundColor:
                                            primaryColor.withOpacity(0.12),
                                        child: logoUrl.isNotEmpty
                                            ? ClipOval(
                                                child: Image.network(
                                                  logoUrl,
                                                  width: 36,
                                                  height: 36,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      Icon(
                                                    Icons.folder_outlined,
                                                    size: 18,
                                                    color: primaryColor,
                                                  ),
                                                ),
                                              )
                                            : Icon(Icons.folder_outlined,
                                                size: 18, color: primaryColor),
                                      ),
                                      title: Text(
                                        scName.isEmpty ? 'Category' : scName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      iconColor: primaryColor,
                                      collapsedIconColor: Colors.grey,
                                      children: children.isEmpty
                                          ? [
                                              Padding(
                                                padding:
                                                    const EdgeInsets.fromLTRB(
                                                        56, 4, 16, 8),
                                                child: Text(
                                                  'No categories yet',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Colors.grey.shade400),
                                                ),
                                              ),
                                            ]
                                          : children.map((cat) {
                                              final catId = cat['id'] as String;
                                              final catName = FirestoreHelper
                                                  .getLocalizedFieldWithLanguage(
                                                cat,
                                                'name',
                                                languageProvider.languageCode,
                                              );
                                              final catLogo =
                                                  (cat['customLogoUrl']
                                                              ?.toString() ??
                                                          '')
                                                      .trim();
                                              return ListTile(
                                                contentPadding:
                                                    const EdgeInsets.only(
                                                        left: 56, right: 16),
                                                leading: catLogo.isNotEmpty
                                                    ? ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        child: Image.network(
                                                          catLogo,
                                                          width: 28,
                                                          height: 28,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (_, __,
                                                                  ___) =>
                                                              Icon(
                                                                  Icons
                                                                      .category_outlined,
                                                                  size: 18,
                                                                  color: Colors
                                                                      .grey),
                                                        ),
                                                      )
                                                    : Icon(
                                                        Icons.category_outlined,
                                                        size: 18,
                                                        color: Colors
                                                            .grey.shade500),
                                                title: Text(
                                                  catName.isEmpty
                                                      ? 'Category'
                                                      : catName,
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.black87),
                                                ),
                                                trailing: Icon(
                                                    Icons.chevron_right,
                                                    size: 16,
                                                    color:
                                                        Colors.grey.shade400),
                                                dense: true,
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  Navigator.pushNamed(
                                                    context,
                                                    '/category-detail',
                                                    arguments: {
                                                      'id': catId,
                                                      'name': catName,
                                                    },
                                                  );
                                                },
                                              );
                                            }).toList(),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
              ),

              // ── Bottom quick links ────────────────────────────────
              const Divider(height: 1),
              ListTile(
                leading:
                    Icon(Icons.share_outlined, color: primaryColor, size: 22),
                title: Text(
                  AppLocalizations.of(context).translate('refer_earn'),
                  style: const TextStyle(fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/refer');
                },
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  // ── Horizontal side-category chip bar (positioned below Services title) ────
  Widget _buildCategoryChips() {
    final primaryColor = Theme.of(context).primaryColor;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getActiveSideCategoriesStream(),
      builder: (context, snapshot) {
        final sideCategories = snapshot.data ?? [];
        if (sideCategories.isEmpty) return const SizedBox.shrink();

        final languageProvider =
            Provider.of<LanguageProvider>(context, listen: false);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: sideCategories.length + 1, // +1 for "All"
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected = _selectedCategoryId == null;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategoryId = null),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: primaryColor.withOpacity(0.3), width: 1),
                      ),
                      child: Text(
                        'All',
                        style: TextStyle(
                          color: isSelected ? Colors.white : primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }

                final sc = sideCategories[index - 1];
                final scId = sc['id'] as String;
                final scName = FirestoreHelper.getLocalizedFieldWithLanguage(
                  sc,
                  'name',
                  languageProvider.languageCode,
                );
                final isSelected = _selectedCategoryId == scId;

                return GestureDetector(
                  onTap: () => setState(() => _selectedCategoryId = scId),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? primaryColor : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: primaryColor.withOpacity(0.3), width: 1),
                    ),
                    child: Text(
                      scName.isEmpty ? 'Category' : scName,
                      style: TextStyle(
                        color: isSelected ? Colors.white : primaryColor,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
