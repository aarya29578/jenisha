import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class CommonBottomNavigation extends StatelessWidget {
  final int currentIndex;
  CommonBottomNavigation({this.currentIndex = 0});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        color: theme.scaffoldBackgroundColor,
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) {
          switch (i) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/applications');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/wallet');
              break;
            case 3:
              Navigator.pushReplacementNamed(context, '/refer');
              break;
            case 4:
              Navigator.pushReplacementNamed(context, '/profile');
              break;
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
            icon: const Icon(Icons.person, size: 24),
            label: l10n.translate('profile'),
          ),
        ],
      ),
    );
  }
}
