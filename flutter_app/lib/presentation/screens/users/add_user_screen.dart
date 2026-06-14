import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../providers/language_provider.dart';
import '../../providers/auth_provider.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _mobile = '';
  String _aadhar = '';
  String _role = 'inspector';
  bool _isLoading = false;

  final List<String> _roles = ['inspector', 'admin', 'superadmin'];

  String _getRoleLabel(String role, bool isHindi) {
    switch (role) {
      case 'inspector': return isHindi ? 'इंस्पेक्टर (Inspector)' : 'Inspector';
      case 'admin': return isHindi ? 'एडमिन (Admin)' : 'Admin';
      case 'superadmin': return isHindi ? 'सुपर एडमिन (Super Admin)' : 'Super Admin';
      default: return role;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    
    setState(() => _isLoading = true);
    
    try {
      await ApiService().createUser({
        'name': _name,
        'mobile': _mobile,
        'aadhar_number': _aadhar,
        'role': _role,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<LanguageProvider>().isHindi ? 'यूज़र सफलतापूर्वक जुड़ गया!' : 'User added successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = context.watch<LanguageProvider>().isHindi;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(isHindi ? 'नया यूज़र जोड़ें' : 'Add User'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isHindi ? 'यूज़र की जानकारी भरें' : 'Enter User Details',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 20),
              
              TextFormField(
                decoration: InputDecoration(
                  labelText: isHindi ? 'पूरा नाम *' : 'Full Name *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (v) => v == null || v.isEmpty ? (isHindi ? 'नाम लिखना अनिवार्य है' : 'Name is required') : null,
                onSaved: (v) => _name = v!,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                decoration: InputDecoration(
                  labelText: isHindi ? 'मोबाइल नंबर *' : 'Mobile Number *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                maxLength: 10,
                validator: (v) => v == null || v.length != 10 ? (isHindi ? 'सही मोबाइल नंबर लिखें' : 'Enter valid mobile number') : null,
                onSaved: (v) => _mobile = v!,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                decoration: InputDecoration(
                  labelText: isHindi ? 'आधार नंबर *' : 'Aadhar Number *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.credit_card),
                ),
                keyboardType: TextInputType.number,
                maxLength: 12,
                validator: (v) => v == null || v.length != 12 ? (isHindi ? '12 अंकों का आधार नंबर लिखें' : 'Enter 12 digit Aadhar number') : null,
                onSaved: (v) => _aadhar = v!,
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _role,
                decoration: InputDecoration(
                  labelText: isHindi ? 'यूज़र का प्रकार (Role) *' : 'User Role *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.admin_panel_settings),
                ),
                items: _roles.map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(_getRoleLabel(r, isHindi)),
                )).toList(),
                onChanged: (v) => setState(() => _role = v!),
              ),
              
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(isHindi ? 'रजिस्टर करें' : 'Register User', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
