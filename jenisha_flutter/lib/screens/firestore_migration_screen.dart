import 'package:flutter/material.dart';
import '../services/bilingual_translation_service.dart';
import '../theme/app_theme.dart';

/// One-time migration script to convert all Firestore data to bilingual format
/// Run this ONCE to migrate existing data
/// After migration, all admin operations should use bilingual format automatically
class FirestoreMigrationScreen extends StatefulWidget {
  const FirestoreMigrationScreen({Key? key}) : super(key: key);

  @override
  State<FirestoreMigrationScreen> createState() =>
      _FirestoreMigrationScreenState();
}

class _FirestoreMigrationScreenState extends State<FirestoreMigrationScreen> {
  final BilingualTranslationService _translationService =
      BilingualTranslationService();
  bool _isMigrating = false;
  String _migrationStatus = 'Ready to migrate';
  final List<String> _migrationLogs = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore Migration'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Database Migration',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will convert all Firestore documents to bilingual format (name_en, name_mr). Run this ONCE.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Status: $_migrationStatus',
                      style: TextStyle(
                        color: _isMigrating
                            ? Theme.of(context)
                                .extension<CustomColors>()!
                                .warning
                            : Theme.of(context)
                                .extension<CustomColors>()!
                                .success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isMigrating ? null : _runMigration,
              child: Text(
                _isMigrating ? 'Migrating...' : 'Start Migration',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Migration Log:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _migrationLogs.isEmpty
                    ? const Center(
                        child: Text(
                          'No logs yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _migrationLogs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Text(
                              _migrationLogs[index],
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runMigration() async {
    setState(() {
      _isMigrating = true;
      _migrationStatus = 'Migration in progress...';
      _migrationLogs.clear();
    });

    _log('🚀 Starting migration...');

    try {
      // Migrate categories
      _log('📂 Migrating categories collection...');
      await _translationService.migrateCollection(
        'categories',
        fieldsToTranslate: ['name'],
      );
      _log('✅ Categories migrated');

      // Migrate services
      _log('📂 Migrating services collection...');
      await _translationService.migrateCollection(
        'services',
        fieldsToTranslate: ['name', 'description'],
      );
      _log('✅ Services migrated');

      // Migrate banners
      _log('📂 Migrating banners collection...');
      await _translationService.migrateCollection(
        'banners',
        fieldsToTranslate: ['title'],
      );
      _log('✅ Banners migrated');

      _log('✅✅✅ Migration completed successfully!');

      setState(() {
        _migrationStatus = 'Migration completed successfully';
        _isMigrating = false;
      });

      // Show success dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Migration Complete'),
            content: const Text(
              'All Firestore data has been migrated to bilingual format. '
              'You can now close this screen.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _log('❌ Migration error: $e');

      setState(() {
        _migrationStatus = 'Migration failed';
        _isMigrating = false;
      });

      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Migration Error'),
            content: Text('Migration failed: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _log(String message) {
    setState(() {
      _migrationLogs.add(
          '${DateTime.now().toIso8601String().substring(11, 19)} $message');
    });
    debugPrint(message);
  }
}
