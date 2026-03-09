import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';

/// Helper for reading bilingual Firestore data
/// Automatically returns name_en or name_mr based on current language
class FirestoreHelper {
  /// Get localized field value from Firestore document
  /// field: 'name', 'title', 'description', etc.
  /// Returns name_mr if Marathi, name_en if English
  static String getLocalizedField(
    Map<String, dynamic> data,
    String field,
    BuildContext context,
  ) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final languageCode = languageProvider.languageCode;

    return getLocalizedFieldWithLanguage(data, field, languageCode);
  }

  /// Get localized field value with explicit language code
  static String getLocalizedFieldWithLanguage(
    Map<String, dynamic> data,
    String field,
    String languageCode,
  ) {
    final suffix = languageCode == 'mr' ? '_mr' : '_en';
    final localizedField = '$field$suffix';

    // Try localized field first (new bilingual format)
    if (data.containsKey(localizedField)) {
      return data[localizedField] as String? ?? '';
    }

    // Fallback: Try English field
    if (data.containsKey('${field}_en')) {
      return data['${field}_en'] as String? ?? '';
    }

    // Fallback: Try non-suffixed field (legacy data)
    if (data.containsKey(field)) {
      return data[field] as String? ?? '';
    }

    return '';
  }

  /// Create bilingual map for Firestore write
  /// Input: {name: "Passport", description: "Apply for passport"}
  /// Output: {name_en: "Passport", name_mr: "पासपोर्ट", description_en: "...", description_mr: "..."}
  static Map<String, dynamic> createBilingualMap(
    Map<String, dynamic> data,
    Map<String, String> marathiTranslations,
  ) {
    final bilingualData = <String, dynamic>{};

    // Copy all non-translated fields
    data.forEach((key, value) {
      if (!marathiTranslations.containsKey(key)) {
        bilingualData[key] = value;
      }
    });

    // Add bilingual fields
    marathiTranslations.forEach((field, marathiValue) {
      if (data.containsKey(field)) {
        bilingualData['${field}_en'] = data[field];
        bilingualData['${field}_mr'] = marathiValue;
      }
    });

    return bilingualData;
  }

  /// Extract query parameter with localization support
  static String getLocalizedFromArgs(
    Map<String, dynamic> args,
    String field,
    BuildContext context,
  ) {
    return getLocalizedField(args, field, context);
  }
}

/// Extension on DocumentSnapshot for easy localized access
extension LocalizedDocumentSnapshot on DocumentSnapshot {
  String getLocalized(String field, String languageCode) {
    final data = this.data();
    if (data == null || data is! Map<String, dynamic>) return '';
    return FirestoreHelper.getLocalizedFieldWithLanguage(
        data, field, languageCode);
  }
}

/// Extension on QueryDocumentSnapshot for easy localized access
extension LocalizedQueryDocumentSnapshot on QueryDocumentSnapshot {
  String getLocalized(String field, String languageCode) {
    final data = this.data();
    if (data is! Map<String, dynamic>) return '';
    return FirestoreHelper.getLocalizedFieldWithLanguage(
        data, field, languageCode);
  }
}
