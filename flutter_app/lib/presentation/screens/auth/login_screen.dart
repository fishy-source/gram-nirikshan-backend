// OTP Login Screen with Indian phone number input

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _mobileController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _otpSent = false;
  String _otp = '';
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A5276), Color(0xFF154360), Color(0xFF0B3C5D)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Logo / Icon
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30, width: 2),
                      ),
                      child: const Icon(Icons.domain_verification_rounded, size: 54, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      context.tr('app_title'),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
                          color: Colors.white, fontFamily: 'Poppins'),
                    ),
                    const Text(
                      'Gram Nirikshan App',
                      style: TextStyle(fontSize: 16, color: Colors.white70, fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('app_subtitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.white54, fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 48),

                    // Login Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2),
                              blurRadius: 30, offset: const Offset(0, 10)),
                        ],
                      ),
                      padding: const EdgeInsets.all(28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _otpSent ? context.tr('enter_otp') : context.tr('login'),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _otpSent
                                  ? (context.watch<LanguageProvider>().isHindi 
                                      ? '${_mobileController.text} पर OTP भेजा गया' 
                                      : 'OTP sent to ${_mobileController.text}')
                                  : context.tr('enter_mobile'),
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 24),

                            if (!_otpSent) _buildMobileInput() else _buildOTPInput(),
                            const SizedBox(height: 24),

                            Consumer<AuthProvider>(
                              builder: (context, auth, _) => Column(
                                children: [
                                  if (auth.error != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text(auth.error!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 13))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  ElevatedButton(
                                    onPressed: auth.isLoading ? null : () => _handleAction(auth),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 54),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      backgroundColor: AppTheme.primaryColor,
                                    ),
                                    child: auth.isLoading
                                        ? const SizedBox(width: 24, height: 24,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : Text(
                                            _otpSent ? context.tr('verify') : context.tr('send_otp'),
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                          ),
                                  ),
                                  if (_otpSent) ...[
                                    const SizedBox(height: 12),
                                    TextButton(
                                      onPressed: () => setState(() => _otpSent = false),
                                      child: Text(context.tr('change_number'), style: const TextStyle(color: AppTheme.secondaryColor)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(context.tr('gov_footer'),
                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(height: 8),
                    Text('Version ${AppConstants.appVersion}',
                        style: const TextStyle(color: Colors.white24, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('mobile'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.primaryColor)),
        const SizedBox(height: 8),
        TextFormField(
          controller: _mobileController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          decoration: InputDecoration(
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: const Text('+91', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor)),
            ),
            hintText: '10-digit mobile number',
            suffixIcon: const Icon(Icons.phone_android_rounded, color: AppTheme.primaryColor),
          ),
          validator: (v) {
            if (v == null || v.length != 10) return context.tr('invalid_mobile_err');
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildOTPInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('enter_otp'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.primaryColor)),
        const SizedBox(height: 12),
        PinCodeTextField(
          appContext: context,
          length: 6,
          keyboardType: TextInputType.number,
          animationType: AnimationType.fade,
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(12),
            fieldHeight: 52,
            fieldWidth: 44,
            activeFillColor: AppTheme.primaryColor.withOpacity(0.08),
            inactiveFillColor: Colors.grey.shade50,
            selectedFillColor: AppTheme.primaryColor.withOpacity(0.12),
            activeColor: AppTheme.primaryColor,
            inactiveColor: Colors.grey.shade300,
            selectedColor: AppTheme.primaryColor,
          ),
          enableActiveFill: true,
          onChanged: (v) => _otp = v,
          onCompleted: (v) => _otp = v,
        ),
      ],
    );
  }

  Future<void> _handleAction(AuthProvider auth) async {
    if (!_otpSent) {
      if (!_formKey.currentState!.validate()) return;
      final success = await auth.sendOTP(_mobileController.text.trim());
      if (success) {
        setState(() => _otpSent = true);
      }
    } else {
      if (_otp.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('invalid_otp_err'))),
        );
        return;
      }
      final success = await auth.verifyOTP(_mobileController.text.trim(), _otp);
      if (success && mounted) {
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    }
  }
}
