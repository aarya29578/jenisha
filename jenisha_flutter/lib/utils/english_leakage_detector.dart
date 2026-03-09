import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

/// English Leakage Detection System
/// Detects and logs any English text displayed in Marathi mode
/// For debug builds only
class EnglishLeakageDetector {
  static final EnglishLeakageDetector _instance =
      EnglishLeakageDetector._internal();
  factory EnglishLeakageDetector() => _instance;
  EnglishLeakageDetector._internal();

  final Set<String> _detectedLeaks = {};
  bool _isEnabled = true;

  /// Enable or disable leak detection
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Check if text contains English characters
  bool containsEnglish(String text) {
    if (text.isEmpty) return false;

    // Ignore numbers, symbols, and whitespace
    final alphaOnly =
        text.replaceAll(RegExp(r'[0-9\s\p{P}₹$€£¥]+', unicode: true), '');
    if (alphaOnly.isEmpty) return false;

    // Check for English letters
    return RegExp(r'[A-Za-z]').hasMatch(alphaOnly);
  }

  /// Detect and log English leakage
  void detect(String text, BuildContext context, {String? source}) {
    if (!_isEnabled) return;
    if (!kDebugMode) return;

    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    if (!languageProvider.isMarathi) return;

    if (containsEnglish(text)) {
      final leak = '${source ?? 'Unknown'}: "$text"';

      // Only log once per unique leak
      if (!_detectedLeaks.contains(leak)) {
        _detectedLeaks.add(leak);
        debugPrint('⚠️ ENGLISH LEAKAGE DETECTED: $leak');
      }
    }
  }

  /// Get all detected leaks
  List<String> getAllLeaks() {
    return _detectedLeaks.toList()..sort();
  }

  /// Clear all detected leaks
  void clearLeaks() {
    _detectedLeaks.clear();
  }

  /// Get leak statistics
  Map<String, dynamic> getStats() {
    return {
      'total_leaks': _detectedLeaks.length,
      'is_enabled': _isEnabled,
      'leaks': getAllLeaks(),
    };
  }
}

/// Debug widget to show English leakage report
class EnglishLeakageReport extends StatelessWidget {
  const EnglishLeakageReport({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final detector = EnglishLeakageDetector();
    final stats = detector.getStats();
    final leaks = stats['leaks'] as List<String>;

    return Scaffold(
      appBar: AppBar(
        title: const Text('English Leakage Report'),
        backgroundColor: const Color(0xFF1E40AF),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              detector.clearLeaks();
              Navigator.pop(context);
            },
            tooltip: 'Clear leaks',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: leaks.isEmpty ? Colors.green.shade50 : Colors.orange.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total English Leaks: ${stats['total_leaks']}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: leaks.isEmpty
                        ? Colors.green.shade900
                        : Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  leaks.isEmpty
                      ? '✅ No English leakage detected in Marathi mode'
                      : '⚠️ Some English text is still visible',
                  style: TextStyle(
                    color: leaks.isEmpty
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: leaks.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 64, color: Colors.green),
                        SizedBox(height: 16),
                        Text(
                          'All Clear!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No English leakage detected',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: leaks.length,
                    itemBuilder: (context, index) {
                      final leak = leaks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(
                            Icons.warning,
                            color: Colors.orange,
                          ),
                          title: Text(
                            leak,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
