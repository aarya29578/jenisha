import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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
                                              app.serviceName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                                color: Theme.of(context)
                                                        .extension<
                                                            CustomColors>()
                                                        ?.textPrimary ??
                                                    const Color(0xFF333333),
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
                            // View certificate button for approved applications with certificate
                            if (app.status.toLowerCase() == 'approved' &&
                                app.certificateUrl != null &&
                                app.certificateUrl!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _viewCertificateInApp(
                                        app.certificateUrl!, app.serviceName),
                                    icon: const Icon(Icons.remove_red_eye,
                                        size: 18),
                                    label: Text(AppLocalizations.of(context)
                                        .get('view_certificate')),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context)
                                              .extension<CustomColors>()
                                              ?.success ??
                                          const Color(0xFF4CAF50),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
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
    setState(() {
      _isDownloading = true;
    });

    try {
      // Request storage permission for Android
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)
                      .get('storage_permission_required')),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }
      }

      // Download the image
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download certificate');
      }

      // Get the appropriate directory
      Directory? directory;
      if (Platform.isAndroid) {
        // Use Downloads directory for Android
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        // Use documents directory for iOS
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access storage');
      }

      // Create filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = widget.imageUrl.split('.').last.split('?').first;
      final filename =
          'certificate_${widget.serviceName.replaceAll(' ', '_')}_$timestamp.$extension';
      final filePath = '${directory.path}/$filename';

      // Save the file
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${AppLocalizations.of(context).get('certificate_downloaded')}\n${AppLocalizations.of(context).get('saved_to')}: ${directory.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
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
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: Center(
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
                      AppLocalizations.of(context).get('failed_to_load_cert'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
