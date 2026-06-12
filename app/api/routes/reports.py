"""
PDF Report Generator using ReportLab.
Generates department-format inspection reports with photos, GPS data, and approval trail.
"""
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm, inch
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    Image as RLImage, HRFlowable, KeepTogether
)
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from pathlib import Path
from datetime import datetime, timezone
import uuid, os

from app.db.database import get_db
from app.models.models import Inspection, Panchayat, User, Photo, Approval, Report
from app.schemas.schemas import MessageResponse
from app.core.dependencies import get_current_user
from app.core.config import settings

router = APIRouter(prefix="/reports", tags=["Reports"])

REPORTS_DIR = Path(settings.UPLOAD_DIR) / "reports"
REPORTS_DIR.mkdir(parents=True, exist_ok=True)

# Color scheme
PRIMARY = colors.HexColor("#1a5276")
SECONDARY = colors.HexColor("#2e86c1")
ACCENT = colors.HexColor("#f39c12")
LIGHT_BG = colors.HexColor("#eaf2fb")
DARK_BG = colors.HexColor("#154360")


def build_pdf_report(inspection, panchayat, engineer, photos, approvals, output_path: str):
    """Build a full PDF inspection report."""
    doc = SimpleDocTemplate(
        output_path,
        pagesize=A4,
        leftMargin=2*cm, rightMargin=2*cm,
        topMargin=2.5*cm, bottomMargin=2*cm,
    )

    styles = getSampleStyleSheet()
    story = []

    # ── Header ────────────────────────────────────────────────
    title_style = ParagraphStyle(
        "Title", fontSize=18, textColor=PRIMARY,
        alignment=TA_CENTER, fontName="Helvetica-Bold", spaceAfter=4
    )
    subtitle_style = ParagraphStyle(
        "Subtitle", fontSize=11, textColor=SECONDARY,
        alignment=TA_CENTER, fontName="Helvetica", spaceAfter=2
    )
    normal = ParagraphStyle("Normal2", fontSize=10, fontName="Helvetica", spaceAfter=4)
    label = ParagraphStyle("Label", fontSize=10, fontName="Helvetica-Bold", textColor=PRIMARY)

    story.append(Paragraph(settings.DEPARTMENT_NAME_EN, title_style))
    story.append(Paragraph("INSPECTION REPORT", subtitle_style))
    story.append(Paragraph(f"Report ID: {inspection.inspection_id}", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=2, color=PRIMARY, spaceAfter=12))

    # ── Basic Information ──────────────────────────────────────
    info_data = [
        ["Inspection ID", inspection.inspection_id, "Status", inspection.status.value.upper()],
        ["Engineer", engineer.name if engineer else "N/A", "Designation", engineer.designation or "N/A"],
        ["Panchayat", panchayat.name if panchayat else "N/A", "District", panchayat.district if panchayat else "N/A"],
        ["Block", panchayat.block if panchayat else "N/A", "Village", panchayat.village or "N/A"],
        ["Inspection Date", str(inspection.inspection_date)[:10] if inspection.inspection_date else "N/A",
         "Report Date", datetime.now(timezone.utc).strftime("%d/%m/%Y")],
        ["Project Name", inspection.project_name or "N/A", "Project Code", inspection.project_code or "N/A"],
    ]

    info_table = Table(info_data, colWidths=[4*cm, 5.5*cm, 4*cm, 5.5*cm])
    info_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (0, -1), LIGHT_BG),
        ("BACKGROUND", (2, 0), (2, -1), LIGHT_BG),
        ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
        ("FONTNAME", (2, 0), (2, -1), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
        ("PADDING", (0, 0), (-1, -1), 6),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 0.3*cm))

    # ── GPS Information ────────────────────────────────────────
    if inspection.checkin_latitude:
        story.append(Paragraph("GPS Check-in/Check-out Details", label))
        gps_data = [
            ["Check-In Time", str(inspection.checkin_time)[:16] if inspection.checkin_time else "N/A",
             "Check-In GPS", f"{inspection.checkin_latitude:.6f}, {inspection.checkin_longitude:.6f}"],
            ["Check-Out Time", str(inspection.checkout_time)[:16] if inspection.checkout_time else "N/A",
             "Check-Out GPS", f"{inspection.checkout_latitude:.6f}, {inspection.checkout_longitude:.6f}" if inspection.checkout_latitude else "N/A"],
            ["Distance Covered", f"{inspection.distance_covered_km:.2f} km" if inspection.distance_covered_km else "N/A",
             "Check-In Address", inspection.checkin_address or "N/A"],
        ]
        gps_table = Table(gps_data, colWidths=[4*cm, 5.5*cm, 4*cm, 5.5*cm])
        gps_table.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (0, -1), LIGHT_BG),
            ("BACKGROUND", (2, 0), (2, -1), LIGHT_BG),
            ("FONTNAME", (0, 0), (0, -1), "Helvetica-Bold"),
            ("FONTNAME", (2, 0), (2, -1), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 9),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ("PADDING", (0, 0), (-1, -1), 6),
        ]))
        story.append(gps_table)
        story.append(Spacer(1, 0.3*cm))

    # ── Observations ──────────────────────────────────────────
    for section_title, content in [
        ("Observations", inspection.observations),
        ("Recommendations", inspection.recommendations),
        ("Action Taken", inspection.action_taken),
        ("AI Suggested Report Draft (AI द्वारा सुझाया गया मसौदा)", inspection.ai_report_draft),
    ]:
        if content:
            story.append(Paragraph(section_title, label))
            story.append(Paragraph(content, normal))
            story.append(Spacer(1, 0.2*cm))

    # ── Photos ────────────────────────────────────────────────
    valid_photos = [p for p in photos if p.file_path and Path(p.file_path).exists()]
    if valid_photos:
        story.append(HRFlowable(width="100%", thickness=1, color=SECONDARY, spaceBefore=8, spaceAfter=8))
        story.append(Paragraph("Inspection Photographs", label))
        story.append(Spacer(1, 0.2*cm))

        # 2 photos per row
        for i in range(0, len(valid_photos), 2):
            row_photos = valid_photos[i:i+2]
            row_data = []
            for photo in row_photos:
                try:
                    img = RLImage(photo.file_path, width=8*cm, height=6*cm)
                    caption = f"{photo.caption or 'Photo'}\n{str(photo.captured_at)[:16] if photo.captured_at else ''}"
                    cell = [img, Paragraph(caption, ParagraphStyle("Cap", fontSize=8, alignment=TA_CENTER))]
                except:
                    cell = [Paragraph("Photo unavailable", normal)]
                row_data.append(cell)

            if len(row_data) == 1:
                row_data.append([""])  # Fill empty cell

            photo_table = Table([row_data], colWidths=[9*cm, 9*cm])
            photo_table.setStyle(TableStyle([
                ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("PADDING", (0, 0), (-1, -1), 5),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.lightgrey),
            ]))
            story.append(photo_table)
            story.append(Spacer(1, 0.2*cm))

    # ── Approval Trail ────────────────────────────────────────
    if approvals:
        story.append(HRFlowable(width="100%", thickness=1, color=SECONDARY, spaceBefore=8, spaceAfter=8))
        story.append(Paragraph("Approval Trail", label))
        approval_data = [["Level", "Approver", "Action", "Remarks", "Date"]]
        for a in approvals:
            approval_data.append([
                a.level,
                a.approver.name if a.approver else "N/A",
                a.action.value.upper(),
                a.remarks or "-",
                str(a.created_at)[:16],
            ])
        approval_table = Table(approval_data, colWidths=[2*cm, 4*cm, 3*cm, 6*cm, 4*cm])
        approval_table.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), DARK_BG),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 9),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ("PADDING", (0, 0), (-1, -1), 5),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, LIGHT_BG]),
        ]))
        story.append(approval_table)

    # ── Signature ─────────────────────────────────────────────
    story.append(Spacer(1, 1*cm))
    sig_data = [
        [Paragraph("Engineer Signature", normal), "", Paragraph("Supervisor Signature", normal)],
        ["", "", ""],
        [Paragraph(f"Name: {engineer.name if engineer else 'N/A'}", normal), "",
         Paragraph("Name: ___________________", normal)],
        [Paragraph(f"Date: {datetime.now().strftime('%d/%m/%Y')}", normal), "",
         Paragraph("Date: ___________________", normal)],
    ]
    sig_table = Table(sig_data, colWidths=[8*cm, 3*cm, 8*cm])
    sig_table.setStyle(TableStyle([
        ("LINEABOVE", (0, 1), (0, 1), 1, colors.black),
        ("LINEABOVE", (2, 1), (2, 1), 1, colors.black),
        ("VALIGN", (0, 0), (-1, -1), "BOTTOM"),
    ]))
    story.append(sig_table)

    # ── Footer ────────────────────────────────────────────────
    story.append(Spacer(1, 0.5*cm))
    story.append(HRFlowable(width="100%", thickness=0.5, color=colors.grey))
    story.append(Paragraph(
        f"Generated by Gram Nirikshan App | {datetime.now().strftime('%d/%m/%Y %H:%M')} | Report ID: {inspection.inspection_id}",
        ParagraphStyle("Footer", fontSize=8, alignment=TA_CENTER, textColor=colors.grey)
    ))

    doc.build(story)


@router.post("/generate/{inspection_id}", response_model=MessageResponse)
async def generate_report(
    inspection_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Generate PDF report for an inspection."""
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

    result5 = await db.execute(select(Approval).where(Approval.inspection_id == inspection_id))
    approvals = result5.scalars().all()

    file_name = f"Report_{inspection.inspection_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf"
    output_path = str(REPORTS_DIR / file_name)

    try:
        build_pdf_report(inspection, panchayat, engineer, list(photos), list(approvals), output_path)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"PDF generation failed: {str(e)}")

    # Save report record
    file_size_kb = Path(output_path).stat().st_size // 1024
    report = Report(
        inspection_id=inspection_id,
        generated_by=current_user.id,
        file_path=output_path,
        file_name=file_name,
        file_size_kb=file_size_kb,
    )
    db.add(report)

    return MessageResponse(
        message="Report generated successfully",
        success=True,
        data={"file_name": file_name, "size_kb": file_size_kb},
    )


@router.get("/download/{inspection_id}")
async def download_report(
    inspection_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Download latest report PDF for an inspection."""
    result = await db.execute(
        select(Report).where(Report.inspection_id == inspection_id)
        .order_by(Report.created_at.desc())
    )
    report = result.scalar_one_or_none()
    if not report or not Path(report.file_path).exists():
        raise HTTPException(status_code=404, detail="Report not found. Generate it first.")

    return FileResponse(
        report.file_path,
        media_type="application/pdf",
        filename=report.file_name,
    )
