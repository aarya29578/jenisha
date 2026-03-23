import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'providers/language_provider.dart';
import 'services/auto_translate_service.dart';
import 'screens/home_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/login_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/user_registration_form_screen.dart';
import 'screens/registration_documents_screen.dart';
import 'screens/registration_status_screen.dart';
import 'screens/account_status_screen.dart';
import 'screens/applications_screen.dart';
import 'screens/category_detail_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/refer_screen.dart';
import 'screens/service_form_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/firestore_migration_screen.dart';
import 'screens/downloaded_certificates_screen.dart';
import 'screens/side_category_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Prevent duplicate initialization
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase initialized successfully');
    } else {
      print('✅ Firebase already initialized');
    }
  } catch (e) {
    print('❌ Firebase initialization error: $e');
    // Continue without Firebase if initialization fails
  }

  // Clear translation cache and reinitialize (remove after first run)
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('translation_cache');
    print('✅ Translation cache cleared');
  } catch (e) {
    print('❌ Cache clear error: $e');
  }

  // Initialize auto-translation service
  try {
    final autoTranslate = AutoTranslateService();
    await autoTranslate.initialize();
    print('✅ Auto-translation service initialized');
  } catch (e) {
    print('❌ Auto-translation initialization error: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: const JenishaApp(),
    ),
  );
}

class JenishaApp extends StatelessWidget {
  const JenishaApp();

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return MaterialApp(
          title: 'Jenisha Online Service',
          debugShowCheckedModeBanner: false,
          locale: languageProvider.locale,
          supportedLocales: const [
            Locale('en', ''),
            Locale('mr', ''),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // ============================================================
          // USE CENTRALIZED THEME - DO NOT OVERRIDE ANYWHERE
          // ============================================================
          theme: AppTheme.lightTheme,
          initialRoute: '/login',
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/login':
                return MaterialPageRoute(builder: (_) => const LoginScreen());
              case '/otp':
                return MaterialPageRoute(
                    builder: (_) => const OTPVerificationScreen());
              case '/home':
                return MaterialPageRoute(
                    builder: (_) =>
                        const MainNavigationScreen(initialIndex: 0));
              case '/registration':
                return MaterialPageRoute(
                    builder: (_) => const UserRegistrationFormScreen());
              case '/registration-documents':
                return MaterialPageRoute(
                    builder: (_) => const RegistrationDocumentsScreen());
              case '/registration-status':
                return MaterialPageRoute(
                  builder: (_) => const RegistrationStatusScreen(),
                  settings: RouteSettings(
                      name: settings.name, arguments: settings.arguments),
                );
              case '/account-status':
                return MaterialPageRoute(
                  builder: (_) => const AccountStatusScreen(),
                  settings: RouteSettings(
                      name: settings.name, arguments: settings.arguments),
                );
              case '/applications':
                return MaterialPageRoute(
                    builder: (_) =>
                        const MainNavigationScreen(initialIndex: 1));
              case '/category-detail':
                return MaterialPageRoute(
                  builder: (_) => const CategoryDetailScreen(),
                  settings: RouteSettings(
                      name: settings.name, arguments: settings.arguments),
                );
              case '/side-category':
                return MaterialPageRoute(
                  builder: (_) => const SideCategoryScreen(),
                  settings: RouteSettings(
                      name: settings.name, arguments: settings.arguments),
                );
              case '/profile':
                return MaterialPageRoute(builder: (_) => const ProfileScreen());
              case '/refer':
                return MaterialPageRoute(
                    builder: (_) =>
                        const MainNavigationScreen(initialIndex: 3));
              case '/service-form':
                return MaterialPageRoute(
                  builder: (_) => const ServiceFormScreen(),
                  settings: RouteSettings(
                      name: settings.name, arguments: settings.arguments),
                );
              case '/wallet':
                return MaterialPageRoute(
                    builder: (_) =>
                        const MainNavigationScreen(initialIndex: 2));
              case '/migration':
                return MaterialPageRoute(
                    builder: (_) => const FirestoreMigrationScreen());
              case '/downloaded-certificates':
                return MaterialPageRoute(
                    builder: (_) => const DownloadedCertificatesScreen());
              default:
                return MaterialPageRoute(builder: (_) => const LoginScreen());
            }
          },
        );
      },
    );
  }
}
