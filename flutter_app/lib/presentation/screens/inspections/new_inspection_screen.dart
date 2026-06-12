import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
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
  
  String? _selectedPanchayatId;
  String? _selectedType;
  DateTime? _selectedDate;
  bool _isManualPanchayat = false;

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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _projectNameController.dispose();
    _projectCodeController.dispose();
    _descriptionController.dispose();
    _panchayatNameController.dispose();
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
          content: Text('निरीक्षण बनाने में विफल: ${provider.error ?? "अज्ञात त्रुटि"}'),
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
