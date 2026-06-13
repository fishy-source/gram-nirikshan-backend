// Inspection Provider - manages inspection state

import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import '../../data/models/models.dart';

class InspectionProvider with ChangeNotifier {
  final _api = ApiService();

  List<InspectionModel> _inspections = [];
  InspectionModel? _selectedInspection;
  List<PanchayatModel> _panchayats = [];
  List<ApprovalModel> _approvals = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  String? _filterStatus;

  List<InspectionModel> get inspections => _inspections;
  InspectionModel? get selectedInspection => _selectedInspection;
  List<PanchayatModel> get panchayats => _panchayats;
  List<ApprovalModel> get approvals => _approvals;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  Future<void> loadInspections({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      _inspections = [];
      _currentPage = 1;
      _hasMore = true;
    }
    if (!_hasMore) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.getInspections(
        page: _currentPage,
        status: _filterStatus,
      );
      final items = (response.data as List).map((j) => InspectionModel.fromJson(j)).toList();
      if (items.length < 20) _hasMore = false;
      _inspections.addAll(items);
      _currentPage++;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(String? status) {
    _filterStatus = status;
    loadInspections(refresh: true);
  }

  Future<InspectionModel?> loadInspectionDetail(String id) async {
    try {
      final response = await _api.getInspection(id);
      _selectedInspection = InspectionModel.fromJson(response.data);
      notifyListeners();
      return _selectedInspection;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<InspectionModel?> createInspection(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.createInspection(data);
      final inspection = InspectionModel.fromJson(response.data);
      _inspections.insert(0, inspection);
      _isLoading = false;
      notifyListeners();
      return inspection;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateInspection(String id, Map<String, dynamic> data) async {
    try {
      final response = await _api.updateInspection(id, data);
      final updated = InspectionModel.fromJson(response.data);
      final idx = _inspections.indexWhere((i) => i.id == id);
      if (idx >= 0) _inspections[idx] = updated;
      if (_selectedInspection?.id == id) _selectedInspection = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteInspection(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _api.deleteInspection(id);
      _inspections.removeWhere((i) => i.id == id);
      if (_selectedInspection?.id == id) _selectedInspection = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitInspection(String id) async {
    try {
      await _api.submitInspection(id);
      await loadInspectionDetail(id);
      loadInspections(refresh: true);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> checkIn(String id, double lat, double lng, String? address) async {
    try {
      final r = await _api.checkIn(id, lat, lng, address);
      await loadInspectionDetail(id);
      return r.data;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> checkOut(String id, double lat, double lng, String? address) async {
    try {
      final r = await _api.checkOut(id, lat, lng, address);
      await loadInspectionDetail(id);
      return r.data;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> approveInspection(String id, String action, String? remarks, String? forwardTo) async {
    try {
      await _api.approveInspection(id, action, remarks, forwardTo);
      await loadInspectionDetail(id);
      loadInspections(refresh: true);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadPanchayats() async {
    try {
      final response = await _api.getPanchayats();
      _panchayats = (response.data as List).map((j) => PanchayatModel.fromJson(j)).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<List<ApprovalModel>> loadApprovalHistory(String id) async {
    try {
      final response = await _api.getInspectionApprovals(id);
      _approvals = (response.data as List).map((j) => ApprovalModel.fromJson(j)).toList();
      notifyListeners();
      return _approvals;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<bool> suggestAIReport(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _api.suggestReport(id);
      await loadInspectionDetail(id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
