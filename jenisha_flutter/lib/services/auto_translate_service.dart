import 'package:translator/translator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AutoTranslateService {
  static final AutoTranslateService _instance =
      AutoTranslateService._internal();
  factory AutoTranslateService() => _instance;
  AutoTranslateService._internal();

  final GoogleTranslator _translator = GoogleTranslator();
  final Map<String, String> _cache = {};
  bool _isInitialized = false;
  String _currentLanguage = 'en';

  /// Initialize the service and load cached translations
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('translation_cache');
      if (cachedJson != null) {
        final Map<String, dynamic> decoded = json.decode(cachedJson);
        _cache.addAll(decoded.cast<String, String>());
      }
      _isInitialized = true;
    } catch (e) {
      print('Error initializing translation cache: $e');
      _isInitialized = true;
    }
  }

  /// Set the current language
  void setLanguage(String languageCode) {
    _currentLanguage = languageCode;
  }

  /// Get current language
  String get currentLanguage => _currentLanguage;

  /// Translate text from English to target language
  /// If language is 'en', returns original text
  /// If translation is cached, returns from cache
  /// Otherwise, translates via Google Translate API and caches result
  Future<String> translate(String text,
      {String from = 'en', String? to}) async {
    if (!_isInitialized) {
      await initialize();
    }

    final targetLang = to ?? _currentLanguage;

    // If target language is English, return original
    if (targetLang == 'en') {
      return text;
    }

    // Check cache
    final cacheKey = '${from}_${targetLang}_$text';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // Translate
    try {
      final translation = await _translator.translate(
        text,
        from: from,
        to: targetLang,
      );

      final translatedText = translation.text;

      // Cache the translation
      _cache[cacheKey] = translatedText;
      _saveCacheToPrefs();

      return translatedText;
    } catch (e) {
      print('Translation error: $e');
      // Return original text on error
      return text;
    }
  }

  /// Synchronous translation - returns cached value or original text
  /// Use this for immediate display, then update with async translate
  String translateSync(String text, {String from = 'en', String? to}) {
    final targetLang = to ?? _currentLanguage;

    if (targetLang == 'en') {
      return text;
    }

    final cacheKey = '${from}_${targetLang}_$text';
    return _cache[cacheKey] ?? text;
  }

  /// Save cache to SharedPreferences
  Future<void> _saveCacheToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(_cache);
      await prefs.setString('translation_cache', jsonString);
    } catch (e) {
      print('Error saving translation cache: $e');
    }
  }

  /// Clear all cached translations
  Future<void> clearCache() async {
    _cache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('translation_cache');
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  /// Preload translations for common phrases
  Future<void> preloadCommonPhrases(List<String> phrases,
      {String to = 'mr'}) async {
    for (final phrase in phrases) {
      await translate(phrase, to: to);
    }
  }
}
