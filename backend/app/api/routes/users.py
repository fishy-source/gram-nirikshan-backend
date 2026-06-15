"""
User Management and CRUD operations with RBAC.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List

from app.db.database import get_db
from app.models.models import User, UserRole
from app.schemas.schemas import UserCreate, UserUpdate, UserResponse, MessageResponse
from app.core.dependencies import get_current_user

router = APIRouter(prefix="/users", tags=["Users"])

def require_superadmin_or_admin(current_user: User = Depends(get_current_user)):
    if current_user.role.value not in [UserRole.SUPERADMIN.value, UserRole.ADMIN.value]:
        raise HTTPException(status_code=403, detail="Only SuperAdmin or Admin can perform this action.")
    return current_user

@router.post("/", response_model=UserResponse, status_code=201)
async def create_user(
    data: UserCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_superadmin_or_admin)
):
    """Create a new user. Admins can only create Inspectors (JE). SuperAdmin can create anyone."""
    
    # RBAC logic
    if current_user.role.value == UserRole.ADMIN.value:
        if data.role != UserRole.INSPECTOR:
            raise HTTPException(status_code=403, detail="Admins can only create Inspectors (JE).")
        # Ensure they are in the same jurisdiction
        if current_user.district and data.district != current_user.district:
            raise HTTPException(status_code=403, detail="Admins can only create users within their district.")

    # Check for existing mobile
    result = await db.execute(select(User).where(User.mobile == data.mobile))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Mobile number already registered")

    new_user = User(**data.model_dump())
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    return new_user

@router.get("/", response_model=List[UserResponse])
async def list_users(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_superadmin_or_admin)
):
    """List all users. Admins see only users in their district."""
    query = select(User)
    
    if current_user.role.value == UserRole.ADMIN.value:
        if current_user.district:
            query = query.where(User.district == current_user.district)
            
    result = await db.execute(query)
    users = result.scalars().all()
    return [UserResponse.model_validate(u) for u in users]

@router.put("/{user_id}", response_model=UserResponse)
async def update_user(
    user_id: str,
    data: UserUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_superadmin_or_admin)
):
    """Update a user."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
        
    if current_user.role.value == UserRole.ADMIN.value:
        if user.role.value not in [UserRole.INSPECTOR.value, UserRole.VIEWER.value]:
            raise HTTPException(status_code=403, detail="Admins can only update lower roles.")
        if current_user.district and user.district != current_user.district:
            raise HTTPException(status_code=403, detail="Cannot update user outside jurisdiction.")

    for field, value in data.model_dump(exclude_none=True).items():
        setattr(user, field, value)

    await db.commit()
    await db.refresh(user)
    return user

@router.delete("/{user_id}", response_model=MessageResponse)
async def delete_user(
    user_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_superadmin_or_admin)
):
    """Delete a user. SuperAdmin only for Admins. Admins can delete JE."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if current_user.role.value == UserRole.ADMIN.value:
        if user.role.value != UserRole.INSPECTOR.value:
            raise HTTPException(status_code=403, detail="Admins can only delete Inspectors (JE).")

    await db.delete(user)
    try:
        await db.commit()
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Cannot delete user. They are linked to existing inspections or reports. Please block them instead.")
    return MessageResponse(message="User deleted successfully", success=True)
