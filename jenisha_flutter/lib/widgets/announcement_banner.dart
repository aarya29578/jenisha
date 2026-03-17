import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:marquee/marquee.dart';

class AnnouncementBanner extends StatelessWidget {
  const AnnouncementBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('announcements')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // ignore: avoid_print
          print('⚠️ AnnouncementBanner Firestore error: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        final docs = snapshot.data?.docs ?? [];

        // ignore: avoid_print
        print('FINAL DOC COUNT: ${docs.length}');

        // Sort newest-first in memory (no composite index needed).
        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final aTs = (a.data() as Map<String, dynamic>)['createdAt'];
          final bTs = (b.data() as Map<String, dynamic>)['createdAt'];
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          try {
            return (bTs as dynamic).compareTo(aTs as dynamic) as int;
          } catch (_) {
            return 0;
          }
        });

        // Collect ALL titles — no limit, no docs.first, no docs[0].
        List<String> titles = sortedDocs
            .map((e) => ((e.data() as Map<String, dynamic>)['title'] ?? '')
                .toString()
                .trim())
            .where((e) => e.isNotEmpty)
            .toList();

        // ignore: avoid_print
        print('TITLES: $titles');

        if (titles.isEmpty) return const SizedBox.shrink();

        // Combine all announcements into one scrolling string.
        // Duplicate for seamless continuous looping with multiple items.
        String combinedText = titles.join('   •   ');
        if (titles.length > 1) {
          combinedText = combinedText + '   •   ' + combinedText;
        }

        // First non-empty URL is the tap target for the whole bar.
        final tapUrl = sortedDocs
            .map((d) =>
                ((d.data() as Map<String, dynamic>)['url'] as String? ?? '')
                    .trim())
            .firstWhere((u) => u.isNotEmpty, orElse: () => '');

        return GestureDetector(
          onTap: tapUrl.isNotEmpty
              ? () async {
                  final uri = Uri.tryParse(tapUrl);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              : null,
          child: Container(
            height: 40,
            width: double.infinity,
            color: const Color(0xFFFFF9C4), // light yellow
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const Icon(Icons.campaign, color: Color(0xFF4A3000), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Marquee(
                    text: combinedText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A3000),
                    ),
                    // Multiple items scroll faster; single item is slower
                    velocity: titles.length == 1 ? 30.0 : 50.0,
                    // Minimal gap between loops for multiple; wider for single
                    blankSpace: titles.length == 1 ? 50.0 : 10.0,
                    // Pause only for a single announcement
                    pauseAfterRound: titles.length == 1
                        ? const Duration(seconds: 2)
                        : Duration.zero,
                    startPadding: 10.0,
                    accelerationDuration: const Duration(milliseconds: 500),
                    decelerationDuration: const Duration(milliseconds: 500),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
