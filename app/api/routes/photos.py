"""
Photo upload route with watermark overlay using Pillow.
Generates watermarked images with GPS, timestamp, engineer name, and panchayat name.
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from PIL import Image, ImageDraw, ImageFont, ImageEnhance
from datetime import datetime, timezone
from pathlib import Path
import io, os, uuid, aiofiles
from typing import Optional

from app.db.database import get_db
from app.models.models import Photo, Inspection, Panchayat, User
from app.schemas.schemas import PhotoResponse, MessageResponse
from app.core.dependencies import get_current_user, require_engineer
from app.core.config import settings

router = APIRouter(prefix="/photos", tags=["Photos"])

UPLOAD_DIR = Path(settings.UPLOAD_DIR) / "photos"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
THUMBNAIL_DIR = UPLOAD_DIR / "thumbnails"
THUMBNAIL_DIR.mkdir(parents=True, exist_ok=True)


def add_watermark(image: Image.Image, watermark_text: str) -> Image.Image:
    """Add multi-line watermark text to image bottom."""
    # Enhance image slightly
    img = image.convert("RGBA")
    width, height = img.size

    # Create overlay for watermark background
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    lines = watermark_text.split("\n")
    font_size = max(16, width // 40)

    try:
        font = ImageFont.truetype("arial.ttf", font_size)
        small_font = ImageFont.truetype("arial.ttf", font_size - 4)
    except:
        font = ImageFont.load_default()
        small_font = font

    line_height = font_size + 6
    padding = 12
    bar_height = len(lines) * line_height + padding * 2

    # Semi-transparent dark bar at bottom
    draw.rectangle(
        [(0, height - bar_height), (width, height)],
        fill=(0, 0, 0, 180)
    )

    # Write each line
    y = height - bar_height + padding
    for i, line in enumerate(lines):
        f = font if i == 0 else small_font
        draw.text((padding, y), line, font=f, fill=(255, 255, 255, 255))
        y += line_height

    # Composite
    img = Image.alpha_composite(img, overlay)
    return img.convert("RGB")


async def process_and_save_photo(
    file_bytes: bytes,
    engineer_name: str,
    panchayat_name: str,
    latitude: Optional[float],
    longitude: Optional[float],
    caption: Optional[str] = None,
) -> tuple[str, str, int]:
    """Process image: resize, compress, watermark. Returns (file_path, thumb_path, size_kb)."""
    img = Image.open(io.BytesIO(file_bytes))

    # Auto-rotate based on EXIF
    try:
        from PIL import ExifTags
        exif = img._getexif()
        if exif:
            for tag, value in exif.items():
                if ExifTags.TAGS.get(tag) == "Orientation":
                    rotations = {3: 180, 6: 270, 8: 90}
                    if value in rotations:
                        img = img.rotate(rotations[value], expand=True)
                    break
    except:
        pass

    # Resize: max 1920px width
    max_w = 1920
    if img.width > max_w:
        ratio = max_w / img.width
        img = img.resize((max_w, int(img.height * ratio)), Image.LANCZOS)

    # Build watermark text
    now = datetime.now(timezone.utc)
    gps_str = f"GPS: {latitude:.6f}, {longitude:.6f}" if latitude and longitude else "GPS: N/A"
    wm_text = "\n".join([
        f"Gram Nirikshan | {panchayat_name}",
        f"Engineer: {engineer_name}",
        gps_str,
        f"Date: {now.strftime('%d/%m/%Y %H:%M')} IST",
        caption or "",
    ]).strip()

    img = add_watermark(img, wm_text)

    # Save full image
    file_id = str(uuid.uuid4())
    file_path = UPLOAD_DIR / f"{file_id}.jpg"
    img.save(str(file_path), "JPEG", quality=85, optimize=True)

    # Save thumbnail
    thumb = img.copy()
    thumb.thumbnail((400, 400))
    thumb_path = THUMBNAIL_DIR / f"{file_id}_thumb.jpg"
    thumb.save(str(thumb_path), "JPEG", quality=70)

    size_kb = file_path.stat().st_size // 1024
    return str(file_path), str(thumb_path), size_kb


@router.post("/upload/{inspection_id}", response_model=PhotoResponse, status_code=201)
async def upload_photo(
    inspection_id: str,
    file: UploadFile = File(...),
    latitude: Optional[float] = Form(None),
    longitude: Optional[float] = Form(None),
    caption: Optional[str] = Form(None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(require_engineer()),
):
    """Upload and watermark a photo for an inspection."""
    # Validate inspection
    result = await db.execute(select(Inspection).where(Inspection.id == inspection_id))
    inspection = result.scalar_one_or_none()
    if not inspection:
        raise HTTPException(status_code=404, detail="Inspection not found")

    # Validate file type
    if file.content_type not in settings.ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=400, detail=f"Invalid file type: {file.content_type}")

    # Check file size
    file_bytes = await file.read()
    if len(file_bytes) > settings.MAX_FILE_SIZE_MB * 1024 * 1024:
        raise HTTPException(status_code=400, detail=f"File too large (max {settings.MAX_FILE_SIZE_MB}MB)")

    # Get panchayat name
    result2 = await db.execute(select(Panchayat).where(Panchayat.id == inspection.panchayat_id))
    panchayat = result2.scalar_one_or_none()
    panchayat_name = (panchayat.name_hindi or panchayat.name) if panchayat else "Unknown"

    # Get dynamic engineer/investigator name
    engineer_name = inspection.investigator_name or current_user.name_hindi or current_user.name

    # Process photo
    file_path, thumb_path, size_kb = await process_and_save_photo(
        file_bytes, engineer_name, panchayat_name, latitude, longitude, caption
    )

    # Save DB record
    photo = Photo(
        inspection_id=inspection_id,
        file_path=file_path,
        thumbnail_path=thumb_path,
        original_filename=file.filename,
        file_size_kb=size_kb,
        mime_type="image/jpeg",
        latitude=latitude,
        longitude=longitude,
        captured_at=datetime.now(timezone.utc),
        engineer_name=engineer_name,
        panchayat_name=panchayat_name,
        caption=caption,
    )
    db.add(photo)
    await db.flush()
    await db.refresh(photo)
    return PhotoResponse.model_validate(photo)


@router.get("/{inspection_id}", response_model=list)
async def get_photos(
    inspection_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get all photos for an inspection."""
    result = await db.execute(
        select(Photo).where(Photo.inspection_id == inspection_id).order_by(Photo.created_at)
    )
    photos = result.scalars().all()
    return [PhotoResponse.model_validate(p) for p in photos]


@router.delete("/{photo_id}", response_model=MessageResponse)
async def delete_photo(
    photo_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a photo."""
    result = await db.execute(select(Photo).where(Photo.id == photo_id))
    photo = result.scalar_one_or_none()
    if not photo:
        raise HTTPException(status_code=404, detail="Photo not found")

    # Delete files
    for path in [photo.file_path, photo.thumbnail_path]:
        if path and Path(path).exists():
            os.remove(path)

    await db.delete(photo)
    return MessageResponse(message="Photo deleted", success=True)
