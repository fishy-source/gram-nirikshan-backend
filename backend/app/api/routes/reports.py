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
from weasyprint import HTML
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

def build_pdf_report_pdfkit(inspection, panchayat, engineer, photos, approvals, output_path: str, lang: str = "en", current_user=None):
    """
    Renders HTML from Jinja templates and converts to PDF using wkhtmltopdf (via pdfkit).
    Works very well on Railway for both English and complex Hindi layout.
    """
    try:
        from app.core.config import settings
        env = Environment(loader=FileSystemLoader(str(find_project_root() / "backend" / "app" / "templates")))
    
        if lang == "hi":
            template = env.get_template("report_hi.html")
        else:
            template = env.get_template("report_en.html")
    
        # Ensure photo absolute paths are available
        for p in photos:
            abs_p = find_project_root() / p.file_path.lstrip("/")
            if abs_p.exists():
                # WeasyPrint accepts local file paths with file:// scheme
                p.absolute_path = "file://" + str(abs_p.absolute()).replace('\\', '/')
            else:
                p.absolute_path = ""
    
        map_img_path = ""
        if inspection.map_image_path:
            abs_map = find_project_root() / inspection.map_image_path.lstrip("/")
            if abs_map.exists():
                map_img_path = "file://" + str(abs_map.absolute()).replace('\\', '/')
    
        html_out = template.render(
            inspection=inspection,
            panchayat=panchayat,
            engineer_name=inspection.investigator_name or (engineer.name_hindi or engineer.name if engineer else "N/A"),
            photos=photos,
            approvals=approvals,
            map_image=map_img_path,
            ai_report_content=inspection.ai_report_draft or "",
            status_hi={"draft": "प्रारूप", "submitted": "प्रस्तुत", "forwarded": "अग्रेषित", "approved": "स्वीकृत", "rejected": "अस्वीकृत"}.get(inspection.status.value.lower(), inspection.status.value.upper()),
            current_user=current_user,
        )
    
        import tempfile
        import subprocess
        import os
        
        fd, temp_html = tempfile.mkstemp(suffix=".html")
        with open(temp_html, "w", encoding="utf-8") as f:
            f.write(html_out)
        os.close(fd)
        
        # Run WeasyPrint as a subprocess so a segfault/OOM won't kill the Uvicorn worker
        process = subprocess.run(
            ["weasyprint", "--base-url", str(find_project_root()), temp_html, output_path],
            capture_output=True,
            text=True
        )
        os.remove(temp_html)
        
        if process.returncode != 0:
            raise Exception(f"WeasyPrint subprocess failed: {process.stderr}")
    except Exception as e:
        import traceback
        err_msg = "".join(traceback.format_exception(type(e), e, e.__traceback__))
        import logging
        logging.getLogger(__name__).error(f"Template rendering or PDF generation failed: {err_msg}")
        raise HTTPException(status_code=500, detail=f"PDF generation failed: {err_msg}")


@router.post("/generate/{inspection_id}", response_model=MessageResponse)
async def generate_report(
    inspection_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
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

Ensure the report is professional, grammatically correct, and written in clear technical English suitable for senior administration.

CRITICAL: You MUST respond ONLY with a valid JSON object in the exact following format, without any markdown formatting or code blocks:
{
  "work_description_and_findings": "...",
  "deficiencies_identified": "...",
  "corrective_recommendations": "...",
  "conclusion": "..."
}"""
        ai_draft_en = await call_gemini(prompt, language="en")
        if ai_draft_en and not ai_draft_en.startswith("AI Error:"):
            inspection.ai_report_draft = ai_draft_en
            await db.flush()

    # Now generate the Hindi version of the AI Report based on the English context
    ai_report_draft_hi = ""
    if inspection.ai_report_draft:
        prompt_hi = f"""Translate the following professional Gram Panchayat inspection report from English to formal administrative Hindi (Devanagari).
Ensure the tone is suitable for senior government officials in Uttar Pradesh.

English Report (JSON format):
{inspection.ai_report_draft}

CRITICAL: You MUST respond ONLY with a valid JSON object in the exact following format, translated into formal Hindi. Do not use markdown code blocks:
{
  "work_description_and_findings": "...",
  "deficiencies_identified": "...",
  "corrective_recommendations": "...",
  "conclusion": "..."
}
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
        import json
        
        try:
            # Parse JSON
            ai_data_en = {}
            try:
                ai_data_en = json.loads(inspection.ai_report_draft.strip('`').strip('json\n')) if inspection.ai_report_draft else {}
            except Exception:
                # Fallback for old plain text
                ai_data_en = {"work_description_and_findings": inspection.ai_report_draft or ""}
                
            ai_data_hi = {}
            try:
                ai_data_hi = json.loads(ai_report_draft_hi.strip('`').strip('json\n')) if ai_report_draft_hi else {}
            except Exception:
                ai_data_hi = {"work_description_and_findings": ai_report_draft_hi or ""}
        except Exception as e:
            import traceback
            err_msg = "".join(traceback.format_exception(type(e), e, e.__traceback__))
            raise HTTPException(status_code=500, detail=f"JSON parsing failed: {err_msg}")

        # Temporarily pass the parsed dict instead of the raw string for the templates to use
        orig_draft = inspection.ai_report_draft
        
        # Build English PDF
        inspection.ai_report_draft = ai_data_en
        build_pdf_report_pdfkit(inspection, panchayat, engineer, list(photos), list(approvals), output_path_en, lang="en", current_user=current_user)
        
        # Build Hindi PDF
        inspection.ai_report_draft = ai_data_hi
        build_pdf_report_pdfkit(inspection, panchayat, engineer, list(photos), list(approvals), output_path_hi, lang="hi", current_user=current_user)
        
        # Restore original
        inspection.ai_report_draft = orig_draft

    except Exception as e:
        import logging
        logging.getLogger(__name__).error(f"WeasyPrint PDF generation failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"PDF generation failed: {str(e)}")

    try:
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
    except Exception as e:
        import traceback
        err_msg = "".join(traceback.format_exception(type(e), e, e.__traceback__))
        raise HTTPException(status_code=500, detail=f"Save failed: {err_msg}")

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

@router.get("/test-weasyprint")
async def test_weasyprint():
    from weasyprint import HTML
    import tempfile
    import os
    try:
        html = "<h1>Test</h1>"
        fd, temp_path = tempfile.mkstemp(suffix=".pdf")
        os.close(fd)
        HTML(string=html).write_pdf(temp_path)
        size = os.path.getsize(temp_path)
        os.remove(temp_path)
        return {"status": "success", "size": size}
    except Exception as e:
        return {"status": "error", "error": str(e)}
