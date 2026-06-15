import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/language_provider.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isHindi = context.watch<LanguageProvider>().isHindi;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Banner / Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF8C00), Color(0xFFD84315)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      image: const DecorationImage(
                        image: AssetImage('assets/images/yogi.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isHindi ? 'ग्राम पंचायत निरीक्षण' : 'Gram Panchayat Inspection',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isHindi ? 'उत्तर प्रदेश सरकार' : 'Government of Uttar Pradesh',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Instructions Section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi ? 'निरीक्षण के लिए आवश्यक निर्देश:' : 'Essential Instructions for Inspection:',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildInstructionItem(
                      icon: Icons.location_on_rounded,
                      title: isHindi ? 'साइट पर चेक-इन' : 'On-site Check-in',
                      description: isHindi
                          ? 'ग्राम पंचायत में पहुँचकर सबसे पहले ऐप में "चेक-इन" (Check-in) करें ताकि आपकी लोकेशन दर्ज हो सके।'
                          : 'Always check-in upon arriving at the Gram Panchayat to record your GPS location.',
                    ),
                    const SizedBox(height: 16),
                    _buildInstructionItem(
                      icon: Icons.camera_alt_rounded,
                      title: isHindi ? 'स्पष्ट तस्वीरें' : 'Clear Photographs',
                      description: isHindi
                          ? 'कार्यों की स्पष्ट और प्रामाणिक तस्वीरें लें। तस्वीरों में जगह का नाम (Watermark) अपने आप दर्ज हो जाएगा।'
                          : 'Take clear and authentic photos of the work. The location watermark will be added automatically.',
                    ),
                    const SizedBox(height: 16),
                    _buildInstructionItem(
                      icon: Icons.edit_document,
                      title: isHindi ? 'सटीक रिपोर्टिंग' : 'Accurate Reporting',
                      description: isHindi
                          ? 'निरीक्षण के दौरान पाई गई सभी कमियों और सुझावों को ईमानदारी से रिपोर्ट में दर्ज करें।'
                          : 'Honestly document all shortcomings and suggestions found during the inspection in the report.',
                    ),
                    const SizedBox(height: 16),
                    _buildInstructionItem(
                      icon: Icons.check_circle_rounded,
                      title: isHindi ? 'समय पर सबमिट करें' : 'Timely Submission',
                      description: isHindi
                          ? 'निरीक्षण पूरा होने के बाद रिपोर्ट को ड्राफ्ट (Draft) में न छोड़ें, उसे उसी दिन सबमिट (Submit) करें।'
                          : 'Do not leave the report in Draft. Submit it on the same day the inspection is completed.',
                    ),
                  ],
                ),
              ),
            ),
            
            // Proceed Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD84315),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    isHindi ? 'मैंने निर्देश पढ़ लिए हैं (Proceed)' : 'I Understand (Proceed)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem({required IconData icon, required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFD84315).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFFD84315), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
