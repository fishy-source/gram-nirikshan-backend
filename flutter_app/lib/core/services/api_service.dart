// API Service using Dio HTTP Client
// Handles all backend communication with auth token injection

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  void initialize() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: AppConstants.connectionTimeoutSecs),
      receiveTimeout: const Duration(seconds: AppConstants.receiveTimeoutSecs),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.accessTokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Try to refresh token
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry original request
            final token = await _storage.read(key: AppConstants.accessTokenKey);
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.request(
              error.requestOptions.path,
              options: Options(
                method: error.requestOptions.method,
                headers: error.requestOptions.headers,
              ),
              data: error.requestOptions.data,
            );
            return handler.resolve(response);
          }
        }
        return handler.next(error);
      },
    ));

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) return false;

      final response = await Dio().post(
        '${AppConstants.baseUrl}/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        await _storage.write(
          key: AppConstants.accessTokenKey,
          value: response.data['access_token'],
        );
        await _storage.write(
          key: AppConstants.refreshTokenKey,
          value: response.data['refresh_token'],
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<Response> sendOtp(String mobile) =>
      _dio.post('/auth/send-otp', data: {'mobile': mobile});

  Future<Response> verifyOtp(String mobile, String otp) =>
      _dio.post('/auth/verify-otp', data: {'mobile': mobile, 'otp': otp});

  // ── Dashboard ─────────────────────────────────────────────────────────────

  Future<Response> getDashboardStats() => _dio.get('/dashboard/stats');
  Future<Response> getEngineerPerformance() => _dio.get('/dashboard/engineer-performance');

  // ── Users ─────────────────────────────────────────────────────────────────

  Future<Response> getMe() => _dio.get('/users/me');
  Future<Response> getUsers() => _dio.get('/users/');
  Future<Response> createUser(Map<String, dynamic> data) => _dio.post('/users/', data: data);
  Future<Response> updateUser(String id, Map<String, dynamic> data) => _dio.put('/users/$id', data: data);
  Future<Response> deleteUser(String id) => _dio.delete('/users/$id');

  // ── Panchayats ────────────────────────────────────────────────────────────

  Future<Response> getPanchayats() => _dio.get('/panchayats/');
  Future<Response> createPanchayat(Map<String, dynamic> data) => _dio.post('/panchayats/', data: data);
  Future<Response> updatePanchayat(String id, Map<String, dynamic> data) => _dio.put('/panchayats/$id', data: data);

  // ── Inspections ───────────────────────────────────────────────────────────

  Future<Response> getInspections({int page = 1, String? status, String? panchayatId}) =>
      _dio.get('/inspections/', queryParameters: {
        'page': page,
        if (status != null) 'status': status,
        if (panchayatId != null) 'panchayat_id': panchayatId,
      });

  Future<Response> createInspection(Map<String, dynamic> data) =>
      _dio.post('/inspections/', data: data);

  Future<Response> getInspection(String id) => _dio.get('/inspections/$id');

  Future<Response> updateInspection(String id, Map<String, dynamic> data) =>
      _dio.put('/inspections/$id', data: data);

  Future<Response> submitInspection(String id) =>
      _dio.post('/inspections/$id/submit');

  Future<Response> checkIn(String id, double lat, double lng, String? address) =>
      _dio.post('/inspections/$id/checkin', data: {
        'latitude': lat, 'longitude': lng, 'address': address,
      });

  Future<Response> checkOut(String id, double lat, double lng, String? address) =>
      _dio.post('/inspections/$id/checkout', data: {
        'latitude': lat, 'longitude': lng, 'address': address,
      });

  Future<Response> approveInspection(String id, String action, String? remarks, String? forwardTo) =>
      _dio.post('/inspections/$id/approve', data: {
        'action': action,
        if (remarks != null) 'remarks': remarks,
        if (forwardTo != null) 'forward_to': forwardTo,
      });

  // ── Photos ────────────────────────────────────────────────────────────────

  Future<Response> uploadPhoto({
    required String inspectionId,
    required String filePath,
    double? latitude,
    double? longitude,
    String? caption,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filePath.split('/').last),
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
      if (caption != null) 'caption': caption,
    });
    return _dio.post('/photos/upload/$inspectionId', data: formData);
  }

  Future<Response> getPhotos(String inspectionId) => _dio.get('/photos/$inspectionId');
  Future<Response> deletePhoto(String photoId) => _dio.delete('/photos/$photoId');

  // ── Reports ───────────────────────────────────────────────────────────────

  Future<Response> generateReport(String inspectionId) =>
      _dio.post('/reports/generate/$inspectionId');

  Future<String> getReportDownloadUrl(String inspectionId) =>
      Future.value('${AppConstants.baseUrl}/reports/download/$inspectionId');

  // ── AI ────────────────────────────────────────────────────────────────────

  Future<Response> aiChat(String message, {String? inspectionId, String language = 'hi'}) =>
      _dio.post('/ai/chat', data: {
        'message': message,
        if (inspectionId != null) 'inspection_id': inspectionId,
        'language': language,
      });

  Future<Response> suggestReport(String inspectionId) =>
      _dio.post('/ai/suggest-report', data: {'inspection_id': inspectionId});

  Future<Response> getInspectionApprovals(String inspectionId) =>
      _dio.get('/inspections/$inspectionId/approvals');

  Future<Response> inspectionGuide(String type, {String language = 'hi'}) =>
      _dio.post('/ai/inspection-guide', queryParameters: {'inspection_type': type, 'language': language});

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<Response> getNotifications() => _dio.get('/notifications/');
}
