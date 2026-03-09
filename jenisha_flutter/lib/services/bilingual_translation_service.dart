import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:translator/translator.dart';
import 'package:flutter/foundation.dart';

/// Bilingual Translation Service
/// Stores translations directly in Firestore - NO render-time translation
/// Admin content is translated ONCE on save, not on every render
class BilingualTranslationService {
  static final BilingualTranslationService _instance =
      BilingualTranslationService._internal();
  factory BilingualTranslationService() => _instance;
  BilingualTranslationService._internal();

  final GoogleTranslator _translator = GoogleTranslator();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Translate text from English to Marathi
  /// Returns translated text or original if translation fails
  Future<String> translateToMarathi(String englishText) async {
    if (englishText.isEmpty) return '';

    try {
      final translation = await _translator.translate(
        englishText,
        from: 'en',
        to: 'mr',
      );
      return translation.text;
    } catch (e) {
      debugPrint('❌ Translation error: $e');
      return englishText; // Fallback to original
    }
  }

  /// Create bilingual document data
  /// Converts: name -> name_en, name_mr
  Future<Map<String, dynamic>> createBilingualData(
    Map<String, dynamic> data, {
    List<String> fieldsToTranslate = const [
      'name',
      'title',
      'description',
      'label'
    ],
  }) async {
    final bilingualData = Map<String, dynamic>.from(data);

    for (final field in fieldsToTranslate) {
      if (data.containsKey(field) && data[field] is String) {
        final englishText = data[field] as String;

        // Store English version
        bilingualData['${field}_en'] = englishText;

        // Translate and store Marathi version
        final marathiText = await translateToMarathi(englishText);
        bilingualData['${field}_mr'] = marathiText;

        // Remove old non-suffixed field
        bilingualData.remove(field);

        debugPrint('✅ Translated: $englishText → $marathiText');
      }
    }

    return bilingualData;
  }

  /// Get localized value from bilingual data
  /// Returns name_mr if Marathi, name_en if English
  String getLocalizedValue(
    Map<String, dynamic> data,
    String field,
    String languageCode,
  ) {
    final suffix = languageCode == 'mr' ? '_mr' : '_en';
    final localizedField = '$field$suffix';

    // Try localized field first
    if (data.containsKey(localizedField)) {
      return data[localizedField] as String? ?? '';
    }

    // Fallback to non-suffixed field (legacy data)
    if (data.containsKey(field)) {
      return data[field] as String? ?? '';
    }

    return '';
  }

  /// Migrate existing document to bilingual format
  Future<void> migrateDocument(
    String collectionPath,
    String docId, {
    List<String> fieldsToTranslate = const [
      'name',
      'title',
      'description',
      'label'
    ],
  }) async {
    try {
      final docRef = _firestore.collection(collectionPath).doc(docId);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        debugPrint('❌ Document not found: $collectionPath/$docId');
        return;
      }

      final data = docSnapshot.data()!;
      bool needsUpdate = false;

      final updates = <String, dynamic>{};

      for (final field in fieldsToTranslate) {
        // Check if already bilingual
        if (data.containsKey('${field}_en') &&
            data.containsKey('${field}_mr')) {
          continue; // Already migrated
        }

        // Check if field exists and needs migration
        if (data.containsKey(field) && data[field] is String) {
          final englishText = data[field] as String;

          updates['${field}_en'] = englishText;
          final marathiText = await translateToMarathi(englishText);
          updates['${field}_mr'] = marathiText;

          needsUpdate = true;
          debugPrint(
              '✅ Migrated $collectionPath/$docId: $field = $englishText → $marathiText');
        }
      }

      if (needsUpdate) {
        await docRef.update(updates);
        debugPrint('✅ Document migrated: $collectionPath/$docId');
      }
    } catch (e) {
      debugPrint('❌ Migration error for $collectionPath/$docId: $e');
    }
  }

  /// Migrate entire collection to bilingual format
  Future<void> migrateCollection(
    String collectionPath, {
    List<String> fieldsToTranslate = const [
      'name',
      'title',
      'description',
      'label'
    ],
  }) async {
    try {
      debugPrint('🔄 Starting migration for collection: $collectionPath');

      final querySnapshot = await _firestore.collection(collectionPath).get();
      final totalDocs = querySnapshot.docs.length;

      debugPrint('📊 Found $totalDocs documents to migrate');

      int migratedCount = 0;
      for (final doc in querySnapshot.docs) {
        await migrateDocument(collectionPath, doc.id,
            fieldsToTranslate: fieldsToTranslate);
        migratedCount++;

        if (migratedCount % 10 == 0) {
          debugPrint('📈 Progress: $migratedCount/$totalDocs documents');
        }
      }

      debugPrint(
          '✅ Migration completed: $collectionPath ($migratedCount documents)');
    } catch (e) {
      debugPrint('❌ Collection migration error: $e');
    }
  }

  /// Migrate all app collections
  Future<void> migrateAllCollections() async {
    debugPrint('🚀 Starting full database migration...');

    // Migrate categories
    await migrateCollection('categories', fieldsToTranslate: ['name']);

    // Migrate services
    await migrateCollection('services',
        fieldsToTranslate: ['name', 'description']);

    // Migrate banners
    await migrateCollection('banners', fieldsToTranslate: ['title']);

    // Migrate document types (if exists)
    await migrateCollection('documentTypes',
        fieldsToTranslate: ['name', 'label']);

    debugPrint('✅ Full migration completed!');
  }
}
