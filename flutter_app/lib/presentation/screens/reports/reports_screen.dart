import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../providers/inspection_provider.dart';
import '../../providers/language_provider.dart';
import '../../../data/models/models.dart';
import '../../../core/services/pdf_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final Map<String, bool> _generatingMap = {};
  final Map<String, double> _downloadProgressMap = {};
  final Map<String, bool> _downloadingMap = {};
  final Map<String, bool> _downloadingDocxMap = {};
  final Map<String, double> _downloadDocxProgressMap = {};


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InspectionProvider>().loadInspections(refresh: true);
    });
  }

  Future<void> _generateReport(String inspectionId) async {
    setState(() => _generatingMap[inspectionId] = true);
    try {
      final response = await ApiService().generateReport(inspectionId);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('pdf_generated_success')), backgroundColor: AppTheme.successColor),
          );
        }
        // Refresh inspections list to update status
        if (mounted) {
          context.read<InspectionProvider>().loadInspections(refresh: true);
        }
      }
    } catch (e) {
      if (mounted) {
        final isHindi = context.read<LanguageProvider>().isHindi;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHindi ? 'रिपोर्ट बनाने में विफल: $errorMessage' : 'Failed to generate report: $errorMessage'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() => _generatingMap[inspectionId] = false);
    }
  }

  Future<void> _downloadAndViewReport(String inspectionId, String title, String format) async {
    setState(() {
      _downloadingMap[inspectionId] = true;
    });

    try {
      // Find the inspection locally
      final inspection = context.read<InspectionProvider>().inspections.firstWhere(
        (i) => i.id == inspectionId,
        orElse: () => throw Exception('Inspection not found'),
      );

      // Fetch photos if any
      final photosResponse = await ApiService().getPhotos(inspectionId);
      final List<PhotoModel> photos = [];
      if (photosResponse.statusCode == 200) {
        final List<dynamic> data = photosResponse.data;
        photos.addAll(data.map((p) => PhotoModel.fromJson(p)).toList());
      }

      final isHindi = format == 'pdf_hi';

      // Generate PDF locally and save
      final savePath = await PdfService.generateInspectionReport(inspection, photos, isHindi: isHindi);

      setState(() => _downloadingMap[inspectionId] = false);

      // Open the generated PDF
      final result = await OpenFile.open(savePath);
      if (result.type != ResultType.done && mounted) {
        final isHindi = context.read<LanguageProvider>().isHindi;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHindi ? 'फ़ाइल खोलने में असमर्थ: ${result.message}' : 'Unable to open file: ${result.message}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloadingMap[inspectionId] = false);
        final isHindi = context.read<LanguageProvider>().isHindi;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHindi ? 'PDF रिपोर्ट बनाने में विफल: $e' : 'Failed to generate PDF report: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }



  Future<void> _shareReportFile(String inspectionId, String title, String format) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(context.tr('preparing_report_share'))),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final downloadUrl = await ApiService().getReportDownloadUrl(inspectionId, format: format);
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/Report_${format}_$inspectionId.pdf';

      // Download file using Dio
      final dio = Dio();
      final flutterSecureStorage = const FlutterSecureStorage();
      final tokenValue = await flutterSecureStorage.read(key: AppConstants.accessTokenKey);

      try {
        await dio.download(
          downloadUrl,
          savePath,
          options: Options(headers: {'Authorization': 'Bearer $tokenValue'}),
        );
      } on DioException catch (de) {
        if (de.response?.statusCode == 404) {
          // Report not found, auto-generate first!
          await ApiService().generateReport(inspectionId);
          // Retry downloading after successful generation
          await dio.download(
            downloadUrl,
            savePath,
            options: Options(headers: {'Authorization': 'Bearer $tokenValue'}),
          );
        } else {
          rethrow;
        }
      }

      // Share the downloaded actual PDF file
      final isHindi = context.read<LanguageProvider>().isHindi;
      final shareText = isHindi ? 'ग्राम निरीक्षण रिपोर्ट: $title' : 'Gram Inspection Report: $title';
      await Share.shareXFiles(
        [XFile(savePath)],
        text: shareText,
      );
    } catch (e) {
      if (mounted) {
        final isHindi = context.read<LanguageProvider>().isHindi;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHindi ? 'शेयर करने में त्रुटि: $e' : 'Error sharing: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _downloadAndViewDocxReport(String inspectionId, String title) async {
    setState(() {
      _downloadingDocxMap[inspectionId] = true;
    });

    try {
      final inspection = context.read<InspectionProvider>().inspections.firstWhere(
        (i) => i.id == inspectionId,
        orElse: () => throw Exception('Inspection not found'),
      );

      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/Report_$inspectionId.doc';

      // Generate HTML content disguised as DOC
      final htmlContent = '''
        <html>
        <head><meta charset="utf-8"></head>
        <body>
          <h1 style="text-align:center; color: #1E88E5;">Inspection Report</h1>
          <hr>
          <h3>Metadata</h3>
          <table border="1" cellpadding="5" cellspacing="0" style="width:100%; border-collapse: collapse;">
            <tr><td><b>Inspection ID</b></td><td>${inspection.inspectionId}</td></tr>
            <tr><td><b>Project Name</b></td><td>${inspection.projectName ?? 'N/A'}</td></tr>
            <tr><td><b>Investigator</b></td><td>${inspection.investigatorName ?? 'N/A'}</td></tr>
            <tr><td><b>Status</b></td><td>${inspection.status.toUpperCase()}</td></tr>
          </table>
          <br>
          <h3>Observations & Conclusions</h3>
          <p>${inspection.aiReportDraft ?? inspection.observations ?? 'Inspection conducted.'}</p>
        </body>
        </html>
      ''';

      final file = File(savePath);
      await file.writeAsString(htmlContent);

      setState(() => _downloadingDocxMap[inspectionId] = false);

      final result = await OpenFile.open(savePath);
      if (result.type != ResultType.done && mounted) {
        final isHindi = context.read<LanguageProvider>().isHindi;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHindi ? 'फ़ाइल खोलने में असमर्थ: ${result.message}' : 'Unable to open file: ${result.message}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _downloadingDocxMap[inspectionId] = false);
      if (mounted) {
        final isHindi = context.read<LanguageProvider>().isHindi;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHindi ? 'DOCX रिपोर्ट बनाने में विफल: $e' : 'Failed to generate DOCX report: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _shareDocxReportFile(String inspectionId, String title) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(context.tr('sharing_docx'))),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final downloadUrl = await ApiService().getReportDownloadUrl(inspectionId, format: 'docx');
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/Report_$inspectionId.docx';

      // Download file using Dio
      final dio = Dio();
      final flutterSecureStorage = const FlutterSecureStorage();
      final tokenValue = await flutterSecureStorage.read(key: AppConstants.accessTokenKey);

      try {
        await dio.download(
          downloadUrl,
          savePath,
          options: Options(headers: {'Authorization': 'Bearer $tokenValue'}),
        );
      } on DioException catch (de) {
        if (de.response?.statusCode == 404) {
          // Report not found, auto-generate first!
          await ApiService().generateReport(inspectionId);
          // Retry downloading after successful generation
          await dio.download(
            downloadUrl,
            savePath,
            options: Options(headers: {'Authorization': 'Bearer $tokenValue'}),
          );
        } else {
          rethrow;
        }
      }

      // Share the downloaded actual DOCX file
      final isHindi = context.read<LanguageProvider>().isHindi;
      final shareText = isHindi ? 'ग्राम निरीक्षण Word रिपोर्ट: $title' : 'Gram Inspection Word Report: $title';
      await Share.shareXFiles(
        [XFile(savePath)],
        text: shareText,
      );
    } catch (e) {
      if (mounted) {
        final isHindi = context.read<LanguageProvider>().isHindi;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHindi ? 'शेयर करने में त्रुटि: $e' : 'Error sharing: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inspections = context.watch<InspectionProvider>().inspections;
    final isLoading = context.watch<InspectionProvider>().isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(context.tr('view_inspection_reports'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<InspectionProvider>().loadInspections(refresh: true),
        child: isLoading && inspections.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : inspections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.description_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(context.tr('no_inspections_available'), style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: inspections.length,
                    itemBuilder: (context, index) {
                      final ins = inspections[index];
                      final isGenerating = _generatingMap[ins.id] ?? false;
                      final isDownloading = _downloadingMap[ins.id] ?? false;
                      final progress = _downloadProgressMap[ins.id] ?? 0.0;
                      final isDownloadingDocx = _downloadingDocxMap[ins.id] ?? false;
                      final progressDocx = _downloadDocxProgressMap[ins.id] ?? 0.0;


                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    ins.inspectionId,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      ins.inspectionType ?? 'General',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                ins.title,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.read<LanguageProvider>().isHindi 
                                    ? 'ग्राम पंचायत: ${ins.panchayat?.nameHindi ?? ins.panchayat?.name ?? "N/A"}' 
                                    : 'Gram Panchayat: ${ins.panchayat?.name ?? ins.panchayat?.nameHindi ?? "N/A"}',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              
                              if (isDownloading) ...[
                                LinearProgressIndicator(value: progress),
                                const SizedBox(height: 8),
                                Center(
                                  child: Text(
                                    '${context.tr('downloading')} ${(progress * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                              ] else if (isDownloadingDocx) ...[
                                LinearProgressIndicator(value: progressDocx),
                                const SizedBox(height: 8),
                                Center(
                                  child: Text(
                                    '${context.tr('downloading_docx')} ${(progressDocx * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                              ] else ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Button to Generate report
                                    ElevatedButton.icon(
                                      onPressed: isGenerating ? null : () => _generateReport(ins.id),
                                      icon: isGenerating
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Icon(Icons.build, size: 16, color: Colors.white),
                                      label: Text(context.tr('generate_report'), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Buttons for English PDF
                                    IconButton(
                                      icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                      tooltip: context.tr('view_reports') + ' (EN)',
                                      onPressed: () => _downloadAndViewReport(ins.id, ins.title, 'pdf_en'),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.share, color: Colors.redAccent),
                                      tooltip: 'Share English PDF',
                                      onPressed: () => _shareReportFile(ins.id, ins.title, 'pdf_en'),
                                    ),

                                    // Buttons for Hindi PDF
                                    IconButton(
                                      icon: const Icon(Icons.picture_as_pdf, color: Colors.orange),
                                      tooltip: context.tr('view_reports') + ' (HI)',
                                      onPressed: () => _downloadAndViewReport(ins.id, ins.title, 'pdf_hi'),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.share, color: Colors.orangeAccent),
                                      tooltip: 'Share Hindi PDF',
                                      onPressed: () => _shareReportFile(ins.id, ins.title, 'pdf_hi'),
                                    ),
                                    
                                    const SizedBox(width: 8),

                                    // Button to Download and View DOCX
                                    IconButton(
                                      icon: const Icon(Icons.description, color: Colors.blue),
                                      tooltip: context.tr('view_docx_report'),
                                      onPressed: () => _downloadAndViewDocxReport(ins.id, ins.title),
                                    ),

                                    // Button to share DOCX file
                                    IconButton(
                                      icon: const Icon(Icons.share, color: Colors.blueAccent),
                                      tooltip: context.tr('share'),
                                      onPressed: () => _shareDocxReportFile(ins.id, ins.title),
                                    ),
                                  ],
                                ),
                              ]
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

// Dummy storage class to read credentials if needed, importing FlutterSecureStorage
class signupStorage {
  const signupStorage();
  Future<String?> readToken() async {
    final storage = FlutterSecureStorage();
    return await storage.read(key: AppConstants.accessTokenKey);
  }
}
