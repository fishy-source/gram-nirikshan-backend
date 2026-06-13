import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  Locale _locale = const Locale('hi', 'IN');

  Locale get locale => _locale;

  bool get isHindi => _locale.languageCode == 'hi';

  LanguageProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('language_code') ?? 'hi';
      _locale = Locale(code, code == 'hi' ? 'IN' : 'US');
      notifyListeners();
    } catch (e) {
      // SharedPreferences might throw in test environments
      debugPrint('SharedPreferences load error: $e');
    }
  }

  Future<void> setLanguage(String languageCode) async {
    if (_locale.languageCode == languageCode) return;
    _locale = Locale(languageCode, languageCode == 'hi' ? 'IN' : 'US');
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', languageCode);
    } catch (e) {
      debugPrint('SharedPreferences save error: $e');
    }
  }

  // Dictionary helper for string translation
  String translate(String key) {
    if (isHindi) {
      return _hindiStrings[key] ?? key;
    } else {
      return _englishStrings[key] ?? key;
    }
  }

  static const Map<String, String> _hindiStrings = {
    // Bottom Nav & Titles
    'dashboard': 'डैशबोर्ड',
    'inspections': 'निरीक्षण',
    'ai_assistant': 'AI सहायक',
    'profile': 'प्रोफ़ाइल',
    'settings': 'सेटिंग्स',
    'cancel': 'रद्द करें',
    'copy': 'कॉपी करें',
    'share': 'शेयर करें',
    'delete': 'हटाएं',
    'delete_inspection': 'निरीक्षण हटाएं',
    'delete_confirm_title': 'निरीक्षण हटाने की पुष्टि',
    'delete_confirm_body': 'क्या आप वाकई इस निरीक्षण को हटाना चाहते हैं? यह क्रिया वापस नहीं ली जा सकती और इससे जुड़े सभी डेटा (फ़ोटो, मैप, पीडीएफ, अनुमोदन विवरण) भी हटा दिए जाएँगे।',
    'delete_success': 'निरीक्षण सफलतापूर्वक हटा दिया गया है',
    'delete_failed': 'निरीक्षण हटाने में विफल',

    // Dashboard
    'app_title': 'ग्राम निरीक्षण',
    'welcome_back': 'नमस्ते, {name}!',
    'quick_actions': 'त्वरित क्रियाएं',
    'recent_activity': 'हाल की गतिविधि',
    'tap_to_view_inspections': 'निरीक्षण सूची देखने के लिए यहाँ टैप करें',
    'total_inspections': 'कुल निरीक्षण',
    'this_month': 'इस माह',
    'approved': 'स्वीकृत',
    'submitted': 'जमा किया',
    'verified': 'सत्यापित',
    'rejected': 'अस्वीकृत',
    'draft': 'मसौदा',
    'pending': 'लंबित',
    'forwarded': 'अग्रेषित / जमा किया',
    'panchayats': 'ग्राम पंचायत',
    'engineers': 'अभियंता',
    'status_chart': 'निरीक्षण स्थिति',
    'new_inspection': 'नया निरीक्षण',
    'photo_upload': 'फ़ोटो अपलोड',
    'view_reports': 'रिपोर्ट देखें',
    'map': 'नक्शा',
    'calendar': 'कैलेंडर',

    // New Inspection Form
    'create_new_inspection': 'नया निरीक्षण बनाएं',
    'inspection_details': 'निरीक्षण का विवरण',
    'officer_name': 'जांचकर्ता का नाम',
    'district_name': 'जनपद का नाम (District)',
    'block_name': 'ब्लॉक का नाम (Block)',
    'select_panchayat': 'ग्राम पंचायत चुनें *',
    'manual_panchayat': 'ग्राम पंचायत का नाम (मैनुअल लिखें) *',
    'write_manual': 'मैनुअल नाम लिखें',
    'select_from_list': 'सूची से चुनें',
    'inspection_type': 'निरीक्षण का प्रकार',
    'inspection_title': 'निरीक्षण का शीर्षक (Title) *',
    'project_name': 'परियोजना का नाम (Project Name)',
    'project_code': 'परियोजना कोड (Project Code)',
    'inspection_date': 'निरीक्षण की तिथि',
    'select_date': 'तिथि चुनें',
    'description': 'विवरण / अतिरिक्त टिप्पणी (Description)',
    'inspection_photo': 'निरीक्षण फ़ोटो (ऑप्शनल)',
    'camera': 'कैमरा',
    'gallery': 'गैलरी',
    'no_photo_selected': 'कोई फोटो चुनी नहीं गई है',
    'gps_not_received': 'GPS स्थान प्राप्त नहीं हुआ',
    'gps_searching': 'GPS स्थान खोजा जा रहा है...',
    'gps_error': 'GPS त्रुटि',
    'photo_caption': 'फ़ोटो का शीर्षक / टिप्पणी (Caption)',
    'save_inspection': 'निरीक्षण सुरक्षित करें',
    'saving_inspection': 'निरीक्षण सेव हो गया। फ़ोटो अपलोड हो रही है...',
    'saved_successfully': 'नया निरीक्षण सफलतापूर्वक बनाया गया!',
    'panchayat_name_required': 'ग्राम पंचायत का नाम लिखना अनिवार्य है',
    'panchayat_select_required': 'ग्राम पंचायत चुनना अनिवार्य है',
    'title_required': 'शीर्षक लिखना अनिवार्य है',
    'please_select_panchayat': 'कृपया ग्राम पंचायत चुनें',
    'please_write_panchayat': 'कृपया ग्राम पंचायत का नाम लिखें',
    'inspection_location_map': 'निरीक्षण स्थान (नक्शा)',
    'inspection_photo_location': 'निरीक्षण/फ़ोटो स्थान',
    'gps_disabled': 'GPS बंद है',
    'gps_denied': 'GPS अनुमति अस्वीकृत',
    'gps_denied_forever': 'GPS अनुमति स्थायी रूप से अस्वीकृत',
    'photo_select_error': 'फोटो चुनने में त्रुटि',

    // Details Tab
    'draft_inspection': 'निरीक्षण मसौदा',
    'details_tab': 'विवरण',
    'gps_tab': 'GPS',
    'photos_tab': 'फ़ोटो',
    'approval_tab': 'अनुमोदन',
    'inspection_detail': 'निरीक्षण विवरण',
    'basic_info': 'बुनियादी जानकारी',
    'observations': 'अवलोकन (Observations)',
    'recommendations': 'सुझाव (Recommendations)',
    'action_taken': 'की गई कार्रवाई (Action Taken)',
    'ai_draft': 'AI द्वारा सुझाया गया मसौदा (AI Suggested Draft)',
    'set_to_observations': 'अवलोकन में सेट करें',
    'regenerate': 'पुनः जनरेट करें',
    'get_ai_draft': 'AI से रिपोर्ट का मसौदा तैयार करवाएं',
    'get_ai_draft_sub': 'यह आपके निरीक्षण डेटा, पंचायत और फ़ोटो के आधार पर विभाग-अनुकूल रिपोर्ट का मसौदा तैयार करेगा।',
    'generate_ai_report': 'AI (Gemini) से रिपोर्ट लिखवाएं',
    'gps_checkin': 'GPS चेक-इन करें',
    'gps_checkout': 'GPS चेक-इन विवरण',
    'gps_checkout_action': 'GPS चेक-आउट करें',
    'checkin_details': 'चेक-इन विवरण',
    'checkout_details': 'चेक-आउट विवरण',
    'photos': 'फ़ोटो',
    'no_photos': 'कोई फ़ोटो नहीं',
    'add_photo': 'फ़ोटो जोड़ें',
    'approval': 'अनुमोदन',
    'workflow_status': 'कार्यप्रवाह स्थिति',
    'approval_action': 'अनुमोदन कार्रवाई',
    'remarks': 'टिप्पणी',
    'approve': 'स्वीकार करें',
    'reject': 'अस्वीकार करें',
    'forward': 'आगे भेजें',
    'edit': 'संपादित करें',
    'submit': 'जमा करें',
    'pdf_report': 'PDF रिपोर्ट',
    'ai_generation_success': '✅ AI रिपोर्ट मसौदा सफलतापूर्वक तैयार हो गया!',
    'ai_generation_failed': '❌ AI जनरेशन विफल हुआ',
    'inspection_id': 'निरीक्षण ID',
    'approval_review_details': 'अनुमोदन एवं समीक्षा विवरण',
    'current_status': 'वर्तमान स्थिति (Status)',
    'sent_to': 'किसको भेजा गया है',
    'verification_approval': 'सत्यापन/स्वीकृति',
    'ae_pending': 'सहायक अभियंता (AE) - समीक्षा के लिए लंबित',
    'xen_pending': 'अधिशासी अभियंता (XEN) - समीक्षा के लिए लंबित',
    'officer_approved': 'अधिकारी द्वारा स्वीकृत (Approved)',
    'officer_rejected': 'अधिकारी द्वारा अस्वीकृत (Rejected)',
    'copy_to_observations': 'अवलोकन में कॉपी करें?',
    'copy_confirm': 'क्या आप इस AI रिपोर्ट मसौदे को अपने मुख्य अवलोकन (Observations) में कॉपी करना चाहते हैं?',
    'observations_update_success': '✅ अवलोकन सफलतापूर्वक अपडेट किया गया!',
    'update_failed': '❌ अपडेट विफल',
    'time': 'समय',
    'gps': 'GPS',
    'address': 'पता',
    'distance': 'दूरी',
    'checkin_success': '✅ चेक-इन सफल!',
    'checkout_success': '✅ चेक-आउट! दूरी: {distance} km',
    'enter_remarks_optional': 'टिप्पणी दर्ज करें (वैकल्पिक)',
    'submit_inspection_btn': 'निरीक्षण जमा करें',
    'submit_inspection_confirm_title': 'निरीक्षण जमा करें?',
    'submit_inspection_confirm_body': 'क्या आप इस निरीक्षण को अनुमोदन के लिए जमा करना चाहते हैं?',
    'submit_success': '✅ जमा सफल!',
    'submit_failed': '❌ जमा विफल',
    'pdf_ready': '✅ PDF रिपोर्ट तैयार!',
    'pdf_failed': '❌ रिपोर्ट विफल: {error}',
    'generate_pdf': 'PDF जनरेट करें',
    'view_on_map': 'मानचित्र पर देखें',
    'approval_history': 'समीक्षा एवं अनुमोदन इतिहास',
    'level': 'स्तर',
    'officer': 'अधिकारी',
    'unknown_officer': 'अज्ञात अधिकारी',
    'date': 'दिनांक',

    // List Screen
    'all': 'सभी',
    'search_inspection': 'निरीक्षण खोजें...',
    'no_inspections': 'कोई निरीक्षण नहीं',
    'add_button_instruction': 'नया निरीक्षण बनाने के लिए + बटन दबाएं',

    // Profile Screen
    'investigator_name_label': 'जांचकर्ता का नाम',
    'employee_id': 'कर्मचारी ID',
    'mobile': 'मोबाइल',
    'email': 'ईमेल',
    'district': 'जिला',
    'block': 'ब्लॉक',
    'logout': 'लॉगआउट',
    'share_app': 'ऐप शेयर करें',
    'share_app_text': 'ग्राम निरीक्षण ऐप (Gram Panchayat Inspection App) डाउनलोड करने के लिए इस लिंक पर जाएं: https://web-production-ccc50.up.railway.app/',

    // Reports Screen
    'view_inspection_reports': 'निरीक्षण रिपोर्ट देखें',
    'pdf_generated_success': 'निरीक्षण रिपोर्ट सफलतापूर्वक बनाई गई!',
    'preparing_report_share': 'रिपोर्ट तैयार करके शेयर की जा रही है...',
    'no_inspections_available': 'कोई निरीक्षण सूची उपलब्ध नहीं है',
    'downloading': 'डाउनलोड हो रहा है...',
    'generate_report': 'रिपोर्ट बनाएं',

    // Photo Upload Screen
    'select_inspection': 'निरीक्षण चुनें',
    'inspection_list_label': 'निरीक्षण सूची *',
    'photo_selection': 'फ़ोटो चयन',
    'additional_info_metadata': 'अतिरिक्त जानकारी (Metadata)',

    // Map Screen
    'inspection_map': 'निरीक्षण नक्शा',
    'view_details': 'विवरण देखें',

    // Calendar Screen
    'inspection_calendar': 'निरीक्षण कैलेंडर',
    'select_date_prompt': 'तारीख का चयन करें',
    'no_inspections_on_date': 'इस तारीख को कोई निरीक्षण नहीं है',

    // Login Screen
    'login': 'लॉगइन करें',
    'enter_mobile': 'अपना मोबाइल नंबर दर्ज करें',
    'verify': 'सत्यापित करें',
    'send_otp': 'OTP भेजें',
    'enter_otp': 'OTP दर्ज करें',
    'change_number': 'नंबर बदलें',
    'invalid_mobile_err': 'कृपया 10 अंकों का मोबाइल नंबर दर्ज करें',
    'invalid_otp_err': 'कृपया 6 अंकों का OTP दर्ज करें',
    'gov_footer': 'भारत सरकार | ग्राम विकास विभाग',
    'app_subtitle': 'ग्राम पंचायत निरीक्षण एवं निगरानी प्रणाली',

    // AI Assistant
    'ai_welcome': 'नमस्ते! मैं ग्राम निरीक्षण AI सहायक हूं 🙏\n\n'
        'आप मुझसे पूछ सकते हैं:\n'
        '• निरीक्षण कैसे करें?\n'
        '• रिपोर्ट कैसे लिखें?\n'
        '• सरकारी योजनाओं की जानकारी\n'
        '• तकनीकी सवाल\n\n'
        'हिंदी या अंग्रेजी में पूछें।',
    'ai_error_try_again': 'माफ़ करें, कोई त्रुटि हुई। कृपया पुनः प्रयास करें।',
    'view_docx_report': 'Word रिपोर्ट देखें',
    'downloading_docx': 'Word रिपोर्ट डाउनलोड हो रही है...',
    'sharing_docx': 'Word रिपोर्ट शेयर की जा रही है...',
  };

  static const Map<String, String> _englishStrings = {
    // Bottom Nav & Titles
    'dashboard': 'Dashboard',
    'inspections': 'Inspections',
    'ai_assistant': 'AI Assistant',
    'profile': 'Profile',
    'settings': 'Settings',
    'cancel': 'Cancel',
    'copy': 'Copy',
    'share': 'Share',
    'delete': 'Delete',
    'delete_inspection': 'Delete Inspection',
    'delete_confirm_title': 'Confirm Delete',
    'delete_confirm_body': 'Are you sure you want to delete this inspection? This action cannot be undone and will delete all associated data (photos, maps, pdf, approval details).',
    'delete_success': 'Inspection deleted successfully',
    'delete_failed': 'Failed to delete inspection',

    // Dashboard
    'app_title': 'Gram Nirikshan',
    'welcome_back': 'Hello, {name}!',
    'quick_actions': 'Quick Actions',
    'recent_activity': 'Recent Activity',
    'tap_to_view_inspections': 'Tap here to view inspections list',
    'total_inspections': 'Total Inspections',
    'this_month': 'This Month',
    'approved': 'Approved',
    'submitted': 'Submitted',
    'verified': 'Verified',
    'rejected': 'Rejected',
    'draft': 'Draft',
    'pending': 'Pending',
    'forwarded': 'Forwarded',
    'panchayats': 'Gram Panchayats',
    'engineers': 'Engineers',
    'status_chart': 'Inspection Status',
    'new_inspection': 'New Inspection',
    'photo_upload': 'Photo Upload',
    'view_reports': 'View Reports',
    'map': 'Map',
    'calendar': 'Calendar',

    // New Inspection Form
    'create_new_inspection': 'Create New Inspection',
    'inspection_details': 'Inspection Details',
    'officer_name': 'Investigator Name',
    'district_name': 'District Name',
    'block_name': 'Block Name',
    'select_panchayat': 'Select Gram Panchayat *',
    'manual_panchayat': 'Gram Panchayat Name (Write Manual) *',
    'write_manual': 'Write Manual Name',
    'select_from_list': 'Select from list',
    'inspection_type': 'Inspection Type',
    'inspection_title': 'Inspection Title *',
    'project_name': 'Project Name',
    'project_code': 'Project Code',
    'inspection_date': 'Inspection Date',
    'select_date': 'Select Date',
    'description': 'Description / Comments',
    'inspection_photo': 'Inspection Photo (Optional)',
    'camera': 'Camera',
    'gallery': 'Gallery',
    'no_photo_selected': 'No photo selected',
    'gps_not_received': 'GPS coordinates not received',
    'gps_searching': 'Fetching GPS coordinates...',
    'gps_error': 'GPS Error',
    'photo_caption': 'Photo Caption / Remarks',
    'save_inspection': 'Save Inspection',
    'saving_inspection': 'Inspection saved. Uploading photo...',
    'saved_successfully': 'New inspection created successfully!',
    'panchayat_name_required': 'Gram Panchayat name is required',
    'panchayat_select_required': 'Selecting a Gram Panchayat is required',
    'title_required': 'Title is required',
    'please_select_panchayat': 'Please select a Gram Panchayat',
    'please_write_panchayat': 'Please write a Gram Panchayat name',
    'inspection_location_map': 'Inspection Location (Map)',
    'inspection_photo_location': 'Inspection/Photo Location',
    'gps_disabled': 'GPS is disabled',
    'gps_denied': 'GPS permission denied',
    'gps_denied_forever': 'GPS permission permanently denied',
    'photo_select_error': 'Error selecting photo',

    // Details Tab
    'draft_inspection': 'Draft Inspection',
    'details_tab': 'Details',
    'gps_tab': 'GPS',
    'photos_tab': 'Photos',
    'approval_tab': 'Approval',
    'inspection_detail': 'Inspection Detail',
    'basic_info': 'Basic Information',
    'observations': 'Observations',
    'recommendations': 'Recommendations',
    'action_taken': 'Action Taken',
    'ai_draft': 'AI Suggested Draft',
    'set_to_observations': 'Set to Observations',
    'regenerate': 'Regenerate',
    'get_ai_draft': 'Draft Report with AI',
    'get_ai_draft_sub': 'This will draft a department-compliant report based on your inspection data, Panchayat, and photos.',
    'generate_ai_report': 'Write Report with AI (Gemini)',
    'gps_checkin': 'GPS Check-In',
    'gps_checkout': 'GPS Check-In Details',
    'gps_checkout_action': 'GPS Check-Out',
    'checkin_details': 'Check-In Details',
    'checkout_details': 'Check-Out Details',
    'photos': 'Photos',
    'no_photos': 'No photos',
    'add_photo': 'Add Photo',
    'approval': 'Approval',
    'workflow_status': 'Workflow Status',
    'approval_action': 'Approval Actions',
    'remarks': 'Remarks',
    'approve': 'Approve',
    'reject': 'Reject',
    'forward': 'Forward',
    'edit': 'Edit',
    'submit': 'Submit',
    'pdf_report': 'PDF Report',
    'ai_generation_success': '✅ AI report draft generated successfully!',
    'ai_generation_failed': '❌ AI generation failed',
    'inspection_id': 'Inspection ID',
    'approval_review_details': 'Approval & Review Details',
    'current_status': 'Current Status',
    'sent_to': 'Forwarded To',
    'verification_approval': 'Verification / Approval',
    'ae_pending': 'Assistant Engineer (AE) - Pending Review',
    'xen_pending': 'Executive Engineer (XEN) - Pending Review',
    'officer_approved': 'Approved by Officer',
    'officer_rejected': 'Rejected by Officer',
    'copy_to_observations': 'Copy to Observations?',
    'copy_confirm': 'Do you want to copy this AI report draft to your main Observations?',
    'observations_update_success': '✅ Observations updated successfully!',
    'update_failed': '❌ Update failed',
    'time': 'Time',
    'gps': 'GPS',
    'address': 'Address',
    'distance': 'Distance',
    'checkin_success': '✅ Check-in successful!',
    'checkout_success': '✅ Checked out! Distance: {distance} km',
    'enter_remarks_optional': 'Enter remarks (optional)',
    'submit_inspection_btn': 'Submit Inspection',
    'submit_inspection_confirm_title': 'Submit Inspection?',
    'submit_inspection_confirm_body': 'Are you sure you want to submit this inspection for approval?',
    'submit_success': '✅ Submission successful!',
    'submit_failed': '❌ Submission failed',
    'pdf_ready': '✅ PDF Report ready!',
    'pdf_failed': '❌ PDF Report failed: {error}',
    'generate_pdf': 'Generate PDF',
    'view_on_map': 'View on Map',
    'approval_history': 'Approval History',
    'level': 'Level',
    'officer': 'Officer',
    'unknown_officer': 'Unknown Officer',
    'date': 'Date',

    // List Screen
    'all': 'All',
    'search_inspection': 'Search Inspections...',
    'no_inspections': 'No inspections found',
    'add_button_instruction': 'Tap + button to create a new inspection',

    // Profile Screen
    'investigator_name_label': 'Investigator Name',
    'employee_id': 'Employee ID',
    'mobile': 'Mobile',
    'email': 'Email',
    'district': 'District',
    'block': 'Block',
    'logout': 'Logout',
    'share_app': 'Share App',
    'share_app_text': 'Go to this link to download Gram Nirikshan App (Gram Panchayat Inspection App): https://web-production-ccc50.up.railway.app/',

    // Reports Screen
    'view_inspection_reports': 'View Inspection Reports',
    'pdf_generated_success': 'Inspection report generated successfully!',
    'preparing_report_share': 'Preparing report for sharing...',
    'no_inspections_available': 'No inspection list available',
    'downloading': 'Downloading...',
    'generate_report': 'Generate Report',

    // Photo Upload Screen
    'select_inspection': 'Select Inspection',
    'inspection_list_label': 'Inspection List *',
    'photo_selection': 'Photo Selection',
    'additional_info_metadata': 'Additional Info (Metadata)',

    // Map Screen
    'inspection_map': 'Inspection Map',
    'view_details': 'View Details',

    // Calendar Screen
    'inspection_calendar': 'Inspection Calendar',
    'select_date_prompt': 'Select a date',
    'no_inspections_on_date': 'No inspections on this date',

    // Login Screen
    'login': 'Login',
    'enter_mobile': 'Enter your mobile number',
    'verify': 'Verify',
    'send_otp': 'Send OTP',
    'enter_otp': 'Enter OTP',
    'change_number': 'Change Number',
    'invalid_mobile_err': 'Please enter a valid 10-digit mobile number',
    'invalid_otp_err': 'Please enter a valid 6-digit OTP',
    'gov_footer': 'Govt of India | Rural Development Dept',
    'app_subtitle': 'Gram Panchayat Inspection & Monitoring System',

    // AI Assistant
    'ai_welcome': 'Hello! I am your Gram Nirikshan AI Assistant 🙏\n\n'
        'You can ask me about:\n'
        '• How to conduct an inspection?\n'
        '• How to write reports?\n'
        '• Information on govt schemes\n'
        '• Technical questions\n\n'
        'Ask in Hindi or English.',
    'ai_error_try_again': 'Sorry, an error occurred. Please try again.',
    'view_docx_report': 'View Word Report',
    'downloading_docx': 'Downloading Word report...',
    'sharing_docx': 'Sharing Word report...',
  };
}

extension TranslationExtension on BuildContext {
  String tr(String key) {
    return watch<LanguageProvider>().translate(key);
  }
}
