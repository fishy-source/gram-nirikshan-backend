"""
PDF Report Generator using WeasyPrint and Jinja2.
Generates department-format inspection reports with complex text shaping support (Hindi).
"""
import asyncio
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from pathlib import Path
from datetime import datetime
import os
from xhtml2pdf import pisa
from io import BytesIO
from jinja2 import Environment, FileSystemLoader

from app.db.database import get_db
from app.models.models import Inspection, Panchayat, User, Photo, Approval, Report
from app.schemas.schemas import MessageResponse
from app.core.dependencies import get_current_user
from app.core.config import settings

router = APIRouter(prefix="/reports", tags=["Reports"])

REPORTS_DIR = Path(settings.UPLOAD_DIR) / "reports"
REPORTS_DIR.mkdir(parents=True, exist_ok=True)

def find_project_root() -> Path:
    current = Path(__file__).resolve().parent
    for _ in range(5):
        if (current / "flutter_app").exists():
            return current
        current = current.parent
    return Path(__file__).parents[3]

def get_absolute_path(rel_path: str) -> Path:
    path = Path(rel_path)
    if path.exists():
        return path
    root = find_project_root()
    path2 = root / rel_path
    if path2.exists():
        return path2
    path3 = root / "backend" / rel_path
    if path3.exists():
        return path3
    return path

def build_pdf_report_xhtml2pdf(inspection, panchayat, engineer, photos, approvals, output_path: str, lang: str = "en"):
    env = Environment(loader=FileSystemLoader(str(find_project_root() / "backend" / "app" / "templates")))
    template_name = "report_en.html" if lang == "en" else "report_hi.html"
    template = env.get_template(template_name)
    
    # Process photos to have absolute paths
    processed_photos = []
    for p in photos:
        if p.file_path:
            abs_p = get_absolute_path(p.file_path)
            if abs_p.exists():
                # WeasyPrint expects file:// URLs for absolute local paths on some platforms,
                # but Path(abs_p).as_uri() is safest.
                p.absolute_path = abs_p.as_uri()
                processed_photos.append(p)

    map_image_uri = None
    if inspection.map_image_path:
        map_abs = get_absolute_path(inspection.map_image_path)
        if map_abs.exists():
            map_image_uri = map_abs.as_uri()

    engineer_name = inspection.investigator_name or (engineer.name_hindi or engineer.name if engineer else "N/A")
    
    # Render HTML
    html_out = template.render(
        inspection=inspection,
        panchayat=panchayat,
        engineer_name=engineer_name,
        photos=processed_photos,
        approvals=approvals,
        map_image=map_image_uri,
        ai_report_content=inspection.ai_report_draft or "",
        status_hi={"draft": "प्रारूप", "submitted": "प्रस्तुत", "forwarded": "अग्रेषित", "approved": "स्वीकृत", "rejected": "अस्वीकृत"}.get(inspection.status.value.lower(), inspection.status.value.upper()),
    )
    
    # Generate PDF using xhtml2pdf
    with open(output_path, "wb") as pdf_file:
        pisa.CreatePDF(BytesIO(html_out.encode('utf-8')), dest=pdf_file)


@router.post("/generate/{inspection_id}", response_model=MessageResponse)
async def generate_report(
    inspection_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Generate both English and Hindi PDF reports using WeasyPrint."""
    result = await db.execute(select(Inspection).where(Inspection.id == inspection_id))
    inspection = result.scalar_one_or_none()
    if not inspection:
        raise HTTPException(status_code=404, detail="Inspection not found")

    result2 = await db.execute(select(Panchayat).where(Panchayat.id == inspection.panchayat_id))
    panchayat = result2.scalar_one_or_none()

    result3 = await db.execute(select(User).where(User.id == inspection.engineer_id))
    engineer = result3.scalar_one_or_none()

    result4 = await db.execute(select(Photo).where(Photo.inspection_id == inspection_id))
    photos = result4.scalars().all()

    result5 = await db.execute(
        select(Approval)
        .where(Approval.inspection_id == inspection_id)
        .options(selectinload(Approval.approver))
    )
    approvals = result5.scalars().all()

    # We will generate AI English Report first if missing
    from app.api.routes.ai import call_gemini
    
    if not inspection.ai_report_draft:
        prompt = f"""Draft a highly formal and professional Gram Panchayat inspection report (Inspection Memo) in English according to the standards of the Rural Development Department.

Inspection Details:
- Inspection ID: {inspection.inspection_id}
- Title: {inspection.title}
- Gram Panchayat: {panchayat.name if panchayat else 'N/A'}
- Inspector/Engineer: {inspection.investigator_name or (engineer.name if engineer else 'N/A')}
- Project/Work Name: {inspection.project_name or 'N/A'} (Work Code: {inspection.project_code or 'N/A'})

Observations / Notes:
{inspection.observations or 'Site inspection conducted.'}

Corrective Recommendations:
{inspection.recommendations or 'Appropriate corrective measures should be taken.'}

Draft the full English report under the following sections:
1. **Work Description & Key Findings (What was good)**
2. **Deficiencies / Issues Identified (What was lacking)**
3. **Corrective Actions / Recommendations (What can be resolved)**
4. **Conclusion**

Ensure the report is professional, grammatically correct, and written in clear technical English suitable for senior administration."""
        ai_draft_en = await call_gemini(prompt, language="en")
        if ai_draft_en and not ai_draft_en.startswith("AI Error:"):
            inspection.ai_report_draft = ai_draft_en
            await db.flush()

    # Now generate the Hindi version of the AI Report based on the English context
    ai_report_draft_hi = ""
    if inspection.ai_report_draft:
        prompt_hi = f"""Translate the following professional Gram Panchayat inspection report from English to formal administrative Hindi (Devanagari).
Ensure the tone is suitable for senior government officials in Uttar Pradesh.

English Report:
{inspection.ai_report_draft}
"""
        ai_draft_hi = await call_gemini(prompt_hi, language="hi")
        if ai_draft_hi and not ai_draft_hi.startswith("AI Error:"):
            ai_report_draft_hi = ai_draft_hi

    file_name_en = f"Report_EN_{inspection.inspection_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf"
    file_name_hi = f"Report_HI_{inspection.inspection_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf"
    
    output_path_en = str(REPORTS_DIR / file_name_en)
    output_path_hi = str(REPORTS_DIR / file_name_hi)

    # Translate the other UI fields for Hindi PDF dynamically, but keep the core English objects
    import copy
    
    try:
        # Build English PDF
        build_pdf_report_xhtml2pdf(inspection, panchayat, engineer, list(photos), list(approvals), output_path_en, lang="en")
        
        # Build Hindi PDF
        # Temporarily swap the AI draft with the Hindi translation
        orig_draft = inspection.ai_report_draft
        if ai_report_draft_hi:
            inspection.ai_report_draft = ai_report_draft_hi
            
        build_pdf_report_xhtml2pdf(inspection, panchayat, engineer, list(photos), list(approvals), output_path_hi, lang="hi")
        
        # Restore original
        inspection.ai_report_draft = orig_draft

    except Exception as e:
        import logging
        logging.getLogger(__name__).error(f"xhtml2pdf PDF generation failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"PDF generation failed: {str(e)}")

    # Save PDF report records
    file_size_en = Path(output_path_en).stat().st_size // 1024
    report_en = Report(
        inspection_id=inspection_id,
        generated_by=current_user.id,
        file_path=output_path_en,
        file_name=file_name_en,
        file_size_kb=file_size_en,
        report_format="pdf_en",
    )
    db.add(report_en)

    file_size_hi = Path(output_path_hi).stat().st_size // 1024
    report_hi = Report(
        inspection_id=inspection_id,
        generated_by=current_user.id,
        file_path=output_path_hi,
        file_name=file_name_hi,
        file_size_kb=file_size_hi,
        report_format="pdf_hi",
    )
    db.add(report_hi)

    await db.commit()

    return MessageResponse(
        message="Reports generated successfully",
        success=True,
        data={"file_name_en": file_name_en, "file_name_hi": file_name_hi},
    )


@router.get("/download/{inspection_id}")
async def download_report(
    inspection_id: str,
    format: str = "pdf_en",
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Download latest report PDF for an inspection (format: pdf_en or pdf_hi)."""
    # Fallback for old apps requesting 'pdf'
    if format == "pdf":
        format = "pdf_en"
        
    result = await db.execute(
        select(Report).where(Report.inspection_id == inspection_id)
        .where(Report.report_format == format)
        .order_by(Report.created_at.desc())
    )
    report = result.scalars().first()
    if not report or not Path(report.file_path).exists():
        raise HTTPException(status_code=404, detail=f"Report in {format} format not found. Generate it first.")

    return FileResponse(
        report.file_path,
        media_type="application/pdf",
        filename=report.file_name,
    )
