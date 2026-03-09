import 'package:flutter/material.dart';
import 'dart:async';
import 'package:collection/collection.dart';
import 'package:url_launcher/url_launcher.dart';

class BannerSlider extends StatefulWidget {
  final List<Map<String, dynamic>> banners;
  final double height;

  const BannerSlider({
    Key? key,
    required this.banners,
    this.height = 180,
  }) : super(key: key);

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;
  bool _userInteracting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(covariant BannerSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If banner list changed, reset page controller and restart timer
    if (oldWidget.banners.length != widget.banners.length ||
        (oldWidget.banners.isNotEmpty &&
            widget.banners.isNotEmpty &&
            !ListEquality().equals(oldWidget.banners, widget.banners))) {
      // Reset current page to 0 if out of range
      if (_currentPage >= widget.banners.length) {
        _currentPage = 0;
      }
      _pageController.dispose();
      _pageController = PageController(initialPage: _currentPage);
      _startAutoScroll();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!_userInteracting && mounted) {
        final nextPage = (_currentPage + 1) % widget.banners.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page % widget.banners.length;
    });
  }

  Future<void> _handleBannerTap(Map<String, dynamic> banner) async {
    final linkUrl = banner['linkUrl'] as String?;
    
    debugPrint('🔗 Banner tapped!');
    debugPrint('   linkUrl: $linkUrl');
    
    if (linkUrl == null || linkUrl.isEmpty) {
      debugPrint('   ⚠️ No link URL provided, nothing to open');
      return;
    }

    // Validate URL format
    if (!linkUrl.startsWith('http://') && !linkUrl.startsWith('https://')) {
      debugPrint('   ❌ Invalid URL format: $linkUrl');
      return;
    }

    try {
      final url = Uri.parse(linkUrl);
      debugPrint('   📱 Attempting to launch: $url');
      
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        debugPrint('   ✅ URL launched successfully');
      } else {
        debugPrint('   ❌ Cannot launch URL: $url');
      }
    } catch (e) {
      debugPrint('   ❌ Error launching URL: $e');
    }
  }

  void _onUserInteractionStart() {
    setState(() {
      _userInteracting = true;
    });
  }

  void _onUserInteractionEnd() {
    setState(() {
      _userInteracting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: widget.height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        children: [
          // PageView with banners
          GestureDetector(
            onPanDown: (_) => _onUserInteractionStart(),
            onPanEnd: (_) => _onUserInteractionEnd(),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: widget.banners.length * 1000, // Infinite scroll
              itemBuilder: (context, index) {
                final banner = widget.banners[index % widget.banners.length];
                final imageUrl = banner['imageUrl'] as String? ?? '';
                return GestureDetector(
                  onTap: () => _handleBannerTap(banner),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildBannerImage(imageUrl),
                    ),
                  ),
                );
              },
            ),
          ),

          // Page indicator dots
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.banners.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerImage(String imageUrl) {
    // Check if it's a local asset or network URL
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder();
        },
      );
    } else {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder();
        },
      );
    }
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.image_not_supported,
          size: 48,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}
