"""
Dashboard analytics and user management routes.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from datetime import datetime, timezone, timedelta
from typing import List

from app.db.database import get_db
from app.models.models import Inspection, InspectionStatus, User, Panchayat, Approval, Photo
from app.schemas.schemas import DashboardStats, EngineerPerformance, UserCreate, UserUpdate, UserResponse, MessageResponse
from app.core.dependencies import get_current_user, require_admin, require_roles
from app.models.models import UserRole

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("/stats", response_model=DashboardStats)
async def get_dashboard_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get dashboard statistics. Engineers see their own, admins see all."""
    is_engineer = current_user.role == UserRole.JE

    # Build base filter
    def insp_filter(status=None):
        conditions = []
        if is_engineer:
            conditions.append(Inspection.engineer_id == current_user.id)
        if status:
            conditions.append(Inspection.status == status)
        return and_(*conditions) if conditions else True

    async def count_insp(status=None):
        q = select(func.count(Inspection.id)).where(insp_filter(status))
        r = await db.execute(q)
        return r.scalar() or 0

    # This month
    now = datetime.now(timezone.utc)
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    month_q = select(func.count(Inspection.id))
    if is_engineer:
        month_q = month_q.where(Inspection.engineer_id == current_user.id)
    month_q = month_q.where(Inspection.created_at >= month_start)
    month_r = await db.execute(month_q)
    this_month = month_r.scalar() or 0

    # Pending approvals for current user
    pending_q = select(func.count(Approval.id)).where(
        Approval.approver_id == current_user.id,
        Approval.action == "pending"
    )
    pending_r = await db.execute(pending_q)
    pending_approvals = pending_r.scalar() or 0

    # Total panchayats
    total_panchayats_q = await db.execute(select(func.count(Panchayat.id)))
    total_panchayats = total_panchayats_q.scalar() or 0

    # Total engineers
    total_engineers_q = await db.execute(select(func.count(User.id)).where(User.role == UserRole.JE))
    total_engineers = total_engineers_q.scalar() or 0

    return DashboardStats(
        total_inspections=await count_insp(),
        draft_count=await count_insp(InspectionStatus.DRAFT),
        submitted_count=await count_insp(InspectionStatus.SUBMITTED),
        verified_count=await count_insp(InspectionStatus.VERIFIED),
        approved_count=await count_insp(InspectionStatus.APPROVED),
        rejected_count=await count_insp(InspectionStatus.REJECTED),
        total_panchayats=total_panchayats,
        total_engineers=total_engineers,
        this_month_inspections=this_month,
        pending_approvals=pending_approvals,
    )


@router.get("/engineer-performance", response_model=List[EngineerPerformance])
async def get_engineer_performance(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get engineer performance metrics (admin/AE/XEN only)."""
    if current_user.role not in [UserRole.ADMIN, UserRole.AE, UserRole.XEN]:
        raise HTTPException(status_code=403, detail="Access denied")

    engineers_q = await db.execute(select(User).where(User.role == UserRole.JE, User.is_active == True))
    engineers = engineers_q.scalars().all()

    results = []
    for eng in engineers:
        async def count(status=None):
            q = select(func.count(Inspection.id)).where(Inspection.engineer_id == eng.id)
            if status:
                q = q.where(Inspection.status == status)
            r = await db.execute(q)
            return r.scalar() or 0

        results.append(EngineerPerformance(
            engineer_id=eng.id,
            engineer_name=eng.name,
            total_inspections=await count(),
            approved_inspections=await count(InspectionStatus.APPROVED),
            pending_inspections=await count(InspectionStatus.SUBMITTED),
            rejected_inspections=await count(InspectionStatus.REJECTED),
        ))

    return results


# ─── User Management (Admin) ───────────────────────────────────────────────────
user_router = APIRouter(prefix="/users", tags=["Users"])


@user_router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    """Get current user profile."""
    return UserResponse.model_validate(current_user)


@user_router.get("/", response_model=List[UserResponse])
async def list_users(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_roles(UserRole.ADMIN, UserRole.AE, UserRole.XEN)),
):
    result = await db.execute(select(User).order_by(User.name))
    return [UserResponse.model_validate(u) for u in result.scalars().all()]


@user_router.post("/", response_model=UserResponse, status_code=201)
async def create_user(
    data: UserCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin()),
):
    """Admin: create a new user."""
    existing = await db.execute(select(User).where(User.mobile == data.mobile))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Mobile number already registered")

    user = User(**data.model_dump())
    db.add(user)
    await db.flush()
    await db.refresh(user)
    return UserResponse.model_validate(user)


@user_router.put("/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: str,
    data: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update user (admin can update any, user can update self)."""
    if current_user.id != user_id and current_user.role != UserRole.ADMIN:
        raise HTTPException(status_code=403, detail="Access denied")

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(user, field, value)
    await db.flush()
    await db.refresh(user)
    return UserResponse.model_validate(user)


@user_router.delete("/{user_id}", response_model=MessageResponse)
async def delete_user(
    user_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin()),
):
    """Admin: deactivate (soft delete) a user."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.is_active = False
    return MessageResponse(message="User deactivated", success=True)


# ─── Panchayat Routes ──────────────────────────────────────────────────────────
panchayat_router = APIRouter(prefix="/panchayats", tags=["Panchayats"])

from app.schemas.schemas import PanchayatCreate, PanchayatUpdate, PanchayatResponse


@panchayat_router.get("/", response_model=List[PanchayatResponse])
async def list_panchayats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Panchayat).where(Panchayat.is_active == True).order_by(Panchayat.name))
    return [PanchayatResponse.model_validate(p) for p in result.scalars().all()]


@panchayat_router.post("/", response_model=PanchayatResponse, status_code=201)
async def create_panchayat(
    data: PanchayatCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin()),
):
    panchayat = Panchayat(**data.model_dump())
    db.add(panchayat)
    await db.flush()
    await db.refresh(panchayat)
    return PanchayatResponse.model_validate(panchayat)


@panchayat_router.put("/{panchayat_id}", response_model=PanchayatResponse)
async def update_panchayat(
    panchayat_id: str,
    data: PanchayatUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_admin()),
):
    result = await db.execute(select(Panchayat).where(Panchayat.id == panchayat_id))
    panchayat = result.scalar_one_or_none()
    if not panchayat:
        raise HTTPException(status_code=404, detail="Panchayat not found")
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(panchayat, field, value)
    await db.flush()
    await db.refresh(panchayat)
    return PanchayatResponse.model_validate(panchayat)
