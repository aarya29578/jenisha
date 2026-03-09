import 'package:flutter/material.dart';
import '../services/auto_translate_service.dart';
import '../l10n/app_localizations.dart';

/// A Text widget that automatically translates its content based on current locale
///
/// Usage:
///   AutoTranslatedText('Hello World')  // Automatically translates to Marathi
///
/// Or use extension method on String:
///   'Hello World'.tr(context)
///
class AutoTranslatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AutoTranslatedText(
    this.text, {
    Key? key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : super(key: key);

  @override
  State<AutoTranslatedText> createState() => _AutoTranslatedTextState();
}

class _AutoTranslatedTextState extends State<AutoTranslatedText> {
  final AutoTranslateService _translator = AutoTranslateService();
  String _translatedText = '';
  bool _isTranslating = false;

  @override
  void initState() {
    super.initState();
    _translateText();
  }

  @override
  void didUpdateWidget(AutoTranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _translateText();
    }
  }

  void _translateText() async {
    final locale = Localizations.localeOf(context);

    // If English, no translation needed
    if (locale.languageCode == 'en') {
      setState(() {
        _translatedText = widget.text;
      });
      return;
    }

    // Get sync translation (from cache or original)
    final syncText = _translator.translateSync(widget.text);
    setState(() {
      _translatedText = syncText;
    });

    // If not cached, translate async
    if (syncText == widget.text && !_isTranslating) {
      _isTranslating = true;
      final translated = await _translator.translate(widget.text);
      if (mounted) {
        setState(() {
          _translatedText = translated;
          _isTranslating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _translatedText.isEmpty ? widget.text : _translatedText,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}

/// Extension method to easily translate strings
extension StringTranslationExtension on String {
  /// Automatically translate this string to current locale
  ///
  /// Usage: 'Hello World'.tr(context)
  String tr(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return localizations.translateText(this);
  }

  /// Get a widget that auto-translates this text
  ///
  /// Usage: 'Hello World'.toAutoText()
  Widget toAutoText({
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return AutoTranslatedText(
      this,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
