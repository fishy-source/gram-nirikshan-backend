"""
SQLAlchemy models for all database tables in Gram Nirikshan App.
"""
from sqlalchemy import (
    Column, String, Integer, Float, Boolean, DateTime, Text,
    ForeignKey, Enum, BigInteger, JSON
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum
import uuid
from app.db.database import Base


def generate_uuid():
    return str(uuid.uuid4())


# ─── Enums ─────────────────────────────────────────────────────────────────────

class UserRole(str, enum.Enum):
    ADMIN = "admin"
    JE = "je"        # Junior Engineer
    AE = "ae"        # Assistant Engineer
    XEN = "xen"      # Executive Engineer
    VIEWER = "viewer"


class InspectionStatus(str, enum.Enum):
    DRAFT = "draft"
    SUBMITTED = "submitted"
    VERIFIED = "verified"
    APPROVED = "approved"
    REJECTED = "rejected"


class ApprovalAction(str, enum.Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    FORWARDED = "forwarded"


class DocumentType(str, enum.Enum):
    PDF = "pdf"
    IMAGE = "image"
    EXCEL = "excel"
    OTHER = "other"


class NotificationType(str, enum.Enum):
    INSPECTION_SUBMITTED = "inspection_submitted"
    INSPECTION_APPROVED = "inspection_approved"
    INSPECTION_REJECTED = "inspection_rejected"
    INSPECTION_FORWARDED = "inspection_forwarded"
    REMINDER = "reminder"
    SYSTEM = "system"


# ─── User Model ────────────────────────────────────────────────────────────────

class User(Base):
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    mobile = Column(String(15), unique=True, nullable=False, index=True)
    name = Column(String(100), nullable=False)
    name_hindi = Column(String(200), nullable=True)
    email = Column(String(100), unique=True, nullable=True)
    role = Column(Enum(UserRole), nullable=False, default=UserRole.JE)
    employee_id = Column(String(50), unique=True, nullable=True)
    designation = Column(String(100), nullable=True)
    department = Column(String(100), nullable=True)
    district = Column(String(100), nullable=True)
    block = Column(String(100), nullable=True)
    profile_photo = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True)
    firebase_token = Column(String(255), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    inspections = relationship("Inspection", back_populates="engineer", foreign_keys="Inspection.engineer_id")
    approvals_given = relationship("Approval", back_populates="approver", foreign_keys="Approval.approver_id")
    notifications = relationship("Notification", back_populates="user")


# ─── OTP Model ─────────────────────────────────────────────────────────────────

class OTPRecord(Base):
    __tablename__ = "otp_records"

    id = Column(Integer, primary_key=True, autoincrement=True)
    mobile = Column(String(15), nullable=False, index=True)
    otp = Column(String(10), nullable=False)
    is_used = Column(Boolean, default=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


# ─── Panchayat Model ───────────────────────────────────────────────────────────

class Panchayat(Base):
    __tablename__ = "panchayats"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    name = Column(String(200), nullable=False)
    name_hindi = Column(String(300), nullable=True)
    code = Column(String(20), unique=True, nullable=True)
    district = Column(String(100), nullable=False)
    block = Column(String(100), nullable=False)
    village = Column(String(200), nullable=True)
    population = Column(Integer, nullable=True)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    sarpanch_name = Column(String(100), nullable=True)
    sarpanch_mobile = Column(String(15), nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    inspections = relationship("Inspection", back_populates="panchayat")


# ─── Inspection Model ──────────────────────────────────────────────────────────

class Inspection(Base):
    __tablename__ = "inspections"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    inspection_id = Column(String(30), unique=True, nullable=False)  # Auto-generated
    panchayat_id = Column(String(36), ForeignKey("panchayats.id"), nullable=False)
    engineer_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    status = Column(Enum(InspectionStatus), default=InspectionStatus.DRAFT, index=True)

    # Inspection Details
    title = Column(String(300), nullable=False)
    description = Column(Text, nullable=True)
    inspection_type = Column(String(100), nullable=True)
    project_name = Column(String(300), nullable=True)
    project_code = Column(String(50), nullable=True)

    # GPS Data
    checkin_latitude = Column(Float, nullable=True)
    checkin_longitude = Column(Float, nullable=True)
    checkin_time = Column(DateTime(timezone=True), nullable=True)
    checkin_address = Column(String(500), nullable=True)
    checkout_latitude = Column(Float, nullable=True)
    checkout_longitude = Column(Float, nullable=True)
    checkout_time = Column(DateTime(timezone=True), nullable=True)
    checkout_address = Column(String(500), nullable=True)
    distance_covered_km = Column(Float, nullable=True)

    # Observations
    observations = Column(Text, nullable=True)
    recommendations = Column(Text, nullable=True)
    action_taken = Column(Text, nullable=True)

    # AI Generated Content
    ai_report_draft = Column(Text, nullable=True)
    ai_suggestions = Column(JSON, nullable=True)

    # Timestamps
    inspection_date = Column(DateTime(timezone=True), nullable=True)
    submitted_at = Column(DateTime(timezone=True), nullable=True)
    approved_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    panchayat = relationship("Panchayat", back_populates="inspections")
    engineer = relationship("User", back_populates="inspections", foreign_keys=[engineer_id])
    photos = relationship("Photo", back_populates="inspection", cascade="all, delete-orphan")
    documents = relationship("Document", back_populates="inspection", cascade="all, delete-orphan")
    reports = relationship("Report", back_populates="inspection")
    approvals = relationship("Approval", back_populates="inspection", order_by="Approval.created_at")


# ─── Photo Model ───────────────────────────────────────────────────────────────

class Photo(Base):
    __tablename__ = "photos"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    inspection_id = Column(String(36), ForeignKey("inspections.id"), nullable=False)
    file_path = Column(String(500), nullable=False)
    thumbnail_path = Column(String(500), nullable=True)
    original_filename = Column(String(255), nullable=True)
    file_size_kb = Column(Integer, nullable=True)
    mime_type = Column(String(50), nullable=True)

    # Watermark Data
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    captured_at = Column(DateTime(timezone=True), nullable=True)
    engineer_name = Column(String(100), nullable=True)
    panchayat_name = Column(String(200), nullable=True)
    address = Column(String(500), nullable=True)
    caption = Column(String(500), nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    inspection = relationship("Inspection", back_populates="photos")


# ─── Document Model ────────────────────────────────────────────────────────────

class Document(Base):
    __tablename__ = "documents"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    inspection_id = Column(String(36), ForeignKey("inspections.id"), nullable=True)
    uploaded_by = Column(String(36), ForeignKey("users.id"), nullable=False)
    document_type = Column(Enum(DocumentType), nullable=False)
    file_path = Column(String(500), nullable=False)
    original_filename = Column(String(255), nullable=False)
    file_size_kb = Column(Integer, nullable=True)
    mime_type = Column(String(100), nullable=True)
    description = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    inspection = relationship("Inspection", back_populates="documents")


# ─── Report Model ──────────────────────────────────────────────────────────────

class Report(Base):
    __tablename__ = "reports"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    inspection_id = Column(String(36), ForeignKey("inspections.id"), nullable=False)
    generated_by = Column(String(36), ForeignKey("users.id"), nullable=False)
    file_path = Column(String(500), nullable=False)
    file_name = Column(String(255), nullable=False)
    file_size_kb = Column(Integer, nullable=True)
    report_format = Column(String(20), default="pdf")
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    inspection = relationship("Inspection", back_populates="reports")


# ─── Approval Model ────────────────────────────────────────────────────────────

class Approval(Base):
    __tablename__ = "approvals"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    inspection_id = Column(String(36), ForeignKey("inspections.id"), nullable=False)
    approver_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    level = Column(String(10), nullable=False)  # JE, AE, XEN
    action = Column(Enum(ApprovalAction), default=ApprovalAction.PENDING)
    remarks = Column(Text, nullable=True)
    forward_to = Column(String(36), ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    inspection = relationship("Inspection", back_populates="approvals")
    approver = relationship("User", back_populates="approvals_given", foreign_keys=[approver_id])


# ─── Notification Model ────────────────────────────────────────────────────────

class Notification(Base):
    __tablename__ = "notifications"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=False)
    title = Column(String(200), nullable=False)
    body = Column(Text, nullable=True)
    notification_type = Column(Enum(NotificationType), nullable=False)
    reference_id = Column(String(36), nullable=True)  # inspection_id or other
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    user = relationship("User", back_populates="notifications")
