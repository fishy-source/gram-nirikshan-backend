// App Constants & API Configuration

class AppConstants {
  // API Base URL - Change for production
  static const String baseUrl = 'https://web-production-ccc50.up.railway.app/api/v1';
  // For production: static const String baseUrl = 'https://api.gramnirikshan.in/api/v1';

  // App Info
  static const String appName = 'Gram Nirikshan';
  static const String appNameHindi = 'ग्राम निरीक्षण';
  static const String appVersion = '1.0.0';

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String themeKey = 'app_theme';
  static const String languageKey = 'app_language';

  // Inspection Types
  static const List<String> inspectionTypes = [
    'Road & Infrastructure',
    'Water Supply & Sanitation',
    'Public Buildings',
    'Pradhan Mantri Gram Sadak Yojana',
    'MGNREGA Works',
    'Swachh Bharat Mission',
    'Jal Jeevan Mission',
    'PM Awas Yojana (Gramin)',
    'Street Lighting',
    'Drainage System',
    'Community Hall',
    'Health & Education',
    'General Inspection',
  ];

  // Hindi Labels
  static const Map<String, String> statusLabels = {
    'draft': 'मसौदा',
    'submitted': 'जमा किया',
    'verified': 'सत्यापित',
    'approved': 'स्वीकृत',
    'rejected': 'अस्वीकृत',
  };

  static const Map<String, String> roleLabels = {
    'admin': 'प्रशासक',
    'je': 'कनिष्ठ अभियंता (JE)',
    'ae': 'सहायक अभियंता (AE)',
    'xen': 'कार्यपालक अभियंता (XEN)',
    'viewer': 'दर्शक',
  };

  // File Limits
  static const int maxFileSizeMB = 10;
  static const int maxPhotosPerInspection = 50;

  // Map defaults
  static const double defaultLat = 26.8467;
  static const double defaultLng = 80.9462;
  static const double defaultZoom = 14.0;

  // Timeouts
  static const int connectionTimeoutSecs = 30;
  static const int receiveTimeoutSecs = 60;
}
