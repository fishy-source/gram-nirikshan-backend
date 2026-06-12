import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../providers/inspection_provider.dart';
import '../../providers/auth_provider.dart';

class NewInspectionScreen extends StatefulWidget {
  const NewInspectionScreen({super.key});

  @override
  State<NewInspectionScreen> createState() => _NewInspectionScreenState();
}

class _NewInspectionScreenState extends State<NewInspectionScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _titleController = TextEditingController();
  final _projectNameController = TextEditingController();
  final _projectCodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _panchayatNameController = TextEditingController();
  final _captionController = TextEditingController();
  
  String? _selectedPanchayatId;
  String? _selectedType;
  DateTime? _selectedDate;
  bool _isManualPanchayat = false;

  final _picker = ImagePicker();
  File? _imageFile;
  Position? _currentPosition;
  String _gpsStatus = 'GPS स्थान प्राप्त नहीं हुआ';
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    if (AppConstants.inspectionTypes.isNotEmpty) {
      _selectedType = AppConstants.inspectionTypes.first;
    }
    // Load panchayats from the backend on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InspectionProvider>().loadPanchayats();
    });
    _determinePosition();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _projectNameController.dispose();
    _projectCodeController.dispose();
    _descriptionController.dispose();
    _panchayatNameController.dispose();
    _captionController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('hi', 'IN'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _updateMapCamera() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          16.0,
        ),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _updateMapCamera();
  }

  Set<Marker> _buildMapMarkers() {
    final markers = <Marker>{};
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current_photo_loc'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'निरीक्षण/फ़ोटो स्थान'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        ),
      );
    }
    return markers;
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
      _updateMapCamera();
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
        // Auto-fetch fresh GPS coordinates when photo is taken/picked
        _determinePosition();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('फोटो चुनने में त्रुटि: $e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isManualPanchayat && _selectedPanchayatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया ग्राम पंचायत चुनें'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    if (_isManualPanchayat && _panchayatNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया ग्राम पंचायत का नाम लिखें'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final provider = context.read<InspectionProvider>();
    final data = {
      if (!_isManualPanchayat) 'panchayat_id': _selectedPanchayatId,
      if (_isManualPanchayat) 'new_panchayat_name': _panchayatNameController.text.trim(),
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      'inspection_type': _selectedType,
      'project_name': _projectNameController.text.trim().isEmpty ? null : _projectNameController.text.trim(),
      'project_code': _projectCodeController.text.trim().isEmpty ? null : _projectCodeController.text.trim(),
      'inspection_date': _selectedDate?.toUtc().toIso8601String(),
    };

    final newInspection = await provider.createInspection(data);
    if (!mounted) return;

    if (newInspection != null) {
      // Direct Photo Upload Logic
      if (_imageFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('निरीक्षण सेव हो गया। फ़ोटो अपलोड हो रही है...'),
              ],
            ),
            duration: Duration(seconds: 4),
          ),
        );
        try {
          await ApiService().uploadPhoto(
            inspectionId: newInspection.id,
            filePath: _imageFile!.path,
            latitude: _currentPosition?.latitude ?? AppConstants.defaultLat,
            longitude: _currentPosition?.longitude ?? AppConstants.defaultLng,
            caption: _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('फ़ोटो अपलोड विफल: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('नया निरीक्षण सफलतापूर्वक बनाया गया!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      // Redirect to the newly created inspection's detail screen
      Navigator.pushReplacementNamed(
        context,
        '/inspections/detail',
        arguments: newInspection.id,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('निरीक्षण बनाने में विफल: ${provider.error ?? "अज्ञान त्रुटि"}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InspectionProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final panchayats = provider.panchayats;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('नया निरीक्षण बनाएं', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: provider.isLoading && panchayats.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Form Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'निरीक्षण का विवरण',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Junior Engineer Name
                            TextFormField(
                              initialValue: user?.nameHindi ?? user?.name ?? 'N/A',
                              enabled: false,
                              style: const TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                labelText: 'अवर अभियंता का नाम (Junior Engineer)',
                                prefixIcon: const Icon(Icons.person, color: Colors.grey),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // District Name
                            TextFormField(
                              initialValue: user?.district ?? 'N/A',
                              enabled: false,
                              style: const TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                labelText: 'जनपद का नाम (District)',
                                prefixIcon: const Icon(Icons.map, color: Colors.grey),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Block Name
                            TextFormField(
                              initialValue: user?.block ?? 'N/A',
                              enabled: false,
                              style: const TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                labelText: 'ब्लॉक का नाम (Block)',
                                prefixIcon: const Icon(Icons.location_on, color: Colors.grey),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Panchayat Mode Selection
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'ग्राम पंचायत *',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _isManualPanchayat = !_isManualPanchayat;
                                      if (_isManualPanchayat) {
                                        _selectedPanchayatId = null;
                                      } else {
                                        _panchayatNameController.clear();
                                      }
                                    });
                                  },
                                  icon: Icon(_isManualPanchayat ? Icons.list : Icons.edit, size: 18),
                                  label: Text(
                                    _isManualPanchayat ? 'सूची से चुनें' : 'मैनुअल नाम लिखें',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            _isManualPanchayat
                                ? TextFormField(
                                    controller: _panchayatNameController,
                                    decoration: InputDecoration(
                                      labelText: 'ग्राम पंचायत का नाम (मैनुअल लिखें) *',
                                      prefixIcon: const Icon(Icons.location_city, color: AppTheme.primaryColor),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                    validator: (val) {
                                      if (_isManualPanchayat && (val == null || val.trim().isEmpty)) {
                                        return 'ग्राम पंचायत का नाम लिखना अनिवार्य है';
                                      }
                                      return null;
                                    },
                                  )
                                : DropdownButtonFormField<String>(
                                    value: _selectedPanchayatId,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: 'ग्राम पंचायत चुनें *',
                                      prefixIcon: const Icon(Icons.location_city, color: AppTheme.primaryColor),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                    hint: const Text('ग्राम पंचायत चुनें'),
                                    items: panchayats.map((p) {
                                      return DropdownMenuItem<String>(
                                        value: p.id,
                                        child: Text(
                                          p.nameHindi ?? p.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedPanchayatId = val;
                                      });
                                    },
                                    validator: (val) {
                                      if (!_isManualPanchayat && val == null) {
                                        return 'ग्राम पंचायत चुनना अनिवार्य है';
                                      }
                                      return null;
                                    },
                                  ),
                            const SizedBox(height: 16),

                            // Inspection Type Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedType,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'निरीक्षण का प्रकार',
                                prefixIcon: const Icon(Icons.category, color: AppTheme.primaryColor),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              items: AppConstants.inspectionTypes.map((type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(
                                    type,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedType = val;
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // Title Field
                            TextFormField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                labelText: 'निरीक्षण का शीर्षक (Title) *',
                                prefixIcon: const Icon(Icons.title, color: AppTheme.primaryColor),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'शीर्षक लिखना अनिवार्य है';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Project Name Field
                            TextFormField(
                              controller: _projectNameController,
                              decoration: InputDecoration(
                                labelText: 'परियोजना का नाम (Project Name)',
                                prefixIcon: const Icon(Icons.work, color: AppTheme.primaryColor),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Project Code Field
                            TextFormField(
                              controller: _projectCodeController,
                              decoration: InputDecoration(
                                labelText: 'परियोजना कोड (Project Code)',
                                prefixIcon: const Icon(Icons.qr_code, color: AppTheme.primaryColor),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Date Picker Field
                            InkWell(
                              onTap: () => _selectDate(context),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'निरीक्षण की तिथि',
                                  prefixIcon: const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                child: Text(
                                  _selectedDate == null
                                      ? 'तिथि चुनें'
                                      : DateFormat('dd/MM/yyyy').format(_selectedDate!),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Description Field
                            TextFormField(
                              controller: _descriptionController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: 'विवरण / अतिरिक्त टिप्पणी (Description)',
                                prefixIcon: const Icon(Icons.description, color: AppTheme.primaryColor),
                                alignLabelWithHint: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Photo Upload Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'निरीक्षण फ़ोटो (ऑप्शनल)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _imageFile == null
                                ? Container(
                                    height: 150,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey[300]!, width: 1),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey),
                                        SizedBox(height: 8),
                                        Text('कोई फोटो चुनी नहीं गई है', style: TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(_imageFile!, height: 180, fit: BoxFit.cover),
                                  ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _pickImage(ImageSource.camera),
                                    icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                                    label: const Text('कैमरा', style: TextStyle(color: Colors.white, fontSize: 13)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _pickImage(ImageSource.gallery),
                                    icon: const Icon(Icons.photo_library, color: Colors.white, size: 18),
                                    label: const Text('गैलरी', style: TextStyle(color: Colors.white, fontSize: 13)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.secondaryColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_imageFile != null) ...[
                              const SizedBox(height: 12),
                              // Caption field
                              TextFormField(
                                controller: _captionController,
                                decoration: InputDecoration(
                                  labelText: 'फ़ोटो का शीर्षक / टिप्पणी (Caption)',
                                  prefixIcon: const Icon(Icons.comment, color: AppTheme.primaryColor, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Google Map Card showing current location
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'निरीक्षण स्थान (नक्शा)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 180,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[300]!, width: 1),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: GoogleMap(
                                  onMapCreated: _onMapCreated,
                                  initialCameraPosition: CameraPosition(
                                    target: _currentPosition != null
                                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                                        : const LatLng(AppConstants.defaultLat, AppConstants.defaultLng),
                                    zoom: _currentPosition != null ? 16.0 : 8.0,
                                  ),
                                  markers: _buildMapMarkers(),
                                  myLocationEnabled: true,
                                  myLocationButtonEnabled: false,
                                  zoomControlsEnabled: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: AppTheme.primaryColor, size: 16),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _gpsStatus,
                                    style: TextStyle(
                                      color: _currentPosition != null ? AppTheme.successColor : Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 16, color: AppTheme.primaryColor),
                                  onPressed: _determinePosition,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: provider.isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: provider.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'निरीक्षण सुरक्षित करें',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
