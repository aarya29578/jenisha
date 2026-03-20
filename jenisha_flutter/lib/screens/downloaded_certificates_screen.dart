import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';

class DownloadedCertificatesScreen extends StatefulWidget {
  const DownloadedCertificatesScreen({Key? key}) : super(key: key);

  @override
  _DownloadedCertificatesScreenState createState() =>
      _DownloadedCertificatesScreenState();
}

class _DownloadedCertificatesScreenState
    extends State<DownloadedCertificatesScreen> with RouteAware {
  List<Map<String, dynamic>> _downloadedCertificates = [];
  bool _isLoading = true;
  static final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  @override
  void initState() {
    super.initState();
    _loadDownloadedCertificates();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes so didPopNext / didPush fire
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Called when the user navigates back TO this screen
  @override
  void didPopNext() {
    _loadDownloadedCertificates();
  }

  /// Called when this screen is pushed (tab switch back into view)
  @override
  void didPush() {
    _loadDownloadedCertificates();
  }

  Future<void> _loadDownloadedCertificates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final certificatesJson =
          prefs.getStringList('downloaded_certificates') ?? [];

      setState(() {
        _downloadedCertificates = certificatesJson
            .map((jsonStr) => json.decode(jsonStr) as Map<String, dynamic>)
            .toList()
            .reversed
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading downloaded certificates: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openCertificate(String url, String serviceName) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _CertificateViewerScreen(
          imageUrl: url,
          serviceName: serviceName,
        ),
      ),
    );
  }

  Future<void> _deleteCertificate(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).get('delete_certificate')),
        content: Text(
            AppLocalizations.of(context).get('delete_certificate_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context).get('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context).get('delete')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _downloadedCertificates.removeAt(index);

        final certificatesJson =
            _downloadedCertificates.map((cert) => json.encode(cert)).toList();

        await prefs.setStringList('downloaded_certificates', certificatesJson);

        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppLocalizations.of(context).get('certificate_deleted'))),
        );
      } catch (e) {
        print('❌ Error deleting certificate: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)
                  .get('failed_to_delete_certificate'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          localizations.get('downloaded_certificates'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _downloadedCertificates.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        localizations.get('no_downloaded_certificates'),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizations.get('certificates_will_appear'),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDownloadedCertificates,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _downloadedCertificates.length,
                    itemBuilder: (context, index) {
                      final cert = _downloadedCertificates[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () => _openCertificate(cert['url'],
                              cert['serviceName'] ?? 'Certificate'),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.verified,
                                    color: Theme.of(context).primaryColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cert['serviceName'] ?? 'Certificate',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF333333),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        cert['downloadedAt'] ?? '',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  onPressed: () => _deleteCertificate(index),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// Full-screen certificate viewer — handles images and PDFs
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
  bool _launching = false;

  String get _ext =>
      widget.imageUrl.split('.').last.split('?').first.toLowerCase();

  bool get _isImage => ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(_ext);

  Future<void> _openWithLauncher() async {
    setState(() => _launching = true);
    try {
      final uri = Uri.parse(Uri.encodeFull(widget.imageUrl));
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (!_isImage) {
      // Auto-open PDFs/DOCs as soon as the screen appears
      WidgetsBinding.instance.addPostFrameCallback((_) => _openWithLauncher());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.serviceName,
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isImage
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
                                .get('failed_to_load_certificate'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _ext == 'pdf'
                          ? Icons.picture_as_pdf
                          : Icons.insert_drive_file,
                      color: Colors.white,
                      size: 80,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.serviceName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Opening document viewer…',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    if (_launching)
                      const CircularProgressIndicator(color: Colors.white)
                    else
                      ElevatedButton.icon(
                        onPressed: _openWithLauncher,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4C4CFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
