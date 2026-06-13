// Data models for the Gram Nirikshan App

class UserModel {
  final String id;
  final String mobile;
  final String name;
  final String? nameHindi;
  final String? email;
  final String role;
  final String? employeeId;
  final String? designation;
  final String? department;
  final String? district;
  final String? block;
  final String? profilePhoto;
  final bool isActive;

  UserModel({
    required this.id,
    required this.mobile,
    required this.name,
    this.nameHindi,
    this.email,
    required this.role,
    this.employeeId,
    this.designation,
    this.department,
    this.district,
    this.block,
    this.profilePhoto,
    required this.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        mobile: json['mobile'],
        name: json['name'],
        nameHindi: json['name_hindi'],
        email: json['email'],
        role: json['role'],
        employeeId: json['employee_id'],
        designation: json['designation'],
        department: json['department'],
        district: json['district'],
        block: json['block'],
        profilePhoto: json['profile_photo'],
        isActive: json['is_active'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'mobile': mobile, 'name': name, 'name_hindi': nameHindi,
        'email': email, 'role': role, 'employee_id': employeeId,
        'designation': designation, 'department': department,
        'district': district, 'block': block,
        'profile_photo': profilePhoto, 'is_active': isActive,
      };

  bool get isAdmin => role == 'admin';
  bool get isJE => role == 'je';
  bool get isAE => role == 'ae';
  bool get isXEN => role == 'xen';
  bool get canApprove => role == 'ae' || role == 'xen' || role == 'admin';
}


class PanchayatModel {
  final String id;
  final String name;
  final String? nameHindi;
  final String? code;
  final String district;
  final String block;
  final String? village;
  final int? population;
  final double? latitude;
  final double? longitude;
  final String? sarpanchName;
  final String? sarpanchMobile;

  PanchayatModel({
    required this.id, required this.name, this.nameHindi, this.code,
    required this.district, required this.block, this.village,
    this.population, this.latitude, this.longitude,
    this.sarpanchName, this.sarpanchMobile,
  });

  factory PanchayatModel.fromJson(Map<String, dynamic> json) => PanchayatModel(
        id: json['id'], name: json['name'], nameHindi: json['name_hindi'],
        code: json['code'], district: json['district'], block: json['block'],
        village: json['village'], population: json['population'],
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        sarpanchName: json['sarpanch_name'], sarpanchMobile: json['sarpanch_mobile'],
      );
}


class InspectionModel {
  final String id;
  final String inspectionId;
  final String panchayatId;
  final String engineerId;
  final String status;
  final String title;
  final String? description;
  final String? inspectionType;
  final String? projectName;
  final String? projectCode;
  final double? checkinLatitude;
  final double? checkinLongitude;
  final DateTime? checkinTime;
  final String? checkinAddress;
  final double? checkoutLatitude;
  final double? checkoutLongitude;
  final DateTime? checkoutTime;
  final String? checkoutAddress;
  final double? distanceCoveredKm;
  final String? observations;
  final String? recommendations;
  final String? actionTaken;
  final String? aiReportDraft;
  final DateTime? inspectionDate;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final PanchayatModel? panchayat;
  final UserModel? engineer;
  final List<PhotoModel> photos;
  final String? investigatorName;
  final String? district;
  final String? block;
  final String? mapImagePath;

  InspectionModel({
    required this.id, required this.inspectionId, required this.panchayatId,
    required this.engineerId, required this.status, required this.title,
    this.description, this.inspectionType, this.projectName, this.projectCode,
    this.checkinLatitude, this.checkinLongitude, this.checkinTime, this.checkinAddress,
    this.checkoutLatitude, this.checkoutLongitude, this.checkoutTime, this.checkoutAddress,
    this.distanceCoveredKm, this.observations, this.recommendations, this.actionTaken,
    this.aiReportDraft,
    this.inspectionDate, this.submittedAt, this.approvedAt, required this.createdAt,
    this.panchayat, this.engineer, this.photos = const [],
    this.investigatorName, this.district, this.block, this.mapImagePath,
  });

  factory InspectionModel.fromJson(Map<String, dynamic> json) => InspectionModel(
        id: json['id'], inspectionId: json['inspection_id'],
        panchayatId: json['panchayat_id'], engineerId: json['engineer_id'],
        status: json['status'], title: json['title'],
        description: json['description'], inspectionType: json['inspection_type'],
        projectName: json['project_name'], projectCode: json['project_code'],
        checkinLatitude: (json['checkin_latitude'] as num?)?.toDouble(),
        checkinLongitude: (json['checkin_longitude'] as num?)?.toDouble(),
        checkinTime: json['checkin_time'] != null ? DateTime.parse(json['checkin_time']) : null,
        checkinAddress: json['checkin_address'],
        checkoutLatitude: (json['checkout_latitude'] as num?)?.toDouble(),
        checkoutLongitude: (json['checkout_longitude'] as num?)?.toDouble(),
        checkoutTime: json['checkout_time'] != null ? DateTime.parse(json['checkout_time']) : null,
        checkoutAddress: json['checkout_address'],
        distanceCoveredKm: (json['distance_covered_km'] as num?)?.toDouble(),
        observations: json['observations'], recommendations: json['recommendations'],
        actionTaken: json['action_taken'],
        aiReportDraft: json['ai_report_draft'],
        inspectionDate: json['inspection_date'] != null ? DateTime.parse(json['inspection_date']) : null,
        submittedAt: json['submitted_at'] != null ? DateTime.parse(json['submitted_at']) : null,
        approvedAt: json['approved_at'] != null ? DateTime.parse(json['approved_at']) : null,
        createdAt: DateTime.parse(json['created_at']),
        panchayat: json['panchayat'] != null ? PanchayatModel.fromJson(json['panchayat']) : null,
        engineer: json['engineer'] != null ? UserModel.fromJson(json['engineer']) : null,
        photos: (json['photos'] as List<dynamic>?)?.map((p) => PhotoModel.fromJson(p)).toList() ?? [],
        investigatorName: json['investigator_name'],
        district: json['district'],
        block: json['block'],
        mapImagePath: json['map_image_path'],
      );

  bool get isDraft => status == 'draft';
  bool get isCheckedIn => checkinTime != null && checkoutTime == null;
  String get statusLabel {
    const labels = {
      'draft': 'मसौदा', 'submitted': 'जमा किया', 'verified': 'सत्यापित',
      'approved': 'स्वीकृत', 'rejected': 'अस्वीकृत',
    };
    return labels[status] ?? status;
  }
}


class PhotoModel {
  final String id;
  final String filePath;
  final String? thumbnailPath;
  final double? latitude;
  final double? longitude;
  final DateTime? capturedAt;
  final String? caption;

  PhotoModel({
    required this.id, required this.filePath, this.thumbnailPath,
    this.latitude, this.longitude, this.capturedAt, this.caption,
  });

  factory PhotoModel.fromJson(Map<String, dynamic> json) => PhotoModel(
        id: json['id'], filePath: json['file_path'],
        thumbnailPath: json['thumbnail_path'],
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        capturedAt: json['captured_at'] != null ? DateTime.parse(json['captured_at']) : null,
        caption: json['caption'],
      );
}


class DashboardStats {
  final int totalInspections;
  final int draftCount;
  final int submittedCount;
  final int verifiedCount;
  final int approvedCount;
  final int rejectedCount;
  final int totalPanchayats;
  final int totalEngineers;
  final int thisMonthInspections;
  final int pendingApprovals;

  DashboardStats({
    required this.totalInspections, required this.draftCount,
    required this.submittedCount, required this.verifiedCount,
    required this.approvedCount, required this.rejectedCount,
    required this.totalPanchayats, required this.totalEngineers,
    required this.thisMonthInspections, required this.pendingApprovals,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        totalInspections: json['total_inspections'] ?? 0,
        draftCount: json['draft_count'] ?? 0,
        submittedCount: json['submitted_count'] ?? 0,
        verifiedCount: json['verified_count'] ?? 0,
        approvedCount: json['approved_count'] ?? 0,
        rejectedCount: json['rejected_count'] ?? 0,
        totalPanchayats: json['total_panchayats'] ?? 0,
        totalEngineers: json['total_engineers'] ?? 0,
        thisMonthInspections: json['this_month_inspections'] ?? 0,
        pendingApprovals: json['pending_approvals'] ?? 0,
      );
}

class ApprovalModel {
  final String id;
  final String inspectionId;
  final String approverId;
  final String level;
  final String action;
  final String? remarks;
  final DateTime createdAt;
  final UserModel? approver;

  ApprovalModel({
    required this.id,
    required this.inspectionId,
    required this.approverId,
    required this.level,
    required this.action,
    this.remarks,
    required this.createdAt,
    this.approver,
  });

  factory ApprovalModel.fromJson(Map<String, dynamic> json) => ApprovalModel(
        id: json['id'],
        inspectionId: json['inspection_id'],
        approverId: json['approver_id'],
        level: json['level'],
        action: json['action'],
        remarks: json['remarks'],
        createdAt: DateTime.parse(json['created_at']),
        approver: json['approver'] != null ? UserModel.fromJson(json['approver']) : null,
      );
}
