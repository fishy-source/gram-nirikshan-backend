"""
Inspection routes: CRUD, GPS check-in/out, status workflow, auto-ID generation.
"""
from fastapi import APIRouter, Depends, HTTPException, status, Query, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from sqlalchemy.orm import selectinload
from datetime import datetime, timezone
import math
from typing import Optional, List

from app.db.database import get_db
from app.models.models import (
    Inspection, InspectionStatus as DBStatus,
    Approval, ApprovalAction, Panchayat, User, Notification, NotificationType
)
from app.schemas.schemas import (
    InspectionCreate, InspectionUpdate, InspectionResponse,
    GPSCheckIn, GPSCheckOut, ApprovalCreate, ApprovalResponse, MessageResponse
)
from app.core.dependencies import get_current_user, require_engineer, require_approver
from app.core.config import settings

router = APIRouter(prefix="/inspections", tags=["Inspections"])


async def generate_inspection_id(db: AsyncSession) -> str:
    """Generate unique inspection ID: GN-YYYYMM-XXXXX"""
    now = datetime.now(timezone.utc)
    prefix = f"GN-{now.year}{now.month:02d}-"
    result = await db.execute(
        select(Inspection.inspection_id)
        .where(Inspection.inspection_id.like(f"{prefix}%"))
        .order_by(Inspection.inspection_id.desc())
        .limit(1)
    )
    max_id = result.scalar()
    if max_id:
        try:
            last_seq = int(max_id.split("-")[-1])
            next_seq = last_seq + 1
        except (ValueError, IndexError):
            next_seq = 1
    else:
        next_seq = 1
    return f"{prefix}{next_seq:05d}"


def calculate_distance(lat1, lon1, lat2, lon2) -> float:
    """Calculate Haversine distance in kilometers."""
    R = 6371
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


@router.get("/", response_model=List[InspectionResponse])
async def list_inspections(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    status: Optional[str] = None,
    panchayat_id: Optional[str] = None,
    engineer_id: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List inspections. Engineers see only their own; admins/approvers see all."""
    query = select(Inspection).options(
        selectinload(Inspection.panchayat),
        selectinload(Inspection.engineer),
        selectinload(Inspection.photos)
    )

    # Role-based filtering
    if current_user.role.value == "je":
        query = query.where(Inspection.engineer_id == current_user.id)

    if status:
        query = query.where(Inspection.status == status)
    if panchayat_id:
        query = query.where(Inspection.panchayat_id == panchayat_id)
    if engineer_id and current_user.role.value in ["admin", "ae", "xen"]:
        query = query.where(Inspection.engineer_id == engineer_id)

    query = query.order_by(Inspection.created_at.desc())
    query = query.offset((page - 1) * per_page).limit(per_page)

    result = await db.execute(query)
    inspections = result.scalars().all()
    return [InspectionResponse.model_validate(i) for i in inspections]


@router.post("/", response_model=InspectionResponse, status_code=201)
async def create_inspection(
    data: InspectionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_engineer()),
):
    """Create a new inspection (Draft status)."""
    panchayat_id = data.panchayat_id

    # If new_panchayat_name is provided, create a new Panchayat on-the-fly
    if data.new_panchayat_name and data.new_panchayat_name.strip():
        name = data.new_panchayat_name.strip()
        # Check if a panchayat with this name already exists in user's district/block to avoid duplicate
        existing_res = await db.execute(
            select(Panchayat).where(
                Panchayat.name == name,
                Panchayat.district == (current_user.district or "Hathras"),
                Panchayat.block == (current_user.block or "Hathras")
            )
        )
        existing_p = existing_res.scalar_one_or_none()
        if existing_p:
            panchayat_id = existing_p.id
        else:
            import uuid
            new_p = Panchayat(
                id=str(uuid.uuid4()),
                name=name,
                name_hindi=name,
                code=f"GP-{str(uuid.uuid4())[:8].upper()}",
                district=current_user.district or "Hathras",
                block=current_user.block or "Hathras",
                is_active=True
            )
            db.add(new_p)
            await db.flush()
            panchayat_id = new_p.id

    if not panchayat_id:
        raise HTTPException(status_code=400, detail="Panchayat ID or New Panchayat Name is required")

    # Validate panchayat exists
    result = await db.execute(select(Panchayat).where(Panchayat.id == panchayat_id))
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Panchayat not found")

    inspection_id = await generate_inspection_id(db)
    
    dump_data = data.model_dump()
    dump_data.pop("new_panchayat_name", None)
    dump_data["panchayat_id"] = panchayat_id

    inspection = Inspection(
        inspection_id=inspection_id,
        engineer_id=current_user.id,
        **dump_data,
    )
    db.add(inspection)
    await db.flush()
    
    # Eagerly load relationships to avoid greenlet lazy load errors in response validation
    result = await db.execute(
        select(Inspection)
        .where(Inspection.id == inspection.id)
        .options(
            selectinload(Inspection.panchayat),
            selectinload(Inspection.engineer),
            selectinload(Inspection.photos)
        )
    )
    db_inspection = result.scalar_one()
    return db_inspection


@router.get("/{inspection_id}", response_model=InspectionResponse)
async def get_inspection(
    inspection_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get inspection details by ID."""
    result = await db.execute(
        select(Inspection)
        .where(Inspection.id == inspection_id)
        .options(
            selectinload(Inspection.panchayat),
            selectinload(Inspection.engineer),
            selectinload(Inspection.photos)
        )
    )
    inspection = result.scalar_one_or_none()
    if not inspection:
        raise HTTPException(status_code=404, detail="Inspection not found")
    return inspection


@router.put("/{inspection_id}", response_model=InspectionResponse)
async def update_inspection(
    inspection_id: str,
    data: InspectionUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update inspection (only if Draft or Rejected)."""
    result = await db.execute(select(Inspection).where(Inspection.id == inspection_id))
    inspection = result.scalar_one_or_none()
    if not inspection:
        raise HTTPException(status_code=404, detail="Inspection not found")

    if inspection.engineer_id != current_user.id and current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Not authorized")

    if inspection.status not in [DBStatus.DRAFT, DBStatus.REJECTED]:
        raise HTTPException(status_code=400, detail="Can only edit Draft or Rejected inspections")

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(inspection, field, value)

    await db.flush()
    
    # Query fully loaded inspection
    res = await db.execute(
        select(Inspection)
        .where(Inspection.id == inspection.id)
        .options(
            selectinload(Inspection.panchayat),
            selectinload(Inspection.engineer),
            selectinload(Inspection.photos)
        )
    )
    return res.scalar_one()


@router.post("/{inspection_id}/submit", response_model=MessageResponse)
async def submit_inspection(
    inspection_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_engineer()),
):
    """Submit inspection for approval."""
    result = await db.execute(select(Inspection).where(Inspection.id == inspection_id))
    inspection = result.scalar_one_or_none()
    if not inspection:
        raise HTTPException(status_code=404, detail="Inspection not found")
    if inspection.engineer_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not your inspection")
    if inspection.status != DBStatus.DRAFT:
        raise HTTPException(status_code=400, detail="Only draft inspections can be submitted")

    inspection.status = DBStatus.SUBMITTED
    inspection.submitted_at = datetime.now(timezone.utc)

    # Create approval record
    approval = Approval(
        inspection_id=inspection.id,
        approver_id=current_user.id,
        level="JE",
        action=ApprovalAction.FORWARDED,
        remarks="Submitted for review",
    )
    db.add(approval)

    return MessageResponse(message="Inspection submitted successfully", success=True)


@router.post("/{inspection_id}/checkin", response_model=MessageResponse)
async def gps_checkin(
    inspection_id: str,
    data: GPSCheckIn,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_engineer()),
):
    """GPS Check-in for inspection."""
    result = await db.execute(select(Inspection).where(Inspection.id == inspection_id))
    inspection = result.scalar_one_or_none()
    if not inspection:
        raise HTTPException(status_code=404, detail="Inspection not found")
    if inspection.engineer_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    inspection.checkin_latitude = data.latitude
    inspection.checkin_longitude = data.longitude
    inspection.checkin_address = data.address
    inspection.checkin_time = datetime.now(timezone.utc)

    return MessageResponse(message="Checked in successfully", success=True,
                           data={"time": inspection.checkin_time.isoformat()})


@router.post("/{inspection_id}/checkout", response_model=MessageResponse)
async def gps_checkout(
    inspection_id: str,
    data: GPSCheckOut,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_engineer()),
):
    """GPS Check-out, calculates distance."""
    result = await db.execute(select(Inspection).where(Inspection.id == inspection_id))
    inspection = result.scalar_one_or_none()
    if not inspection:
        raise HTTPException(status_code=404, detail="Inspection not found")
    if inspection.engineer_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    inspection.checkout_latitude = data.latitude
    inspection.checkout_longitude = data.longitude
    inspection.checkout_address = data.address
    inspection.checkout_time = datetime.now(timezone.utc)

    # Calculate distance if check-in exists
    if inspection.checkin_latitude and inspection.checkin_longitude:
        inspection.distance_covered_km = calculate_distance(
            inspection.checkin_latitude, inspection.checkin_longitude,
            data.latitude, data.longitude,
        )

    return MessageResponse(
        message="Checked out successfully",
        success=True,
        data={"distance_km": inspection.distance_covered_km, "time": inspection.checkout_time.isoformat()},
    )


@router.post("/{inspection_id}/upload-map", response_model=InspectionResponse)
async def upload_map(
    inspection_id: str,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_engineer()),
):
    """Upload location map image for an inspection."""
    result = await db.execute(select(Inspection).where(Inspection.id == inspection_id))
    inspection = result.scalar_one_or_none()
    if not inspection:
        raise HTTPException(status_code=404, detail="Inspection not found")

    if file.content_type not in settings.ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=400, detail=f"Invalid file type: {file.content_type}")

    file_bytes = await file.read()
    if len(file_bytes) > settings.MAX_FILE_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=400, detail=f"File too large (max {settings.MAX_FILE_SIZE_MB}MB)")

    import uuid
    from pathlib import Path
    maps_dir = Path(settings.UPLOAD_DIR) / "maps"
    maps_dir.mkdir(parents=True, exist_ok=True)

    file_id = str(uuid.uuid4())
    file_path = maps_dir / f"{file_id}.jpg"

    with open(file_path, "wb") as f:
        f.write(file_bytes)

    inspection.map_image_path = f"uploads/maps/{file_id}.jpg"
    await db.flush()

    res = await db.execute(
        select(Inspection)
        .where(Inspection.id == inspection.id)
        .options(
            selectinload(Inspection.panchayat),
            selectinload(Inspection.engineer),
            selectinload(Inspection.photos)
        )
    )
    return res.scalar_one()


@router.post("/{inspection_id}/approve", response_model=MessageResponse)
async def approve_inspection(
    inspection_id: str,
    data: ApprovalCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_approver()),
):
    """Approve or reject an inspection."""
    result = await db.execute(select(Inspection).where(Inspection.id == inspection_id))
    inspection = result.scalar_one_or_none()
    if not inspection:
        raise HTTPException(status_code=404, detail="Inspection not found")

    if inspection.status not in [DBStatus.SUBMITTED, DBStatus.VERIFIED]:
        raise HTTPException(status_code=400, detail="Inspection cannot be approved in current status")

    level_map = {"ae": "AE", "xen": "XEN", "admin": "ADMIN"}
    level = level_map.get(current_user.role.value, "AE")

    approval = Approval(
        inspection_id=inspection.id,
        approver_id=current_user.id,
        level=level,
        action=data.action,
        remarks=data.remarks,
        forward_to=data.forward_to,
    )
    db.add(approval)

    # Update inspection status
    if data.action == ApprovalAction.APPROVED:
        inspection.status = DBStatus.APPROVED
        inspection.approved_at = datetime.now(timezone.utc)
        msg = "Inspection approved"
    elif data.action == ApprovalAction.REJECTED:
        inspection.status = DBStatus.REJECTED
        msg = "Inspection rejected"
    elif data.action == ApprovalAction.FORWARDED:
        inspection.status = DBStatus.VERIFIED
        msg = "Inspection forwarded to next level"
    else:
        msg = "Action recorded"

    return MessageResponse(message=msg, success=True)


@router.get("/{inspection_id}/approvals", response_model=List[ApprovalResponse])
async def get_inspection_approvals(
    inspection_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get approval history for an inspection."""
    result = await db.execute(
        select(Approval)
        .where(Approval.inspection_id == inspection_id)
        .options(selectinload(Approval.approver))
        .order_by(Approval.created_at)
    )
    approvals = result.scalars().all()
    return [ApprovalResponse.model_validate(a) for a in approvals]


@router.delete("/{inspection_id}", response_model=MessageResponse)
async def delete_inspection(
    inspection_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete an inspection. Restricted to Admin."""
    if current_user.role.value != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only Admin can delete inspections."
        )

    result = await db.execute(select(Inspection).where(Inspection.id == inspection_id))
    inspection = result.scalar_one_or_none()
    if not inspection:
        raise HTTPException(status_code=404, detail="Inspection not found")

    await db.delete(inspection)
    await db.commit()

    return MessageResponse(message="Inspection deleted successfully", success=True)
