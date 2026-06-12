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
import '../../../data/models/models.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final Map<String, bool> _generatingMap = {};
  final Map<String, double> _downloadProgressMap = {};
  final Map<String, bool> _downloadingMap = {};

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
            const SnackBar(content: Text('निरीक्षण रिपोर्ट सफलतापूर्वक बनाई गई!'), backgroundColor: AppTheme.successColor),
          );
        }
        // Refresh inspections list to update status
        if (mounted) {
          context.read<InspectionProvider>().loadInspections(refresh: true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('रिपोर्ट बनाने में विफल: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      setState(() => _generatingMap[inspectionId] = false);
    }
  }

  Future<void> _downloadAndViewReport(String inspectionId, String title) async {
    setState(() {
      _downloadingMap[inspectionId] = true;
      _downloadProgressMap[inspectionId] = 0.0;
    });

    try {
      final downloadUrl = await ApiService().getReportDownloadUrl(inspectionId);
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/Report_$inspectionId.pdf';

      // Download file using Dio
      final dio = Dio();
      
      final flutterSecureStorage = FlutterSecureStorage();
      final tokenValue = await flutterSecureStorage.read(key: AppConstants.accessTokenKey);

      try {
        await dio.download(
          downloadUrl,
          savePath,
          options: Options(headers: {'Authorization': 'Bearer $tokenValue'}),
          onReceiveProgress: (received, total) {
            if (total != -1) {
              setState(() {
                _downloadProgressMap[inspectionId] = received / total;
              });
            }
          },
        );
      } on DioException catch (de) {
        if (de.response?.statusCode == 404) {
          // Report not found, auto-generate first!
          setState(() {
            _generatingMap[inspectionId] = true;
          });
          await ApiService().generateReport(inspectionId);
          setState(() {
            _generatingMap[inspectionId] = false;
          });
          
          // Retry downloading after successful generation
          await dio.download(
            downloadUrl,
            savePath,
            options: Options(headers: {'Authorization': 'Bearer $tokenValue'}),
            onReceiveProgress: (received, total) {
              if (total != -1) {
                setState(() {
                  _downloadProgressMap[inspectionId] = received / total;
                });
              }
            },
          );
        } else {
          rethrow;
        }
      }

      setState(() => _downloadingMap[inspectionId] = false);

      // Open the downloaded PDF
      final result = await OpenFile.open(savePath);
      if (result.type != ResultType.done && mounted) {
        // Fallback: launch in browser
        final url = Uri.parse(downloadUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('फ़ाइल खोलने में असमर्थ: ${result.message}'), backgroundColor: AppTheme.errorColor),
          );
        }
      }
    } catch (e) {
      setState(() {
        _downloadingMap[inspectionId] = false;
        _generatingMap[inspectionId] = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('रिपोर्ट खोलने या बनाने में विफल: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _shareReportLink(String inspectionId) async {
    try {
      final downloadUrl = await ApiService().getReportDownloadUrl(inspectionId);
      await Share.share(
        'ग्राम निरीक्षण रिपोर्ट देखने के लिए इस लिंक पर जाएं:\n$downloadUrl',
        subject: 'ग्राम निरीक्षण रिपोर्ट',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('शेयर करने में त्रुटि: $e'), backgroundColor: AppTheme.errorColor),
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
        title: const Text('निरीक्षण रिपोर्ट देखें', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<InspectionProvider>().loadInspections(refresh: true),
        child: isLoading && inspections.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : inspections.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.description_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('कोई निरीक्षण सूची उपलब्ध नहीं है', style: TextStyle(color: Colors.grey)),
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
                                'ग्राम पंचायत: ${ins.panchayat?.nameHindi ?? ins.panchayat?.name ?? "N/A"}',
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              
                              if (isDownloading) ...[
                                LinearProgressIndicator(value: progress),
                                const SizedBox(height: 8),
                                Center(
                                  child: Text(
                                    'डाउनलोड हो रहा है... ${(progress * 100).toStringAsFixed(0)}%',
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
                                      label: const Text('रिपोर्ट बनाएं', style: TextStyle(color: Colors.white, fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Button to Download and View
                                    IconButton(
                                      icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                      tooltip: 'रिपोर्ट देखें',
                                      onPressed: () => _downloadAndViewReport(ins.id, ins.title),
                                    ),

                                    // Button to share link
                                    IconButton(
                                      icon: const Icon(Icons.share, color: AppTheme.secondaryColor),
                                      tooltip: 'शेयर करें',
                                      onPressed: () => _shareReportLink(ins.id),
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
