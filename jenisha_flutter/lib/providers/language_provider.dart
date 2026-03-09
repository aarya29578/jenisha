import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auto_translate_service.dart';

class LanguageProvider with ChangeNotifier {
  Locale _locale = const Locale('en'); // Default English
  static const String _languageKey = 'app_language';

  Locale get locale => _locale;

  String get languageCode => _locale.languageCode;

  String get languageName => _locale.languageCode == 'en' ? 'English' : 'मराठी';

  bool get isEnglish => _locale.languageCode == 'en';
  bool get isMarathi => _locale.languageCode == 'mr';

  LanguageProvider() {
    // Always start in English; do not restore previous language selection.
    _initDefault();
  }

  // Ensure AutoTranslateService is aligned with the default English locale.
  void _initDefault() {
    final autoTranslate = AutoTranslateService();
    autoTranslate.setLanguage('en');
  }

  // Load saved language preference (kept for reference, not called on startup)
  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_languageKey) ?? 'en';
      _locale = Locale(languageCode);

      // Update AutoTranslateService language
      final autoTranslate = AutoTranslateService();
      autoTranslate.setLanguage(languageCode);

      // Pre-translate common terms if Marathi
      if (languageCode == 'mr') {
        _preTranslateCommonTerms(autoTranslate);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading language preference: $e');
    }
  }

  // Set language and save preference
  Future<void> setLanguage(String languageCode) async {
    if (_locale.languageCode == languageCode) return;

    _locale = Locale(languageCode);

    // Update AutoTranslateService language
    final autoTranslate = AutoTranslateService();
    autoTranslate.setLanguage(languageCode);

    // Pre-translate common terms for Marathi
    if (languageCode == 'mr') {
      _preTranslateCommonTerms(autoTranslate);
    }

    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
      debugPrint('Language saved: $languageCode');
    } catch (e) {
      debugPrint('Error saving language preference: $e');
    }
  }

  // Pre-translate common terms to warm up the cache
  Future<void> _preTranslateCommonTerms(
      AutoTranslateService autoTranslate) async {
    final commonTerms = [
      'raj',
      'aarr',
      'lic',
      'drive',
      'passport',
      'pan',
      'aadhaar',
      'license',
      'insurance',
      'loan',
      'account',
      'card',
      'form',
      'certificate',
      'document',
      'application',
      'status',
      'pending',
      'approved',
      'rejected',
      'completed',
      'processing',
      'submitted',
      'Pending',
      'Approved',
      'Rejected',
      'Completed',
      'In Progress',
      'Unknown Service',
      'Unknown Customer',
    ];

    // Trigger translations asynchronously
    for (final term in commonTerms) {
      autoTranslate.translate(term).then((translated) {
        debugPrint('Pre-translated: $term → $translated');
      }).catchError((e) {
        debugPrint('Translation error for $term: $e');
      });
    }
  }

  // Toggle between English and Marathi
  Future<void> toggleLanguage() async {
    final newLanguage = _locale.languageCode == 'en' ? 'mr' : 'en';
    await setLanguage(newLanguage);
  }

  // Set English
  Future<void> setEnglish() async {
    await setLanguage('en');
  }

  // Set Marathi
  Future<void> setMarathi() async {
    await setLanguage('mr');
  }
}
