import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/auto_translate_service.dart';

/// A widget that displays dynamic text (e.g., from Firestore) and
/// auto-translates it to Marathi when the app is in Marathi mode.
///
/// If the text is already in a non-ASCII script (e.g., Devanagari), it is
/// shown as-is. If it is plain ASCII (English) and the app is in Marathi
/// mode, an async translation request is issued and the widget updates once
/// the result arrives.
class TranslatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const TranslatedText(
    this.text, {
    Key? key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  }) : super(key: key);

  @override
  State<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
  String _displayText = '';

  @override
  void initState() {
    super.initState();
    _displayText = widget.text;
    // Defer translation until after first frame so context is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTranslation());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-run translation whenever locale (AppLocalizations) changes.
    _loadTranslation();
  }

  @override
  void didUpdateWidget(TranslatedText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _displayText = widget.text;
      _loadTranslation();
    }
  }

  /// Returns true when [text] contains only ASCII characters (i.e., is
  /// likely English and may need translation).
  bool _isAscii(String text) => text.runes.every((c) => c < 128);

  Future<void> _loadTranslation() async {
    if (!mounted || widget.text.isEmpty) return;

    final loc = AppLocalizations.of(context);
    if (!loc.isMarathi) {
      // English mode – just show original text
      if (_displayText != widget.text) {
        setState(() => _displayText = widget.text);
      }
      return;
    }

    // Already Marathi / Devanagari – no translation needed
    if (!_isAscii(widget.text)) {
      if (_displayText != widget.text) {
        setState(() => _displayText = widget.text);
      }
      return;
    }

    // Try to get a cached (instant) translation first
    final cached = AutoTranslateService().translateSync(widget.text, to: 'mr');
    if (cached != widget.text) {
      if (mounted) setState(() => _displayText = cached);
      return;
    }

    // Fetch from Google Translate asynchronously
    final translated = await AutoTranslateService()
        .translate(widget.text, from: 'en', to: 'mr');
    if (mounted) setState(() => _displayText = translated);
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayText,
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
    );
  }
}
