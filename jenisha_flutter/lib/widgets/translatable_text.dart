import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../l10n/app_localizations.dart';
import '../providers/language_provider.dart';
import 'package:provider/provider.dart';

/// Global enforcement widget for translation
/// ALL visible text MUST use this widget
/// This ensures zero English leakage in Marathi mode
class TranslatableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;

  const TranslatableText(
    this.text, {
    Key? key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    // Debug mode: detect English leakage in Marathi mode
    if (kDebugMode) {
      final languageProvider =
          Provider.of<LanguageProvider>(context, listen: false);
      if (languageProvider.isMarathi && _containsEnglish(text)) {
        debugPrint('⚠️ Untranslated English detected: "$text"');
      }
    }

    return Text(
      localizations.translateText(text),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
    );
  }

  /// Check if text contains English characters
  bool _containsEnglish(String text) {
    if (text.isEmpty) return false;

    // Ignore numbers, symbols, and whitespace
    final alphaOnly =
        text.replaceAll(RegExp(r'[0-9\s\p{P}₹$€£¥]+', unicode: true), '');
    if (alphaOnly.isEmpty) return false;

    // Check for English letters
    return RegExp(r'[A-Za-z]').hasMatch(alphaOnly);
  }
}

/// Use for simple text rendering without style customization
class Txt extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const Txt(this.text, {Key? key, this.style}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TranslatableText(text, style: style);
  }
}
