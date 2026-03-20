import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../utils/firestore_helper.dart';
import '../providers/language_provider.dart';
import '../theme/app_theme.dart';

class _Application {
  final String id;
  final String serviceName;
  final String customerName;
  final String date;
  final String status;
  final String? certificateUrl;
  final String? phone;
  const _Application(this.id, this.serviceName, this.customerName, this.date,
      this.status, this.certificateUrl, this.phone);
}

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({Key? key}) : super(key: key);

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _searchController = TextEditingController();
  String _filterStatus = 'all'; // all, pending, approved, rejected, in-progress
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _downloadCertificate(
      BuildContext ctx, String certUrl, String serviceName) async {
    try {
      final encodedUrl = Uri.encodeFull(certUrl);
      print('📥 CERT URL: $encodedUrl');

      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Downloading…'),
          duration: Duration(seconds: 2),
        ),
      );

      // Try public Downloads folder; fall back to app external dir (always writable)
      Directory? dir;
      try {
        final downloads = Directory('/storage/emulated/0/Download');
        if (!downloads.existsSync()) downloads.createSync(recursive: true);
        final probe = File('${downloads.path}/.writable_test');
        probe.writeAsBytesSync([]);
        probe.deleteSync();
        dir = downloads;
      } catch (_) {
        dir = await getExternalStorageDirectory();
      }
      dir ??= await getApplicationDocumentsDirectory();

      final ext = certUrl.split('.').last.split('?').first.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename =
          'certificate_${serviceName.replaceAll(' ', '_')}_$timestamp.$ext';
      final filePath = '${dir.path}/$filename';
      print('💾 Saving to: $filePath');

      await Dio().download(
        encodedUrl,
        filePath,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );

      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
              '${AppLocalizations.of(ctx).get('certificate_downloaded')}\nSaved to: $filePath'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );

      // Also register in the downloads list so the profile Downloads screen shows it
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('downloaded_certificates') ?? [];
      final entry = json.encode({
        'url': certUrl,
        'serviceName': serviceName,
        'downloadedAt':
            DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
      });
      if (!list.contains(entry)) {
        list.add(entry);
        await prefs.setStringList('downloaded_certificates', list);
      }
    } catch (e) {
      print('❌ Error downloading certificate: $e');
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content:
              Text('${AppLocalizations.of(ctx).get('failed_to_download')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _viewCertificateInApp(
      String certificateUrl, String serviceName) async {
    try {
      // Save to downloaded certificates
      final prefs = await SharedPreferences.getInstance();
      final certificatesJson =
          prefs.getStringList('downloaded_certificates') ?? [];

      // Add new certificate
      final newCert = json.encode({
        'url': certificateUrl,
        'serviceName': serviceName,
        'downloadedAt':
            DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
      });

      // Avoid duplicates
      if (!certificatesJson.contains(newCert)) {
        certificatesJson.add(newCert);
        await prefs.setStringList('downloaded_certificates', certificatesJson);
      }

      // Open certificate in full-screen viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _CertificateViewerScreen(
            imageUrl: certificateUrl,
            serviceName: serviceName,
          ),
        ),
      );
    } catch (e) {
      print('❌ Error viewing certificate: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).get('failed_to_open')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }

  Stream<List<_Application>> _getApplicationsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('serviceApplications')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .asyncMap((snapshot) async {
      // Sort in memory to avoid needing a Firestore index
      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final aTime = a.data()['createdAt'] as Timestamp?;
        final bTime = b.data()['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // Descending order (newest first)
      });

      final applications = <_Application>[];

      for (final doc in docs) {
        final data = doc.data();

        // Get current language for localized fields
        final languageCode =
            Provider.of<LanguageProvider>(context, listen: false).languageCode;

        String serviceName = data['serviceName'] ?? '';
        final serviceId = data['serviceId'] as String?;

        // Always fetch localized name from services collection when:
        // 1. In Marathi mode (stored name may be in English from submission time)
        // 2. Or stored serviceName is empty
        if ((languageCode == 'mr' || serviceName.isEmpty) &&
            serviceId != null &&
            serviceId.isNotEmpty) {
          try {
            final serviceDoc =
                await _firestore.collection('services').doc(serviceId).get();
            if (serviceDoc.exists) {
              final localizedName =
                  serviceDoc.getLocalized('name', languageCode);
              if (localizedName.isNotEmpty) {
                serviceName = localizedName;
              } else if (serviceName.isEmpty) {
                // Fall back to English name from Firestore
                serviceName = serviceDoc.getLocalized('name', 'en');
              }
            }
          } catch (e) {
            debugPrint('Error fetching service name: $e');
          }
        }

        if (serviceName.isEmpty) {
          final localizations = AppLocalizations.of(context);
          serviceName = localizations.get('unknown_service');
        }

        applications.add(_Application(
          doc.id,
          serviceName,
          data['fullName'] ?? 'Unknown Customer',
          _formatDate(data['createdAt'] as Timestamp?),
          data['status'] ?? 'pending',
          data['certificateUrl'] as String?,
          data['phone'] as String?,
        ));
      }

      return applications;
    });
  }

  Color _statusBgColor(String s) {
    final status = s.toLowerCase();
    final customColors = Theme.of(context).extension<CustomColors>();
    switch (status) {
      case 'generated':
      case 'approved':
        return customColors?.success ?? const Color(0xFF4CAF50);
      case 'pending':
        return customColors?.warning ?? const Color(0xFFFF9800);
      case 'in-progress':
      case 'in progress':
        return Theme.of(context).primaryColor;
      case 'rejected':
        return Theme.of(context).colorScheme.error;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _statusTextColor(String s) {
    final status = s.toLowerCase();
    switch (status) {
      case 'generated':
      case 'approved':
      case 'pending':
      case 'in-progress':
      case 'in progress':
      case 'rejected':
        return Colors.white;
      default:
        return Colors.black87;
    }
  }

  IconData _statusIcon(String s) {
    final status = s.toLowerCase();
    switch (status) {
      case 'generated':
      case 'approved':
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'in-progress':
      case 'in progress':
        return Icons.sync;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _formatStatus(String s, BuildContext context) {
    final localizations = AppLocalizations.of(context);
    // Try to translate using localization keys first
    final key = s.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    final translated = localizations.get(key);
    // If translation key exists, use it; otherwise translate the raw text
    if (translated != key || translated != s) {
      return translated;
    }
    // Fallback: translate the formatted status text
    final formatted = s[0].toUpperCase() + s.substring(1).toLowerCase();
    return localizations.translateText(formatted);
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = selected ? value : 'all';
        });
      },
      backgroundColor: Colors.white,
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.15),
      labelStyle: TextStyle(
        color:
            isSelected ? Theme.of(context).primaryColor : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      checkmarkColor: Theme.of(context).primaryColor,
      side: BorderSide(
        color:
            isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        title: Text(
          localizations.get('my_applications'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.get('submitted_applications'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            // Filter Buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(localizations.get('all'), 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip(localizations.get('pending'), 'pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                      localizations.get('in_progress'), 'in-progress'),
                  const SizedBox(width: 8),
                  _buildFilterChip(localizations.get('approved'), 'approved'),
                  const SizedBox(width: 8),
                  _buildFilterChip(localizations.get('rejected'), 'rejected'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: localizations.get('search_by_service_phone'),
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<_Application>>(
                stream: _getApplicationsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            localizations.get('error_loading_applications'),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final applications = snapshot.data ?? [];

                  // Apply status filter
                  var filteredApplications = _filterStatus == 'all'
                      ? applications
                      : applications
                          .where((app) =>
                              app.status.toLowerCase() == _filterStatus)
                          .toList();

                  // Apply search filter (sub-category and phone number search)
                  if (_searchQuery.isNotEmpty) {
                    filteredApplications = filteredApplications.where((app) {
                      final matchesServiceName =
                          app.serviceName.toLowerCase().contains(_searchQuery);
                      final matchesPhone = app.phone != null &&
                          app.phone!.contains(_searchQuery);
                      return matchesServiceName || matchesPhone;
                    }).toList();
                  }

                  if (filteredApplications.isEmpty) {
                    // Determine empty state message
                    String emptyMessage;
                    String emptySubMessage;
                    if (_searchQuery.isNotEmpty) {
                      emptyMessage = localizations.get('no_applications_found');
                      emptySubMessage =
                          '${localizations.get('no_results_for')} "$_searchQuery"';
                    } else if (_filterStatus != 'all') {
                      emptyMessage =
                          '${localizations.get('no')} ${localizations.get(_filterStatus)} ${localizations.get('my_applications').toLowerCase()}';
                      emptySubMessage =
                          localizations.get('no_applications_with_status');
                    } else {
                      emptyMessage = localizations.get('no_applications_yet');
                      emptySubMessage =
                          localizations.get('applications_will_appear');
                    }

                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty
                                ? Icons.search_off
                                : Icons.inbox_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            emptyMessage,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            emptySubMessage,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_searchQuery.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: () {
                                _searchController.clear();
                              },
                              icon: const Icon(Icons.clear),
                              label: Text(AppLocalizations.of(context)
                                  .get('clear_search')),
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredApplications.length,
                    itemBuilder: (context, i) {
                      final app = filteredApplications[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.07),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .primaryColor
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Icon(
                                          Icons.description,
                                          color: Theme.of(context).primaryColor,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              app.serviceName.toUpperCase(),
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: const Color(0xFF1A1A1A),
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              app.customerName,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                        .extension<
                                                            CustomColors>()
                                                        ?.textTertiary ??
                                                    Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              app.date,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: _statusBgColor(app.status),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _statusIcon(app.status),
                                        size: 14,
                                        color: _statusTextColor(app.status),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatStatus(app.status, context),
                                        style: TextStyle(
                                          color: _statusTextColor(app.status),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Certificate buttons — shown whenever a certificate URL exists
                            if (app.certificateUrl != null &&
                                app.certificateUrl!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              const Divider(height: 1, thickness: 1),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _viewCertificateInApp(
                                          app.certificateUrl!, app.serviceName),
                                      icon: const Icon(Icons.remove_red_eye,
                                          size: 16),
                                      label: Text(AppLocalizations.of(context)
                                          .get('view_certificate')),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            Theme.of(context).primaryColor,
                                        side: BorderSide(
                                            color:
                                                Theme.of(context).primaryColor),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _downloadCertificate(
                                          context,
                                          app.certificateUrl!,
                                          app.serviceName),
                                      icon:
                                          const Icon(Icons.download, size: 16),
                                      label: const Text(
                                        'Download',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context)
                                                .extension<CustomColors>()
                                                ?.success ??
                                            const Color(0xFF4CAF50),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Full-screen certificate viewer
class _CertificateViewerScreen extends StatefulWidget {
  final String imageUrl;
  final String serviceName;

  const _CertificateViewerScreen({
    required this.imageUrl,
    required this.serviceName,
  });

  @override
  State<_CertificateViewerScreen> createState() =>
      _CertificateViewerScreenState();
}

class _CertificateViewerScreenState extends State<_CertificateViewerScreen> {
  bool _isDownloading = false;

  Future<void> _downloadCertificate() async {
    setState(() => _isDownloading = true);

    try {
      final encodedUrl = Uri.encodeFull(widget.imageUrl);
      print('📥 CERT URL: $encodedUrl');

      // Determine save directory — try public Downloads first,
      // fall back to app-specific external dir (always writable on all API levels)
      Directory? dir;
      try {
        final downloads = Directory('/storage/emulated/0/Download');
        if (!downloads.existsSync()) {
          downloads.createSync(recursive: true);
        }
        // Verify writable with a probe write
        final probe = File('${downloads.path}/.writable_test');
        probe.writeAsBytesSync([]);
        probe.deleteSync();
        dir = downloads;
      } catch (_) {
        dir = await getExternalStorageDirectory();
      }
      dir ??= await getApplicationDocumentsDirectory();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension =
          widget.imageUrl.split('.').last.split('?').first.toLowerCase();
      final filename =
          'certificate_${widget.serviceName.replaceAll(' ', '_')}_$timestamp.$extension';
      final filePath = '${dir.path}/$filename';
      print('💾 Saving to: $filePath');

      await Dio().download(
        encodedUrl,
        filePath,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${AppLocalizations.of(context).get('certificate_downloaded')}\nSaved to: $filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // Also register in the downloads list so the profile Downloads screen shows it
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('downloaded_certificates') ?? [];
      final entry = json.encode({
        'url': widget.imageUrl,
        'serviceName': widget.serviceName,
        'downloadedAt':
            DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
      });
      if (!list.contains(entry)) {
        list.add(entry);
        await prefs.setStringList('downloaded_certificates', list);
      }
    } catch (e) {
      print('❌ Error downloading certificate: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${AppLocalizations.of(context).get('failed_to_download')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.imageUrl.split('.').last.split('?').first.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
    final isPdf = ext == 'pdf';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.serviceName,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download, color: Colors.white),
            onPressed: _isDownloading ? null : _downloadCertificate,
            tooltip: AppLocalizations.of(context).get('download_certificate'),
          ),
        ],
      ),
      body: isImage
          ? Center(
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)
                                .get('failed_to_load_cert'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            )
          : isPdf
              ? _PdfChromeTabView(url: widget.imageUrl)
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.insert_drive_file,
                            color: Colors.white, size: 80),
                        const SizedBox(height: 20),
                        Text(
                          widget.serviceName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${ext.toUpperCase()} Document',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Preview not available.\nUse the Download button above.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

// Opens a PDF URL in a Chrome Custom Tab (in-app experience, renders PDF).
class _PdfChromeTabView extends StatefulWidget {
  final String url;
  const _PdfChromeTabView({required this.url});

  @override
  State<_PdfChromeTabView> createState() => _PdfChromeTabViewState();
}

class _PdfChromeTabViewState extends State<_PdfChromeTabView> {
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    // Auto-open as soon as the screen is shown
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (_launching) return;
    setState(() => _launching = true);
    try {
      final uri = Uri.parse(Uri.encodeFull(widget.url));
      print('📄 Opening PDF: $uri');
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open PDF. No compatible app found.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.white, size: 80),
            const SizedBox(height: 24),
            const Text(
              'Opening PDF viewer…',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (_launching)
              const CircularProgressIndicator(color: Colors.white)
            else
              ElevatedButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4C4CFF),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
