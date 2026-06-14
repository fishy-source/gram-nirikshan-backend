import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';

class PdfPreviewScreen extends StatefulWidget {
  final String inspectionId;
  final String title;
  final String format;

  const PdfPreviewScreen({
    super.key,
    required this.inspectionId,
    required this.title,
    this.format = 'pdf_en',
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  String? _localPath;
  bool _loading = true;
  String? _error;
  int _totalPages = 0;
  int _currentPage = 0;
  bool _pdfReady = false;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final downloadUrl = await ApiService().getReportDownloadUrl(widget.inspectionId, format: widget.format);
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/Report_${widget.inspectionId}.pdf';

      final dio = Dio();
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: AppConstants.accessTokenKey);

      try {
        await dio.download(
          downloadUrl,
          savePath,
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      } on DioException catch (de) {
        if (de.response?.statusCode == 404) {
          // Trigger generation first if not found
          await ApiService().generateReport(widget.inspectionId);
          // Retry download
          await dio.download(
            downloadUrl,
            savePath,
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
        } else {
          rethrow;
        }
      }

      setState(() {
        _localPath = savePath;
        _loading = false;
      });
    } catch (e) {
      String errorMessage = e.toString();
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('detail')) {
          errorMessage = data['detail'].toString();
        } else if (data is Map && data.containsKey('message')) {
          errorMessage = data['message'].toString();
        } else if (data is String) {
          errorMessage = data;
        }
      }
      setState(() {
        _error = errorMessage;
        _loading = false;
      });
    }
  }

  Future<void> _shareNatively(String type) async {
    if (_localPath == null) return;
    final isHindi = context.read<LanguageProvider>().isHindi;
    final shareSubject = isHindi ? 'निरीक्षण रिपोर्ट' : 'Inspection Report';
    final shareBody = isHindi 
        ? 'ग्राम निरीक्षण रिपोर्ट: ${widget.title}\nID: ${widget.inspectionId}' 
        : 'Gram Inspection Report: ${widget.title}\nID: ${widget.inspectionId}';

    try {
      // Native Share Sheet
      await Share.shareXFiles(
        [XFile(_localPath!)],
        text: shareBody,
        subject: shareSubject,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _saveLocally() async {
    if (_localPath == null) return;
    final isHindi = context.read<LanguageProvider>().isHindi;

    try {
      // Find suitable directory (Downloads or Documents)
      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      if (dir == null) {
        throw Exception(isHindi ? 'भंडारण निर्देशिका नहीं मिली' : 'Storage directory not found');
      }

      final fileName = 'Report_${widget.inspectionId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final newFile = File('${dir.path}/$fileName');
      
      await File(_localPath!).copy(newFile.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHindi 
                ? 'रिपोर्ट सफलतापूर्वक सेव की गई: ${newFile.path}' 
                : 'Report saved successfully: ${newFile.path}'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHindi ? 'सेव करने में विफल: $e' : 'Failed to save: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = context.watch<LanguageProvider>().isHindi;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(isHindi ? 'रिपोर्ट पूर्वावलोकन' : 'Report Preview', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_localPath != null)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: _saveLocally,
              tooltip: isHindi ? 'डाउनलोड करें' : 'Download PDF',
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(isHindi ? 'रिपोर्ट लोड हो रही है...' : 'Loading report...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _downloadPdf,
                          icon: const Icon(Icons.refresh),
                          label: Text(isHindi ? 'पुनः प्रयास करें' : 'Try Again'),
                        )
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    PDFView(
                      filePath: _localPath,
                      enableSwipe: true,
                      swipeHorizontal: false,
                      autoSpacing: true,
                      pageFling: true,
                      onRender: (pages) {
                        setState(() {
                          _totalPages = pages ?? 0;
                          _pdfReady = true;
                        });
                      },
                      onError: (error) {
                        setState(() {
                          _error = error.toString();
                        });
                      },
                      onPageError: (page, error) {
                        setState(() {
                          _error = error.toString();
                        });
                      },
                      onPageChanged: (page, total) {
                        setState(() {
                          _currentPage = page ?? 0;
                        });
                      },
                    ),
                    if (!_pdfReady)
                      const Center(child: CircularProgressIndicator()),
                    if (_pdfReady && _totalPages > 0)
                      Positioned(
                        bottom: 90,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_currentPage + 1} / $_totalPages',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
      bottomNavigationBar: _localPath == null
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // WhatsApp Share
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _shareNatively('whatsapp'),
                        icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                        label: Text(
                          isHindi ? 'व्हाट्सएप / शेयर' : 'WhatsApp / Share',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Email Share
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _shareNatively('email'),
                        icon: const Icon(Icons.email_rounded, color: Colors.white, size: 18),
                        label: Text(
                          isHindi ? 'ईमेल द्वारा शेयर' : 'Email / Share',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Close / History
                    IconButton(
                      icon: const Icon(Icons.history, color: AppTheme.secondaryColor),
                      onPressed: () {
                        // Go back to details or inspection list
                        Navigator.pop(context);
                      },
                      tooltip: isHindi ? 'निरीक्षण विवरण देखें' : 'View Details',
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
