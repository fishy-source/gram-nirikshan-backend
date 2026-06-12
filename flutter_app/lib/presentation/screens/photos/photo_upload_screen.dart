import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../providers/inspection_provider.dart';
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
  String _gpsStatus = 'GPS स्थान प्राप्त नहीं हुआ';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
        setState(() => _gpsStatus = 'GPS बंद है');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _gpsStatus = 'GPS अनुमति अस्वीकृत');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _gpsStatus = 'GPS अनुमति स्थायी रूप से अस्वीकृत');
        return;
      }

      setState(() => _gpsStatus = 'GPS स्थान खोजा जा रहा है...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      setState(() {
        _currentPosition = position;
        _gpsStatus = 'GPS स्थान: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      });
    } catch (e) {
      setState(() => _gpsStatus = 'GPS त्रुटि: ${e.toString()}');
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('फोटो चुनने में त्रुटि: $e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  Future<void> _upload() async {
    if (_selectedInspection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया एक निरीक्षण चुनें'), backgroundColor: AppTheme.errorColor),
      );
      return;
    }
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया एक फोटो खींचें या चुनें'), backgroundColor: AppTheme.errorColor),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService().uploadPhoto(
        inspectionId: _selectedInspection!.id,
        filePath: _imageFile!.path,
        latitude: _currentPosition?.latitude ?? AppConstants.defaultLat,
        longitude: _currentPosition?.longitude ?? AppConstants.defaultLng,
        caption: _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('फोटो सफलतापूर्वक अपलोड किया गया!'), backgroundColor: AppTheme.successColor),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('सर्वर त्रुटि: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('अपलोड करने में विफल: $e'), backgroundColor: AppTheme.errorColor),
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
        title: const Text('फ़ोटो अपलोड करें', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    const Text('निरीक्षण चुनें',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<InspectionModel>(
                      value: _selectedInspection,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'निरीक्षण सूची *',
                        prefixIcon: const Icon(Icons.assignment, color: AppTheme.primaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      hint: const Text('निरीक्षण चुनें'),
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
                      Text('ग्राम पंचायत: ${_selectedInspection!.panchayat?.nameHindi ?? _selectedInspection!.panchayat?.name ?? "N/A"}',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text('योजना/परियोजना: ${_selectedInspection!.projectName ?? "N/A"}',
                          style: const TextStyle(color: Colors.grey, fontSize: 13)),
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
                    const Text('फ़ोटो चयन',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    const SizedBox(height: 16),
                    _imageFile == null
                        ? Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!, width: 1),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('कोई फोटो चुनी नहीं गई है', style: TextStyle(color: Colors.grey)),
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
                            label: const Text('कैमरा', style: TextStyle(color: Colors.white)),
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
                            label: const Text('गैलरी', style: TextStyle(color: Colors.white)),
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
                    const Text('अतिरिक्त जानकारी (Metadata)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
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
                        labelText: 'फ़ोटो का शीर्षक / टिप्पणी (Caption)',
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
                  : const Text('फ़ोटो अपलोड करें',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
