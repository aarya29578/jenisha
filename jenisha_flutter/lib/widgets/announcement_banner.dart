import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

/// Real-time announcement banner driven by Firestore.
///
/// Behaviour:
/// - Queries announcements where isActive == true (no orderBy → no index needed).
/// - During stream loading, renders from last-known cached values → no flicker.
/// - Disappears only when the admin sets every document's isActive to false
///   AND all cached state is cleared.
class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({Key? key}) : super(key: key);

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  // Last-known active announcement — preserved across stream reloads
  String? _activeTitle;
  String? _activeUrl;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // No orderBy, no limit — avoids composite index requirement.
      // Admin panel guarantees at most one active document at a time.
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        // ── Update cache when new data arrives ──────────────────────────────
        if (snapshot.hasData) {
          if (snapshot.data!.docs.isNotEmpty) {
            final data =
                snapshot.data!.docs.first.data() as Map<String, dynamic>;
            final newTitle = (data['title'] as String? ?? '').trim();
            final newUrl = (data['url'] as String? ?? '').trim();
            // Only call setState if values actually changed
            if (newTitle != _activeTitle || newUrl != _activeUrl) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _activeTitle = newTitle.isEmpty ? null : newTitle;
                    _activeUrl = newUrl;
                  });
                }
              });
            }
          } else {
            // Firestore confirmed no active document → clear cache
            if (_activeTitle != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted)
                  setState(() {
                    _activeTitle = null;
                    _activeUrl = null;
                  });
              });
            }
          }
        }

        // ── Render decision ─────────────────────────────────────────────────
        // Hide only when we have no cached title (either never loaded, or
        // admin explicitly deactivated all announcements).
        if (_activeTitle == null) return const SizedBox.shrink();

        return _AnnouncementMarquee(
          text: _activeTitle!,
          onTap: (_activeUrl != null && _activeUrl!.isNotEmpty)
              ? () async {
                  final uri = Uri.tryParse(_activeUrl!);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              : null,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Internal marquee widget — no external package required
// ---------------------------------------------------------------------------
class _AnnouncementMarquee extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;

  const _AnnouncementMarquee({required this.text, this.onTap});

  @override
  State<_AnnouncementMarquee> createState() => _AnnouncementMarqueeState();
}

class _AnnouncementMarqueeState extends State<_AnnouncementMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _textWidth = 0;
  bool _started = false;

  static const _textStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: Color(0xFF4A3000),
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
  }

  void _startAnimation() {
    if (!mounted) return;

    // Measure text width using TextPainter
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: _textStyle),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    _textWidth = tp.width;

    final screenWidth = MediaQuery.of(context).size.width;
    // total pixels the text travels: enters from right edge, exits at left edge
    const double pixelsPerSecond = 70.0;
    final totalDistance = screenWidth + _textWidth;
    final duration = Duration(
      milliseconds: (totalDistance / pixelsPerSecond * 1000).round(),
    );

    _controller.duration = duration;
    _controller.repeat();
    if (mounted) setState(() => _started = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        color: const Color(0xFFFFF9C4), // light yellow
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ClipRect(
          child: _started
              ? AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    // Slide from screenWidth (off-screen right) to -_textWidth (off-screen left)
                    final dx = screenWidth -
                        _controller.value * (screenWidth + _textWidth);
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: child,
                    );
                  },
                  child: Text(
                    widget.text,
                    style: _textStyle,
                    maxLines: 1,
                    softWrap: false,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
