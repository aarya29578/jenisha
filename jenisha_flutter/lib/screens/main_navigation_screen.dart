import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'applications_screen.dart';
import 'wallet_screen.dart';
import 'refer_screen.dart';
import 'profile_screen.dart';
import 'appointments_screen.dart';
import 'category_detail_screen.dart';
import 'service_form_screen.dart';
import 'account_status_screen.dart';
import 'downloaded_certificates_screen.dart';

/// MainNavigationScreen
///
/// Owns the BottomNavigationBar and a nested Navigator per tab so that
/// sub-screens (category-detail, service-form, account-status, …) are pushed
/// INSIDE the current tab's navigator, keeping the bottom bar permanently
/// visible on every screen.
class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavigationScreen({Key? key, this.initialIndex = 0})
      : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  StreamSubscription<DocumentSnapshot>? _userDocSub;

  /// Watch the current user's Firestore document. If admin deletes it,
  /// sign out and redirect to the login screen.
  void _listenForAccountDeletion() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) async {
      if (!snap.exists) {
        // Account was deleted by admin — sign out and go to login
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.of(context, rootNavigator: true)
              .pushNamedAndRemoveUntil('/login', (route) => false);
        }
      }
    });
  }

  /// One dedicated navigator key per tab – preserves the full route stack
  /// independently for each tab while the app runs.
  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    5,
    (_) => GlobalKey<NavigatorState>(),
  );

  /// Root widget shown at the bottom of each tab's navigator stack.
  static const List<Widget> _tabRoots = [
    HomeScreen(),
    ApplicationsScreen(),
    WalletScreen(),
    ReferScreen(),
    AppointmentsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _listenForAccountDeletion();
  }

  @override
  void dispose() {
    _userDocSub?.cancel();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Route generator shared by all five nested navigators.
  // Add new in-app routes here so they open inside the current tab.
  // -----------------------------------------------------------------------
  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // ── Tab roots (reached when e.g. home-screen quick-action uses pushNamed)
      case '/home':
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
          settings: settings,
        );
      case '/applications':
        return MaterialPageRoute(
          builder: (_) => const ApplicationsScreen(),
          settings: settings,
        );
      case '/wallet':
        return MaterialPageRoute(
          builder: (_) => const WalletScreen(),
          settings: settings,
        );
      case '/refer':
        return MaterialPageRoute(
          builder: (_) => const ReferScreen(),
          settings: settings,
        );
      case '/appointments':
        return MaterialPageRoute(
          builder: (_) => const AppointmentsScreen(),
          settings: settings,
        );
      case '/profile':
        return MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
          settings: settings,
        );

      // ── Sub-screens that must stay inside the current tab
      case '/category-detail':
        return MaterialPageRoute(
          builder: (_) => const CategoryDetailScreen(),
          settings: settings,
        );
      case '/service-form':
        return MaterialPageRoute(
          builder: (_) => const ServiceFormScreen(),
          settings: settings,
        );
      case '/account-status':
        return MaterialPageRoute(
          builder: (_) => const AccountStatusScreen(),
          settings: settings,
        );
      case '/downloaded-certificates':
        return MaterialPageRoute(
          builder: (_) => const DownloadedCertificatesScreen(),
          settings: settings,
        );

      // Unknown routes: return null so the root navigator can try.
      default:
        return null;
    }
  }

  // -----------------------------------------------------------------------
  // Android back-button handling:
  //   1. If the active tab has a non-root screen → pop it.
  //   2. Else if we are not on the Home tab → go to Home tab.
  //   3. Else → exit the app.
  // -----------------------------------------------------------------------
  Future<bool> _onWillPop() async {
    final navState = _navigatorKeys[_currentIndex].currentState;
    if (navState != null && navState.canPop()) {
      navState.pop();
      return false; // Do not exit
    }
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return false; // Do not exit
    }
    return true; // Let the OS exit the app
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        // ── Tab bodies ────────────────────────────────────────────────────
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(5, (tabIndex) {
            return Navigator(
              key: _navigatorKeys[tabIndex],
              onGenerateRoute: (routeSettings) {
                // Initial route of this tab
                if (routeSettings.name == '/' || routeSettings.name == null) {
                  return MaterialPageRoute(
                    builder: (_) => _tabRoots[tabIndex],
                    settings: routeSettings,
                  );
                }
                return _generateRoute(routeSettings);
              },
            );
          }),
        ),

        // ── Persistent bottom bar ─────────────────────────────────────────
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
            color: theme.scaffoldBackgroundColor,
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              if (index == _currentIndex) {
                // Tap on the already-active tab: pop back to its root screen.
                _navigatorKeys[index]
                    .currentState
                    ?.popUntil((route) => route.isFirst);
              } else {
                setState(() => _currentIndex = index);
              }
            },
            backgroundColor: theme.scaffoldBackgroundColor,
            selectedItemColor: theme.primaryColor,
            unselectedItemColor: Colors.grey.shade600,
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            elevation: 0,
            selectedLabelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            unselectedLabelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home, size: 24),
                label: l10n.translate('home'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.description, size: 24),
                label: l10n.translate('applications'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.account_balance_wallet, size: 24),
                label: l10n.translate('wallet'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.share, size: 24),
                label: l10n.translate('refer'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.calendar_month, size: 24),
                label: 'Appointments',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
