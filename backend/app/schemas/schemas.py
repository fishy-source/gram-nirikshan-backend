"""
Pydantic schemas (request/response DTOs) for the Gram Nirikshan API.
"""
from pydantic import BaseModel, EmailStr, field_validator, model_validator
from typing import Optional, List, Any
from datetime import datetime
from enum import Enum


# ─── Enums ─────────────────────────────────────────────────────────────────────

class UserRole(str, Enum):
    ADMIN = "admin"
    JE = "je"
    AE = "ae"
    XEN = "xen"
    VIEWER = "viewer"


class InspectionStatus(str, Enum):
    DRAFT = "draft"
    SUBMITTED = "submitted"
    VERIFIED = "verified"
    APPROVED = "approved"
    REJECTED = "rejected"


class ApprovalAction(str, Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    FORWARDED = "forwarded"


# ─── Auth Schemas ──────────────────────────────────────────────────────────────

class SendOTPRequest(BaseModel):
    mobile: str

    @field_validator("mobile")
    @classmethod
    def validate_mobile(cls, v):
        v = v.strip().replace(" ", "").replace("-", "")
        if v.startswith("+91"):
            v = v[3:]
        if not v.isdigit() or len(v) != 10:
            raise ValueError("Invalid Indian mobile number (10 digits required)")
        return v


class VerifyOTPRequest(BaseModel):
    mobile: str
    otp: str

    @field_validator("mobile")
    @classmethod
    def validate_mobile(cls, v):
        v = v.strip().replace(" ", "")
        if v.startswith("+91"):
            v = v[3:]
        return v


class UserResponse(BaseModel):
    id: str
    mobile: str
    name: str
    name_hindi: Optional[str] = None
    email: Optional[str] = None
    role: UserRole
    employee_id: Optional[str] = None
    designation: Optional[str] = None
    department: Optional[str] = None
    district: Optional[str] = None
    block: Optional[str] = None
    profile_photo: Optional[str] = None
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    user: UserResponse


class RefreshTokenRequest(BaseModel):
    refresh_token: str


# ─── User Schemas ──────────────────────────────────────────────────────────────

class UserCreate(BaseModel):
    mobile: str
    name: str
    name_hindi: Optional[str] = None
    email: Optional[EmailStr] = None
    role: UserRole = UserRole.JE
    employee_id: Optional[str] = None
    designation: Optional[str] = None
    department: Optional[str] = None
    district: Optional[str] = None
    block: Optional[str] = None


class UserUpdate(BaseModel):
    name: Optional[str] = None
    name_hindi: Optional[str] = None
    email: Optional[EmailStr] = None
    designation: Optional[str] = None
    department: Optional[str] = None
    district: Optional[str] = None
    block: Optional[str] = None
    firebase_token: Optional[str] = None
    is_active: Optional[bool] = None


# ─── Panchayat Schemas ─────────────────────────────────────────────────────────

class PanchayatCreate(BaseModel):
    name: str
    name_hindi: Optional[str] = None
    code: Optional[str] = None
    district: str
    block: str
    village: Optional[str] = None
    population: Optional[int] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    sarpanch_name: Optional[str] = None
    sarpanch_mobile: Optional[str] = None


class PanchayatUpdate(BaseModel):
    name: Optional[str] = None
    name_hindi: Optional[str] = None
    district: Optional[str] = None
    block: Optional[str] = None
    village: Optional[str] = None
    population: Optional[int] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    sarpanch_name: Optional[str] = None
    sarpanch_mobile: Optional[str] = None
    is_active: Optional[bool] = None


class PanchayatResponse(BaseModel):
    id: str
    name: str
    name_hindi: Optional[str] = None
    code: Optional[str] = None
    district: str
    block: str
    village: Optional[str] = None
    population: Optional[int] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    sarpanch_name: Optional[str] = None
    sarpanch_mobile: Optional[str] = None
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


# ─── Inspection Schemas ────────────────────────────────────────────────────────

class InspectionCreate(BaseModel):
    panchayat_id: str
    title: str
    description: Optional[str] = None
    inspection_type: Optional[str] = None
    project_name: Optional[str] = None
    project_code: Optional[str] = None
    inspection_date: Optional[datetime] = None


class InspectionUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    inspection_type: Optional[str] = None
    project_name: Optional[str] = None
    project_code: Optional[str] = None
    observations: Optional[str] = None
    recommendations: Optional[str] = None
    action_taken: Optional[str] = None
    inspection_date: Optional[datetime] = None


class GPSCheckIn(BaseModel):
    latitude: float
    longitude: float
    address: Optional[str] = None


class GPSCheckOut(BaseModel):
    latitude: float
    longitude: float
    address: Optional[str] = None


class PhotoResponse(BaseModel):
    id: str
    file_path: str
    thumbnail_path: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    captured_at: Optional[datetime] = None
    caption: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class InspectionResponse(BaseModel):
    id: str
    inspection_id: str
    panchayat_id: str
    engineer_id: str
    status: InspectionStatus
    title: str
    description: Optional[str] = None
    inspection_type: Optional[str] = None
    project_name: Optional[str] = None
    project_code: Optional[str] = None
    checkin_latitude: Optional[float] = None
    checkin_longitude: Optional[float] = None
    checkin_time: Optional[datetime] = None
    checkout_time: Optional[datetime] = None
    distance_covered_km: Optional[float] = None
    observations: Optional[str] = None
    recommendations: Optional[str] = None
    action_taken: Optional[str] = None
    inspection_date: Optional[datetime] = None
    submitted_at: Optional[datetime] = None
    approved_at: Optional[datetime] = None
    created_at: datetime
    panchayat: Optional[PanchayatResponse] = None
    engineer: Optional[UserResponse] = None
    photos: List[PhotoResponse] = []

    class Config:
        from_attributes = True


# ─── Approval Schemas ──────────────────────────────────────────────────────────

class ApprovalCreate(BaseModel):
    action: ApprovalAction
    remarks: Optional[str] = None
    forward_to: Optional[str] = None  # user_id to forward to


class ApprovalResponse(BaseModel):
    id: str
    inspection_id: str
    approver_id: str
    level: str
    action: ApprovalAction
    remarks: Optional[str] = None
    created_at: datetime
    approver: Optional[UserResponse] = None

    class Config:
        from_attributes = True


# ─── Dashboard Schemas ─────────────────────────────────────────────────────────

class DashboardStats(BaseModel):
    total_inspections: int
    draft_count: int
    submitted_count: int
    verified_count: int
    approved_count: int
    rejected_count: int
    total_panchayats: int
    total_engineers: int
    this_month_inspections: int
    pending_approvals: int


class EngineerPerformance(BaseModel):
    engineer_id: str
    engineer_name: str
    total_inspections: int
    approved_inspections: int
    pending_inspections: int
    rejected_inspections: int


# ─── AI Schemas ────────────────────────────────────────────────────────────────

class AIChatRequest(BaseModel):
    message: str
    inspection_id: Optional[str] = None
    language: str = "hi"  # hi or en


class AIChatResponse(BaseModel):
    response: str
    suggestions: Optional[List[str]] = None


class AIReportSuggestion(BaseModel):
    inspection_id: str


# ─── Notification Schemas ──────────────────────────────────────────────────────

class NotificationResponse(BaseModel):
    id: str
    title: str
    body: Optional[str] = None
    notification_type: str
    reference_id: Optional[str] = None
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True


# ─── Generic Response ──────────────────────────────────────────────────────────

class MessageResponse(BaseModel):
    message: str
    success: bool = True
    data: Optional[Any] = None


class PaginatedResponse(BaseModel):
    items: List[Any]
    total: int
    page: int
    per_page: int
    total_pages: int
