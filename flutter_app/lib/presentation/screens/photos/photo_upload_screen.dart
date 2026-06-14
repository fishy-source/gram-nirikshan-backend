import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../providers/inspection_provider.dart';
import '../../providers/language_provider.dart';
import '../../../data/models/models.dart';

class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({super.key});

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  final _picker = ImagePicker();
  final _captionController = TextEditingController();
  
  InspectionModel? _selectedInspection;
  File? _imageFile;
  bool _isLoading = false;
  Position? _currentPosition;
  String _gpsStatus = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _gpsStatus = context.read<LanguageProvider>().translate('gps_not_received');
      context.read<InspectionProvider>().loadInspections(refresh: true);
    });
    _determinePosition();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _gpsStatus = context.read<LanguageProvider>().translate('gps_disabled'));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _gpsStatus = context.read<LanguageProvider>().translate('gps_denied'));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _gpsStatus = context.read<LanguageProvider>().translate('gps_denied_forever'));
        return;
      }

      setState(() => _gpsStatus = context.read<LanguageProvider>().translate('gps_searching'));
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      setState(() {
        _currentPosition = position;
        final isHindi = context.read<LanguageProvider>().isHindi;
        _gpsStatus = isHindi 
            ? 'GPS स्थान: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}'
            : 'GPS Location: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      });
    } catch (e) {
      final errLabel = context.read<LanguageProvider>().translate('gps_error');
      setState(() => _gpsStatus = '$errLabel: ${e.toString()}');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      final errLabel = context.read<LanguageProvider>().translate('photo_select_error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errLabel: $e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  Future<void> _upload() async {
    final isHindi = context.read<LanguageProvider>().isHindi;
    if (_selectedInspection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isHindi ? 'कृपया एक निरीक्षण चुनें' : 'Please select an inspection'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isHindi ? 'कृपया एक फोटो खींचें या चुनें' : 'Please take or select a photo'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      File fileToUpload = _imageFile!;
      
      // Watermark logic if GPS is available
      if (_currentPosition != null) {
        try {
          final bytes = await fileToUpload.readAsBytes();
          img.Image? originalImage = img.decodeImage(bytes);
          
          if (originalImage != null) {
            final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
            final watermarkText = 'Lat: ${_currentPosition!.latitude.toStringAsFixed(5)} Lng: ${_currentPosition!.longitude.toStringAsFixed(5)} Time: $timestamp';
            
            // Draw text background
            img.fillRect(
              originalImage,
              x1: 0,
              y1: originalImage.height - 40,
              x2: originalImage.width,
              y2: originalImage.height,
              color: img.ColorRgba8(0, 0, 0, 128),
            );
            
            // Draw text
            img.drawString(
              originalImage,
              watermarkText,
              font: img.arial24,
              x: 10,
              y: originalImage.height - 30,
              color: img.ColorRgb8(255, 255, 255),
            );
            
            final watermarkedBytes = img.encodeJpg(originalImage, quality: 85);
            final tempDir = await getTemporaryDirectory();
            fileToUpload = File('${tempDir.path}/watermarked_${DateTime.now().millisecondsSinceEpoch}.jpg');
            await fileToUpload.writeAsBytes(watermarkedBytes);
          }
        } catch (e) {
          debugPrint('Watermarking failed: $e');
        }
      }

      final response = await ApiService().uploadPhoto(
        inspectionId: _selectedInspection!.id,
        filePath: fileToUpload.path,
        latitude: _currentPosition?.latitude ?? AppConstants.defaultLat,
        longitude: _currentPosition?.longitude ?? AppConstants.defaultLng,
        caption: _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isHindi ? 'फोटो सफलतापूर्वक अपलोड किया गया!' : 'Photo uploaded successfully!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception(isHindi ? 'सर्वर त्रुटि: ${response.statusCode}' : 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isHindi ? 'अपलोड करने में विफल: $e' : 'Failed to upload: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inspections = context.watch<InspectionProvider>().inspections;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(context.tr('photo_upload'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Inspection Selector Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('select_inspection'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<InspectionModel>(
                      value: _selectedInspection,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.tr('inspection_list_label'),
                        prefixIcon: const Icon(Icons.assignment, color: AppTheme.primaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      hint: Text(context.tr('select_inspection')),
                      items: inspections.map((ins) {
                        return DropdownMenuItem<InspectionModel>(
                          value: ins,
                          child: Text(
                            '${ins.inspectionId} - ${ins.title}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedInspection = val;
                        });
                      },
                    ),
                    if (_selectedInspection != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        context.read<LanguageProvider>().isHindi 
                            ? 'ग्राम पंचायत: ${_selectedInspection!.panchayat?.nameHindi ?? _selectedInspection!.panchayat?.name ?? "N/A"}' 
                            : 'Gram Panchayat: ${_selectedInspection!.panchayat?.name ?? _selectedInspection!.panchayat?.nameHindi ?? "N/A"}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.read<LanguageProvider>().isHindi 
                            ? 'योजना/परियोजना: ${_selectedInspection!.projectName ?? "N/A"}' 
                            : 'Project: ${_selectedInspection!.projectName ?? "N/A"}',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Image Picker Section Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(context.tr('photo_selection'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    const SizedBox(height: 16),
                    _imageFile == null
                        ? Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!, width: 1),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text(context.tr('no_photo_selected'), style: const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_imageFile!, height: 200, fit: BoxFit.cover),
                          ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt, color: Colors.white),
                            label: Text(context.tr('camera'), style: const TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library, color: Colors.white),
                            label: Text(context.tr('gallery'), style: const TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Metadata Card (GPS & Caption)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(context.tr('additional_info_metadata'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    const SizedBox(height: 16),
                    // GPS status row
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _gpsStatus,
                            style: TextStyle(
                              color: _currentPosition != null ? AppTheme.successColor : Colors.orange,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20, color: AppTheme.primaryColor),
                          onPressed: _determinePosition,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Caption field
                    TextFormField(
                      controller: _captionController,
                      decoration: InputDecoration(
                        labelText: context.tr('photo_caption'),
                        prefixIcon: const Icon(Icons.comment, color: AppTheme.primaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Upload Button
            ElevatedButton(
              onPressed: _isLoading ? null : _upload,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(context.tr('photo_upload'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
