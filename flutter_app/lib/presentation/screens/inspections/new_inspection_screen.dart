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
import 'package:path_provider/path_provider.dart';
import '../../providers/language_provider.dart';
import 'map_picker_screen.dart';

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
  final _investigatorNameController = TextEditingController();
  final _districtController = TextEditingController();
  final _blockController = TextEditingController();
  
  String? _selectedPanchayatId;
  String? _selectedType;
  DateTime? _selectedDate;
  bool _isManualPanchayat = false;

  final _picker = ImagePicker();
  List<File> _selectedPhotos = [];
  File? _mapImageFile;
  Position? _currentPosition;
  String _gpsStatus = '';
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
      _gpsStatus = context.read<LanguageProvider>().translate('gps_not_received');
      context.read<InspectionProvider>().loadPanchayats();

      final user = context.read<AuthProvider>().currentUser;
      if (user != null) {
        setState(() {
          _investigatorNameController.text = user.nameHindi ?? user.name;
          _districtController.text = user.district ?? '';
          _blockController.text = user.block ?? '';
        });
      }
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
    _investigatorNameController.dispose();
    _districtController.dispose();
    _blockController.dispose();
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
          infoWindow: InfoWindow(title: context.tr('inspection_photo_location')),
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
      _updateMapCamera();
    } catch (e) {
      final errLabel = context.read<LanguageProvider>().translate('gps_error');
      setState(() => _gpsStatus = '$errLabel: ${e.toString()}');
    }
  }

  Future<void> _pickGalleryImages() async {
    try {
      final pickedFiles = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedPhotos.addAll(pickedFiles.map((pf) => File(pf.path)));
        });
        _determinePosition();
      }
    } catch (e) {
      final errLabel = context.read<LanguageProvider>().translate('photo_select_error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errLabel: $e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  Future<void> _pickCameraImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedPhotos.add(File(pickedFile.path));
        });
        _determinePosition();
      }
    } catch (e) {
      final errLabel = context.read<LanguageProvider>().translate('photo_select_error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$errLabel: $e'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  Future<void> _captureMapSnapshot() async {
    if (_mapController == null) return;
    try {
      final imageBytes = await _mapController!.takeSnapshot();
      if (imageBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/map_snapshot_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await file.writeAsBytes(imageBytes);
        setState(() {
          _mapImageFile = file;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.read<LanguageProvider>().isHindi 
                  ? 'नक्शा स्नैपशॉट सफलतापूर्वक कैप्चर किया गया!' 
                  : 'Map snapshot captured successfully!'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Map snapshot error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _pickMapImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (pickedFile != null) {
        setState(() {
          _mapImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Map select error: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _executeWorkflow(Map<String, dynamic> data) async {
    final isHindi = context.read<LanguageProvider>().isHindi;
    
    List<String> stepNames = isHindi 
        ? [
            '1. निरीक्षण बनाना',
            '2. फ़ोटो अपलोड करना',
            '3. मानचित्र अपलोड करना',
            '4. AI रिपोर्ट जनरेट करना',
            '5. PDF रिपोर्ट तैयार करना'
          ]
        : [
            '1. Creating Inspection',
            '2. Uploading Photos',
            '3. Uploading Location Map',
            '4. Generating AI Report',
            '5. Generating PDF Report'
          ];

    int currentWorkflowStep = 0;
    String workflowStatus = 'running';
    String errorMsg = '';
    String photoProgress = '';
    StateSetter? dialogStateSetter;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            dialogStateSetter = setDialogState;

            Widget buildStepIcon(int stepIndex) {
              if (currentWorkflowStep > stepIndex) {
                return const Icon(Icons.check_circle, color: Colors.green, size: 24);
              }
              if (currentWorkflowStep == stepIndex) {
                if (workflowStatus == 'running') {
                  return const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  );
                } else if (workflowStatus == 'error') {
                  return const Icon(Icons.error, color: Colors.red, size: 24);
                }
              }
              return const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 24);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                isHindi ? 'निरीक्षण प्रसंस्करण कार्यप्रवाह' : 'Inspection Processing Workflow',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHindi 
                        ? 'कृपया प्रतीक्षा करें, प्रक्रिया चल रही है:' 
                        : 'Please wait while we process the inspection:',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(5, (index) {
                    final isCurrent = index == currentWorkflowStep;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          buildStepIcon(index),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stepNames[index],
                                  style: TextStyle(
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                    color: isCurrent ? Colors.black : Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                if (index == 1 && isCurrent && photoProgress.isNotEmpty)
                                  Text(
                                    photoProgress,
                                    style: const TextStyle(fontSize: 11, color: Colors.blue),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (workflowStatus == 'error') ...[
                    const SizedBox(height: 16),
                    Text(
                      '${isHindi ? "त्रुटि" : "Error"}: $errorMsg',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                if (workflowStatus == 'error')
                  TextButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: Text(isHindi ? 'बंद करें' : 'Close'),
                  ),
              ],
            );
          },
        );
      },
    );

    try {
      final provider = context.read<InspectionProvider>();
      
      void updateDialog(int step, String currentStatus, {String err = '', String prog = ''}) {
        if (dialogStateSetter != null) {
          dialogStateSetter!(() {
            currentWorkflowStep = step;
            workflowStatus = currentStatus;
            errorMsg = err;
            photoProgress = prog;
          });
        }
      }

      // Step 1: Create
      updateDialog(0, 'running');
      final newInspection = await provider.createInspection(data);
      if (newInspection == null) {
        throw Exception(provider.error ?? (isHindi ? 'निरीक्षण बनाने में विफल' : 'Failed to create inspection'));
      }

      // Step 2: Upload Photos
      updateDialog(1, 'running');
      if (_selectedPhotos.isNotEmpty) {
        for (int i = 0; i < _selectedPhotos.length; i++) {
          final photo = _selectedPhotos[i];
          updateDialog(1, 'running', prog: isHindi ? 'अपलोड हो रहा है ${i + 1}/${_selectedPhotos.length}' : 'Uploading ${i + 1}/${_selectedPhotos.length}');
          await ApiService().uploadPhoto(
            inspectionId: newInspection.id,
            filePath: photo.path,
            latitude: _currentPosition?.latitude ?? AppConstants.defaultLat,
            longitude: _currentPosition?.longitude ?? AppConstants.defaultLng,
            caption: _captionController.text.trim().isEmpty ? null : _captionController.text.trim(),
          );
        }
      }

      // Step 3: Upload Map
      updateDialog(2, 'running');
      if (_mapImageFile != null) {
        await ApiService().uploadMap(
          inspectionId: newInspection.id,
          filePath: _mapImageFile!.path,
        );
      }

      // Step 4: Suggest AI Report
      updateDialog(3, 'running');
      final aiSuccess = await provider.suggestAIReport(newInspection.id);
      if (!aiSuccess) {
        throw Exception(provider.error ?? (isHindi ? 'AI रिपोर्ट जनरेट करने में विफल' : 'Failed to generate AI report'));
      }

      // Step 5: Generate PDF
      updateDialog(4, 'running');
      try {
        await ApiService().generateReport(newInspection.id);
      } catch (e) {
        throw Exception(isHindi ? 'PDF जनरेट करने में विफल: $e' : 'Failed to generate PDF: $e');
      }

      updateDialog(5, 'success');
      
      if (mounted) {
        Navigator.pop(context); // Close dialog
        Navigator.pushReplacementNamed(
          context,
          '/reports/preview',
          arguments: {
            'inspectionId': newInspection.id,
            'title': newInspection.title,
          },
        );
      }
    } catch (e) {
      if (dialogStateSetter != null) {
        dialogStateSetter!(() {
          workflowStatus = 'error';
          errorMsg = e.toString().replaceAll('Exception:', '').trim();
        });
      }
    }
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isManualPanchayat && _selectedPanchayatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('please_select_panchayat')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    if (_isManualPanchayat && _panchayatNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('please_write_panchayat')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final data = {
      if (!_isManualPanchayat) 'panchayat_id': _selectedPanchayatId,
      if (_isManualPanchayat) 'new_panchayat_name': _panchayatNameController.text.trim(),
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      'inspection_type': _selectedType,
      'project_name': _projectNameController.text.trim().isEmpty ? null : _projectNameController.text.trim(),
      'project_code': _projectCodeController.text.trim().isEmpty ? null : _projectCodeController.text.trim(),
      'inspection_date': _selectedDate?.toUtc().toIso8601String(),
      'investigator_name': _investigatorNameController.text.trim().isEmpty ? null : _investigatorNameController.text.trim(),
      'district': _districtController.text.trim().isEmpty ? null : _districtController.text.trim(),
      'block': _blockController.text.trim().isEmpty ? null : _blockController.text.trim(),
    };

    _executeWorkflow(data);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InspectionProvider>();
    final panchayats = provider.panchayats;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text(context.tr('create_new_inspection'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                            Text(
                              context.tr('inspection_details'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Junior Engineer Name -> Investigator Name
                            TextFormField(
                              controller: _investigatorNameController,
                              style: const TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                labelText: context.tr('officer_name'),
                                prefixIcon: const Icon(Icons.person, color: AppTheme.primaryColor),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Investigator name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // District Name -> Searchable Editable Text Field
                            Autocomplete<String>(
                              initialValue: TextEditingValue(text: _districtController.text),
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                final list = panchayats.map((p) => p.district).toSet().toList();
                                if (textEditingValue.text.isEmpty) {
                                  return list;
                                }
                                return list.where((String option) {
                                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                });
                              },
                              onSelected: (String selection) {
                                _districtController.text = selection;
                              },
                              fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                                if (textController.text != _districtController.text && _districtController.text.isNotEmpty && textController.text.isEmpty) {
                                  textController.text = _districtController.text;
                                }
                                textController.addListener(() {
                                  _districtController.text = textController.text;
                                });
                                return TextFormField(
                                  controller: textController,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: context.tr('district_name'),
                                    prefixIcon: const Icon(Icons.map, color: AppTheme.primaryColor),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'District is required';
                                    }
                                    return null;
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Block Name -> Searchable Editable Text Field
                            Autocomplete<String>(
                              initialValue: TextEditingValue(text: _blockController.text),
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                final list = panchayats.map((p) => p.block).toSet().toList();
                                if (textEditingValue.text.isEmpty) {
                                  return list;
                                }
                                return list.where((String option) {
                                  return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                                });
                              },
                              onSelected: (String selection) {
                                _blockController.text = selection;
                              },
                              fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                                if (textController.text != _blockController.text && _blockController.text.isNotEmpty && textController.text.isEmpty) {
                                  textController.text = _blockController.text;
                                }
                                textController.addListener(() {
                                  _blockController.text = textController.text;
                                });
                                return TextFormField(
                                  controller: textController,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: context.tr('block_name'),
                                    prefixIcon: const Icon(Icons.location_on, color: AppTheme.primaryColor),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Block is required';
                                    }
                                    return null;
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Panchayat Mode Selection
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  context.tr('select_panchayat'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryColor),
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
                                    _isManualPanchayat ? context.tr('select_from_list') : context.tr('write_manual'),
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
                                      labelText: context.tr('manual_panchayat'),
                                      prefixIcon: const Icon(Icons.location_city, color: AppTheme.primaryColor),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                    validator: (val) {
                                      if (_isManualPanchayat && (val == null || val.trim().isEmpty)) {
                                        return context.tr('panchayat_name_required');
                                      }
                                      return null;
                                    },
                                  )
                                : DropdownButtonFormField<String>(
                                    initialValue: _selectedPanchayatId,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: context.tr('select_panchayat'),
                                      prefixIcon: const Icon(Icons.location_city, color: AppTheme.primaryColor),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                    hint: Text(context.tr('select_panchayat')),
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
                                        return context.tr('panchayat_select_required');
                                      }
                                      return null;
                                    },
                                  ),
                            const SizedBox(height: 16),

                            // Inspection Type Dropdown
                            DropdownButtonFormField<String>(
                              initialValue: _selectedType,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: context.tr('inspection_type'),
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
                                labelText: context.tr('inspection_title'),
                                prefixIcon: const Icon(Icons.title, color: AppTheme.primaryColor),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return context.tr('title_required');
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Project Name Field
                            TextFormField(
                              controller: _projectNameController,
                              decoration: InputDecoration(
                                labelText: context.tr('project_name'),
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
                                labelText: context.tr('project_code'),
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
                                  labelText: context.tr('inspection_date'),
                                  prefixIcon: const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                child: Text(
                                  _selectedDate == null
                                      ? context.tr('select_date')
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
                                labelText: context.tr('description'),
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
                            Text(
                              context.tr('inspection_photo'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _selectedPhotos.isEmpty
                                ? Container(
                                    height: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey[300]!, width: 1),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey),
                                        const SizedBox(height: 8),
                                        Text(context.tr('no_photo_selected'), style: const TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                  )
                                : SizedBox(
                                    height: 120,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _selectedPhotos.length,
                                      itemBuilder: (context, index) {
                                        return Stack(
                                          children: [
                                            Container(
                                              margin: const EdgeInsets.only(right: 8, top: 8),
                                              width: 100,
                                              height: 100,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.grey[350]!),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.file(_selectedPhotos[index], fit: BoxFit.cover),
                                              ),
                                            ),
                                            Positioned(
                                              right: 0,
                                              top: 0,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedPhotos.removeAt(index);
                                                  });
                                                },
                                                child: Container(
                                                  decoration: const BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  padding: const EdgeInsets.all(4),
                                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                                                ),
                                              ),
                                            )
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _pickCameraImage,
                                    icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                                    label: Text(context.tr('camera'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _pickGalleryImages,
                                    icon: const Icon(Icons.photo_library, color: Colors.white, size: 18),
                                    label: Text(context.tr('gallery'), style: const TextStyle(color: Colors.white, fontSize: 13)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.secondaryColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedPhotos.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              // Caption field
                              TextFormField(
                                controller: _captionController,
                                decoration: InputDecoration(
                                  labelText: context.tr('photo_caption'),
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

                    // Google Map Card showing current location & map attachment options
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              context.tr('inspection_location_map'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MapPickerScreen(
                                        initialLat: _currentPosition?.latitude,
                                        initialLng: _currentPosition?.longitude,
                                      ),
                                    ),
                                  );
                                  if (result != null) {
                                    setState(() {
                                      _currentPosition = Position(
                                        latitude: result['latitude'],
                                        longitude: result['longitude'],
                                        timestamp: DateTime.now(),
                                        accuracy: 100,
                                        altitude: 0,
                                        heading: 0,
                                        speed: 0,
                                        speedAccuracy: 0,
                                        altitudeAccuracy: 0,
                                        headingAccuracy: 0,
                                      );
                                      _gpsStatus = 'Selected: ${result['address']}';
                                    });
                                  }
                                },
                                icon: const Icon(Icons.map, color: Colors.white),
                                label: Text(
                                  context.read<LanguageProvider>().isHindi ? 'नक्शे से स्थान चुनें' : 'Pick Location from Map',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                            const SizedBox(height: 12),
                            if (_mapImageFile != null) ...[
                              Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(_mapImageFile!, height: 120, width: double.infinity, fit: BoxFit.cover),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _captureMapSnapshot,
                                    icon: const Icon(Icons.map_rounded, color: Colors.white, size: 18),
                                    label: Text(
                                      context.read<LanguageProvider>().isHindi ? 'नक्शा कैप्चर' : 'Capture Map',
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _pickMapImage,
                                    icon: const Icon(Icons.photo_library, color: Colors.white, size: 18),
                                    label: Text(
                                      context.read<LanguageProvider>().isHindi ? 'नक्शा अपलोड' : 'Upload Map',
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.secondaryColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
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
                          : Text(
                              context.tr('save_inspection'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
