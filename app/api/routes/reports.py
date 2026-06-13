"""
PDF Report Generator using ReportLab.
Generates department-format inspection reports with photos, GPS data, and approval trail.
"""
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm, inch
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    Image as RLImage, HRFlowable, KeepTogether
)
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT, TA_JUSTIFY
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from pathlib import Path
from datetime import datetime, timezone
import uuid, os, shutil

try:
    import docx
    from docx.shared import Inches, Pt, RGBColor
    from docx.enum.text import WD_ALIGN_PARAGRAPH
except ImportError:
    docx = None

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


def find_project_root() -> Path:
    current = Path(__file__).resolve().parent
    for _ in range(5):
        if (current / "flutter_app").exists():
            return current
        current = current.parent
    return Path(__file__).parents[3]


def get_absolute_path(rel_path: str) -> Path:
    """Find absolute path of a file, searching workspace directories."""
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


# Register Noto Sans Devanagari Hindi Unicode font
pdf_font_name = 'Helvetica'
pdf_font_bold_name = 'Helvetica-Bold'

try:
    root = find_project_root()
    backend_font_dir = root / "assets" / "fonts"
    backend_font_dir.mkdir(parents=True, exist_ok=True)

    reg_path = backend_font_dir / "NotoSansDevanagari-Regular.ttf"
    bold_path = backend_font_dir / "NotoSansDevanagari-Bold.ttf"
    kd_path = backend_font_dir / "Kruti_Dev_010.ttf"

    import requests
    if not reg_path.exists():
        try:
            r = requests.get('https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSansDevanagari/NotoSansDevanagari-Regular.ttf', timeout=10)
            with open(reg_path, 'wb') as f:
                f.write(r.content)
        except Exception as e:
            print(f"Failed to download Noto Regular font: {e}")
            
    if not bold_path.exists():
        try:
            r = requests.get('https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSansDevanagari/NotoSansDevanagari-Bold.ttf', timeout=10)
            with open(bold_path, 'wb') as f:
                f.write(r.content)
        except Exception as e:
            print(f"Failed to download Noto Bold font: {e}")

    if not kd_path.exists():
        try:
            r = requests.get('https://github.com/ashoksihmar/iascgl/raw/master/Kruti_Dev_010.ttf', timeout=10)
            with open(kd_path, 'wb') as f:
                f.write(r.content)
        except Exception as e:
            print(f"Failed to download Kruti Dev font: {e}")

    if reg_path.exists() and bold_path.exists():
        pdfmetrics.registerFont(TTFont('NotoDev', str(reg_path)))
        pdfmetrics.registerFont(TTFont('NotoDev-Bold', str(bold_path)))
        pdf_font_name = 'NotoDev'
        pdf_font_bold_name = 'NotoDev-Bold'

    if kd_path.exists():
        pdfmetrics.registerFont(TTFont('KrutiDev', str(kd_path)))
        pdfmetrics.registerFont(TTFont('KrutiDev-Bold', str(kd_path)))
except Exception as e:
    print(f"Error registering Noto Sans Devanagari/Kruti Dev fonts: {e}")
    pdf_font_name = 'Helvetica'
    pdf_font_bold_name = 'Helvetica-Bold'


def Unicode_to_KrutiDev(unicode_substring: str) -> str:
    if not unicode_substring:
        return ""
    modified_substring = unicode_substring
    
    array_one = ["‘",   "’",   "“",   "”",   "(",    ")",   "{",    "}",   "=", "।",  "?",  "-",  "µ", "॰", ",", ".", "् ", 
    "०",  "१",  "२",  "३",     "४",   "५",  "६",   "७",   "८",   "९", "x", 
    
    "फ़्",  "क़",  "ख़",  "ग़", "ज़्", "ज़",  "ड़",  "ढ़",   "फ़",  "य़",  "ऱ",  "ऩ",  
    "त्त्",   "त्त",     "क्त",  "दृ",  "कृ",
    
    "ह्न",  "ह्य",  "हृ",  "ह्म",  "ह्र",  "ह्",   "द्द",  "क्ष्", "क्ष", "त्र्", "त्र","ज्ञ",
    "छ्य",  "ट्य",  "ठ्य",  "ड्य",  "ढ्य", "द्य","द्व",
    "श्र",  "ट्र",    "ड्र",    "ढ्र",    "छ्र",   "क्र",  "फ्र",  "द्र",   "प्र",   "ग्र", "रु",  "रू",
    "्र",
    
    "ओ",  "औ",  "आ",   "अ",   "ई",   "इ",  "उ",   "ऊ",  "ऐ",  "ए", "ऋ",
    
    "क्",  "क",  "क्क",  "ख्",   "ख",    "ग्",   "ग",  "घ्",  "घ",    "ङ",
    "चै",   "च्",   "च",   "छ",  "ज्", "ज",   "झ्",  "झ",   "ञ",
    
    "ट्ट",   "ट्ठ",   "ट",   "ठ",   "ड्ड",   "ड्ढ",  "ड",   "ढ",  "ण्", "ण",  
    "त्",  "त",  "थ्", "थ",  "द्ध",  "द", "ध्", "ध",  "न्",  "न",  
    
    "प्",  "प",  "फ्", "फ",  "ब्",  "ब", "भ्",  "भ",  "म्",  "म",
    "य्",  "य",  "र",  "ल्", "ल",  "ळ",  "व्",  "व", 
    "श्", "श",  "ष्", "ष",  "स्",   "स",   "ह",     
    
    "ऑ",   "ॉ",  "ो",   "ौ",   "ा",   "ी",   "ु",   "ू",   "ृ",   "े",   "ै",
    "ं",   "ँ",   "ः",   "ॅ",    "ऽ",  "् ", "्" ]
    
    array_two = ["^", "*",  "Þ", "ß", "¼", "½", "¿", "À", "¾", "A", "\\", "&", "&", "Œ", "]","-","~ ", 
    "å",  "ƒ",  "„",   "…",   "†",   "‡",   "ˆ",   "‰",   "Š",   "‹","Û",
    
    "¶",   "d",    "[k",  "x",  "T",  "t",   "M+", "<+", "Q",  ";",    "j",   "u",
    "Ù",   "Ùk",   "Dr",    "–",   "—",       
    
    "à",   "á",    "â",   "ã",   "ºz",  "º",   "í", "{", "{k",  "«", "=","K", 
    "Nî",   "Vî",    "Bî",   "Mî",   "<î", "|","}",
    "J",   "Vª",   "Mª",  "<ªª",  "Nª",   "Ø",  "Ý",   "æ", "ç", "xz", "#", ":",
    "z",
    
    "vks",  "vkS",  "vk",    "v",   "bZ",  "b",  "m",  "Å",  ",s",  ",",   "_",
    
    "D",  "d",    "ô",     "[",     "[k",    "X",   "x",  "?",    "?k",   "³", 
    "pkS",  "P",    "p",  "N",   "T",    "t",   "÷",  ">",   "¥",
    
    "ê",      "ë",      "V",  "B",   "ì",       "ï",     "M",  "<",  ".", ".k",   
    "R",  "r",   "F", "Fk",  ")",    "n", "/",  "/k",  "U", "u",   
    
    "I",  "i",   "¶", "Q",   "C",  "c",  "H",  "Hk", "E",   "e",
    "¸",   ";",    "j",  "Y",   "y",  "G",  "O",  "o",
    "'", "'k",  "\"", "\"k", "L",   "l",   "g",      
    
    "v‚",    "‚",    "ks",   "kS",   "k",     "h",    "q",   "w",   "`",    "s",    "S",
    "a",    "¡",    "%",     "W",   "·",   "~ ", "~"]
    
    array_one_length = len(array_one)
    
    modified_substring = modified_substring.replace("ि", "ि")
    modified_substring = modified_substring.replace("ि", "f")
    
    for input_symbol_idx in range(0, array_one_length):
        modified_substring = modified_substring.replace(array_one[input_symbol_idx], array_two[input_symbol_idx])
    
    # Move "f" to correct position (before consonant)
    modified_substring = "  " + modified_substring + "  "
    position_of_f = modified_substring.find("f")
    while position_of_f != -1:
        modified_substring = modified_substring[:position_of_f-1] + "f" + modified_substring[position_of_f-1] + modified_substring[position_of_f+1:]
        position_of_f = modified_substring.find("f", position_of_f + 1)
    modified_substring = modified_substring.strip()
    
    # Move "half R" to correct position
    modified_substring = "  " + modified_substring + "  "
    position_of_r = modified_substring.find("j~")
    set_of_matras = ["‚", "ks", "kS", "k", "h", "q", "w", "`", "s", "S", "a", "¡", "%", "W", "·", "~ ", "~"]
    while position_of_r != -1:
        modified_substring = modified_substring.replace("j~", "", 1)
        if modified_substring[position_of_r + 1] in set_of_matras:
            modified_substring = modified_substring[:position_of_r + 2] + "Z" + modified_substring[position_of_r + 2:]
        else:
            modified_substring = modified_substring[:position_of_r + 1] + "Z" + modified_substring[position_of_r + 1:]
        position_of_r = modified_substring.find("j~")
    modified_substring = modified_substring.strip()
    
    return modified_substring


def to_pdf_html(text: str, bold: bool = False, size: float = None) -> str:
    if not text:
        return ""
    spans = []
    current_type = None
    current_str = []
    for c in text:
        # Check if character is Hindi or ZWJ/ZWNJ
        is_hindi = (0x0900 <= ord(c) <= 0x097F) or (ord(c) in (0x200c, 0x200d))
        if is_hindi:
            this_type = 'hindi'
        elif c in (' ', ',', '.', ':', '(', ')', '-', '/', '_', '[', ']', '\n', '\r'):
            this_type = current_type if current_type else 'english'
        else:
            this_type = 'english'
            
        if this_type != current_type:
            if current_str:
                spans.append((current_type, ''.join(current_str)))
            current_type = this_type
            current_str = [c]
        else:
            current_str.append(c)
    if current_str:
        spans.append((current_type, ''.join(current_str)))

    html_parts = []
    for t, s in spans:
        if t == 'hindi':
            escaped_s = s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('\n', '<br/>').replace('\r', '')
            font = 'NotoDev-Bold' if bold else 'NotoDev'
            fs = f' size="{size}"' if size else ' size="9.5"'
            html_parts.append(f'<font name="{font}"{fs}>{escaped_s}</font>')
        else:
            escaped_s = s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('\n', '<br/>').replace('\r', '')
            font = 'Helvetica-Bold' if bold else 'Helvetica'
            fs = f' size="{size}"' if size else ''
            html_parts.append(f'<font name="{font}"{fs}>{escaped_s}</font>')
            
    return "".join(html_parts)


def extract_witness_name(description: str) -> str:
    if not description:
        return "___________________"
    import re
    match = re.search(r"(?:गवाह का नाम|गवाह\s*नाम|गवाह|witness name|witness)\s*[:：\-‐—\s]\s*([^\n\r।\.]+)", description, re.IGNORECASE)
    if match:
        name = match.group(1).strip()
        name = name.split(',')[0].split(';')[0].strip()
        name = re.sub(r"^(?:श्री|shri|mr\.|mrs\.)\s+", "", name, flags=re.IGNORECASE)
        stop_words = ["उपस्थित", "मौजूद", "थे", "था", "रहा", "रही", "गया", "गई", "है", "हैं", "present", "here", "was", "is", "were"]
        for stop_word in stop_words:
            name = re.sub(rf"(?:\s+|^){stop_word}(?:\s+|$)", " ", name, flags=re.IGNORECASE).strip()
        if name:
            return name
    return "___________________"


def get_val_str(val) -> str:
    if val is None:
        return ""
    if hasattr(val, "value"):
        return str(val.value)
    return str(val)


def get_formatted_district_block(inspection, panchayat):
    dist = inspection.district or (panchayat.district if panchayat else "N/A")
    dist_clean = "".join(dist.lower().split()) if dist else ""
    if "hathras" in dist_clean:
        dist = "Hathras"
    elif "sikandra" in dist_clean:
        dist = "Sikandra Rao"
    
    blk = inspection.block or (panchayat.block if panchayat else "N/A")
    blk_clean = "".join(blk.lower().split()) if blk else ""
    if "hathras" in blk_clean:
        blk = "Hathras"
    elif "sikandra" in blk_clean:
        blk = "Sikandra Rao"
        
    return dist, blk


def build_docx_report(inspection, panchayat, engineer, photos, approvals, output_path: str):
    """Build a formal Microsoft Word report in Kruti Dev 010."""
    if not docx:
        raise RuntimeError("python-docx library is not installed on this server.")
        
    doc = docx.Document()
    
    # Set margins to 0.75 inches for page-like structure
    for section in doc.sections:
        section.top_margin = Inches(0.75)
        section.bottom_margin = Inches(0.75)
        section.left_margin = Inches(0.75)
        section.right_margin = Inches(0.75)

    # Helper function to classify and write mixed text runs in Kruti Dev or Arial
    def add_runs_to_p(p, text, bold=False, font_size_pt=18):
        if not text:
            return
        spans = []
        current_type = None
        current_str = []
        for c in text:
            is_hindi = (0x0900 <= ord(c) <= 0x097F)
            if is_hindi:
                this_type = 'hindi'
            elif c in (' ', ',', '.', ':', '(', ')'):
                this_type = current_type if current_type else 'english'
            else:
                this_type = 'english'
            if this_type != current_type:
                if current_str:
                    spans.append((current_type, ''.join(current_str)))
                current_type = this_type
                current_str = [c]
            else:
                current_str.append(c)
        if current_str:
            spans.append((current_type, ''.join(current_str)))

        for t, s in spans:
            run = p.add_run()
            if t == 'hindi':
                run.text = Unicode_to_KrutiDev(s)
                run.font.name = 'Kruti Dev 010'
            else:
                run.text = s
                run.font.name = 'Arial'
            run.font.size = Pt(font_size_pt)
            if bold:
                run.bold = True

    def set_cell(cell, text, bold=False, font_size_pt=18):
        cell.text = ""
        p = cell.paragraphs[0]
        p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        p.paragraph_format.space_after = Pt(2)
        p.paragraph_format.space_before = Pt(2)
        add_runs_to_p(p, text, bold=bold, font_size_pt=font_size_pt)

    # Basic Information
    engineer_name = inspection.investigator_name or (engineer.name or engineer.name_hindi if engineer else "N/A")
    dist, blk = get_formatted_district_block(inspection, panchayat)
    
    # Subheading/Section: Basic Info
    p_info_lbl = doc.add_paragraph()
    p_info_lbl.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    add_runs_to_p(p_info_lbl, "Inspection Basic Details", bold=True, font_size_pt=19)
    
    table = doc.add_table(rows=5, cols=2)
    table.style = 'Table Grid'
    
    info_pairs = [
        (f"Inspection ID: {inspection.inspection_id}", f"Status: {get_val_str(inspection.status).upper()}"),
        (f"Inspector: {engineer_name}", f"District: {dist}"),
        (f"Gram Panchayat: {panchayat.name or panchayat.name_hindi if panchayat else 'N/A'}", f"Village: {panchayat.village or 'N/A' if panchayat else 'N/A'}"),
        (f"Development Block: {blk}", f"Inspection Date: {str(inspection.inspection_date)[:10] if inspection.inspection_date else 'N/A'}"),
        (f"Project Name: {inspection.project_name or 'N/A'}", f"Work Code: {inspection.project_code or 'N/A'}"),
    ]
    
    for idx, (col1, col2) in enumerate(info_pairs):
        row = table.rows[idx]
        set_cell(row.cells[0], col1, font_size_pt=18)
        set_cell(row.cells[1], col2, font_size_pt=18)
        
    p_space = doc.add_paragraph()
    p_space.paragraph_format.space_after = Pt(12)
    
    # GPS Details
    if inspection.checkin_latitude:
        p_gps_lbl = doc.add_paragraph()
        p_gps_lbl.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        add_runs_to_p(p_gps_lbl, "GPS Check-in/Check-out Details", bold=True, font_size_pt=19)
        
        gps_table = doc.add_table(rows=3, cols=2)
        gps_table.style = 'Table Grid'
        
        gps_pairs = [
            (f"Check-in Time: {str(inspection.checkin_time)[:16] if inspection.checkin_time else 'N/A'}", f"Check-in GPS: {inspection.checkin_latitude:.6f}, {inspection.checkin_longitude:.6f}"),
            (f"Check-out Time: {str(inspection.checkout_time)[:16] if inspection.checkout_time else 'N/A'}", f"Check-out GPS: {f'{inspection.checkout_latitude:.6f}, {inspection.checkout_longitude:.6f}' if inspection.checkout_latitude else 'N/A'}"),
        ]
        
        for idx in range(2):
            row = gps_table.rows[idx]
            set_cell(row.cells[0], gps_pairs[idx][0], font_size_pt=18)
            set_cell(row.cells[1], gps_pairs[idx][1], font_size_pt=18)
            
        row2 = gps_table.rows[2]
        cell_merged = row2.cells[0].merge(row2.cells[1])
        set_cell(cell_merged, f"Check-in Location: {inspection.checkin_address or 'N/A'}", font_size_pt=18)
        
        p_space2 = doc.add_paragraph()
        p_space2.paragraph_format.space_after = Pt(12)
        
    # Map Attachment
    if inspection.map_image_path:
        map_file_path = get_absolute_path(inspection.map_image_path)
        if map_file_path.exists():
            p_map = doc.add_paragraph()
            p_map.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
            add_runs_to_p(p_map, "Inspection Location Map", bold=True, font_size_pt=19)
            
            p_img = doc.add_paragraph()
            p_img.alignment = WD_ALIGN_PARAGRAPH.CENTER
            try:
                p_img.add_run().add_picture(str(map_file_path), width=Inches(5.5))
            except Exception as e:
                p_img.add_run(f"Failed to load map image: {e}")
            
            p_space3 = doc.add_paragraph()
            p_space3.paragraph_format.space_after = Pt(12)
            
    # Observations & Recommendations
    for section_title, content in [
        ("Key Observations / Deficiencies", inspection.observations),
        ("Corrective Recommendations / Measures", inspection.recommendations),
        ("Action Taken / Remarks", inspection.action_taken),
    ]:
        if content:
            p_lbl = doc.add_paragraph()
            p_lbl.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
            add_runs_to_p(p_lbl, section_title, bold=True, font_size_pt=19)
            
            p_val = doc.add_paragraph()
            p_val.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
            p_val.paragraph_format.space_after = Pt(12)
            add_runs_to_p(p_val, content, font_size_pt=18)
            
    # AI Report Draft
    if inspection.ai_report_draft:
        p_ai_lbl = doc.add_paragraph()
        p_ai_lbl.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        add_runs_to_p(p_ai_lbl, "Detailed Inspection Report", bold=True, font_size_pt=19)
        
        ai_lines = inspection.ai_report_draft.split('\n')
        for line in ai_lines:
            if line.strip():
                is_bold = line.strip().startswith('**') or line.strip().startswith('###') or line.strip().startswith('##') or line.strip().startswith('*')
                clean_line = line.strip().replace('**', '').replace('###', '').replace('##', '').replace('*', '').strip()
                p_line = doc.add_paragraph()
                p_line.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
                add_runs_to_p(p_line, clean_line, bold=is_bold, font_size_pt=18)
            else:
                p_space = doc.add_paragraph()
                p_space.paragraph_format.space_after = Pt(6)
            
    # Photos
    valid_photos = []
    for p in photos:
        if p.file_path:
            abs_p = get_absolute_path(p.file_path)
            if abs_p.exists():
                valid_photos.append((p, abs_p))
                
    if valid_photos:
        p_photo_lbl = doc.add_paragraph()
        p_photo_lbl.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
        add_runs_to_p(p_photo_lbl, "Inspection Site Photographs", bold=True, font_size_pt=19)
        
        photo_table = doc.add_table(rows=(len(valid_photos) + 1) // 2, cols=2)
        photo_table.style = 'Table Grid'
        
        for idx, (photo, abs_p) in enumerate(valid_photos):
            row_idx = idx // 2
            col_idx = idx % 2
            cell = photo_table.rows[row_idx].cells[col_idx]
            cell.text = ""
            p_cell = cell.paragraphs[0]
            p_cell.alignment = WD_ALIGN_PARAGRAPH.CENTER
            try:
                p_cell.add_run().add_picture(str(abs_p), width=Inches(2.5))
                caption_text = f"\n{photo.caption or 'Site Photograph'}\n{str(photo.captured_at)[:16] if photo.captured_at else ''}"
                p_cap = cell.add_paragraph()
                p_cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
                add_runs_to_p(p_cap, caption_text, font_size_pt=14)
            except Exception as e:
                p_cell.add_run(f"Failed to load photograph: {e}")
                
        p_space4 = doc.add_paragraph()
        p_space4.paragraph_format.space_after = Pt(12)
        
    # Signatures
    witness_name = extract_witness_name(inspection.action_taken)
    if witness_name == "___________________":
        witness_name = extract_witness_name(inspection.description)
    
    p_sig_space = doc.add_paragraph()
    p_sig_space.paragraph_format.space_before = Pt(24)
    
    sig_table = doc.add_table(rows=4, cols=3)
    sig_table.columns[0].width = Inches(3.2)
    sig_table.columns[1].width = Inches(0.6)
    sig_table.columns[2].width = Inches(3.2)
    
    set_cell(sig_table.rows[0].cells[0], "Signature of Inspecting Officer", bold=True, font_size_pt=18)
    set_cell(sig_table.rows[0].cells[2], "Signature of Witness / Representative", bold=True, font_size_pt=18)
    
    set_cell(sig_table.rows[1].cells[0], f"Name: {engineer_name}", font_size_pt=18)
    set_cell(sig_table.rows[1].cells[2], f"Name: {witness_name}", font_size_pt=18)
    
    set_cell(sig_table.rows[2].cells[0], "", font_size_pt=18)
    set_cell(sig_table.rows[2].cells[2], "", font_size_pt=18)
    
    set_cell(sig_table.rows[3].cells[0], f"Date: {datetime.now().strftime('%d/%m/%Y')}", font_size_pt=18)
    set_cell(sig_table.rows[3].cells[2], "Date: ___________________", font_size_pt=18)
    
    # Footer
    p_foot = doc.add_paragraph()
    p_foot.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_foot.paragraph_format.space_before = Pt(24)
    add_runs_to_p(p_foot, f"──────────────────────────────────────────────────\nAuto-generated by Gram Nirikshan Mobile App | {datetime.now().strftime('%d/%m/%Y %H:%M')} | Inspection ID: {inspection.inspection_id}", font_size_pt=14)
    
    doc.save(output_path)


def build_pdf_report(inspection, panchayat, engineer, photos, approvals, output_path: str):
    """Build a simplified PDF inspection report without squares."""
    doc = SimpleDocTemplate(
        output_path,
        pagesize=A4,
        leftMargin=2*cm, rightMargin=2*cm,
        topMargin=1.5*cm, bottomMargin=2*cm,
    )

    styles = getSampleStyleSheet()
    story = []

    # ── Header ────────────────────────────────────────────────
    title_26 = ParagraphStyle(
        "Title26", fontSize=26, textColor=PRIMARY,
        alignment=TA_CENTER, fontName='Helvetica-Bold', spaceAfter=12
    )
    title_22 = ParagraphStyle(
        "Title22", fontSize=22, textColor=SECONDARY,
        alignment=TA_CENTER, fontName='Helvetica-Bold', spaceAfter=2
    )
    title_18 = ParagraphStyle(
        "Title18", fontSize=18, textColor=colors.black,
        alignment=TA_CENTER, fontName='Helvetica-Bold', spaceAfter=8
    )
    normal = ParagraphStyle("Normal2", fontSize=9, fontName='Helvetica', leading=12, alignment=TA_JUSTIFY, spaceAfter=4)
    label = ParagraphStyle("Label", fontSize=9, fontName='Helvetica-Bold', textColor=PRIMARY, spaceBefore=4, spaceAfter=2)
    label_large = ParagraphStyle("LabelLarge", fontSize=20, fontName='Helvetica-Bold', textColor=PRIMARY, spaceBefore=12, spaceAfter=6, leading=24)

    story.append(Paragraph(to_pdf_html("निरीक्षण आख्या", bold=True, size=26), title_26))
    story.append(HRFlowable(width="100%", thickness=1.5, color=PRIMARY, spaceBefore=2, spaceAfter=6))

    # ── Basic Information ──────────────────────────────────────
    engineer_name = inspection.investigator_name or (engineer.name_hindi or engineer.name if engineer else "N/A")
    dist, blk = get_formatted_district_block(inspection, panchayat)

    status_val = get_val_str(inspection.status).lower()
    status_labels = {
        "draft": "मसौदा (Draft)",
        "submitted": "प्रस्तुत (Submitted)",
        "verified": "सत्यापित (Verified)",
        "approved": "स्वीकृत (Approved)",
        "rejected": "अस्वीकृत (Rejected)"
    }
    status_hindi = status_labels.get(status_val, status_val.upper())

    info_data = [
        [Paragraph(to_pdf_html("निरीक्षण संख्या (ID)"), normal), Paragraph(to_pdf_html(inspection.inspection_id), normal), 
         Paragraph(to_pdf_html("स्थिति (Status)"), normal), Paragraph(to_pdf_html(status_hindi), normal)],
        [Paragraph(to_pdf_html("जाँचकर्ता (Inspector)"), normal), Paragraph(to_pdf_html(engineer_name), normal), 
         Paragraph(to_pdf_html("जनपद (District)"), normal), Paragraph(to_pdf_html(dist), normal)],
        [Paragraph(to_pdf_html("ग्राम पंचायत"), normal), Paragraph(to_pdf_html(panchayat.name_hindi or panchayat.name if panchayat else "N/A"), normal), 
         Paragraph(to_pdf_html("ग्राम (Village)"), normal), Paragraph(to_pdf_html(panchayat.village or "N/A" if panchayat else "N/A"), normal)],
        [Paragraph(to_pdf_html("विकासखंड (Block)"), normal), Paragraph(to_pdf_html(blk), normal), 
         Paragraph(to_pdf_html("निरीक्षण तिथि/दिनांक"), normal), Paragraph(to_pdf_html(str(inspection.inspection_date)[:10] if inspection.inspection_date else "N/A"), normal)],
        [Paragraph(to_pdf_html("परियोजना का नाम"), normal), Paragraph(to_pdf_html(inspection.project_name or "N/A"), normal), 
         Paragraph(to_pdf_html("कार्य कोड (Code)"), normal), Paragraph(to_pdf_html(inspection.project_code or "N/A"), normal)],
    ]

    info_table = Table(info_data, colWidths=[4*cm, 5.5*cm, 4*cm, 5.5*cm])
    info_table.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (0, -1), LIGHT_BG),
        ("BACKGROUND", (2, 0), (2, -1), LIGHT_BG),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
        ("PADDING", (0, 0), (-1, -1), 4),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 0.15*cm))

    # ── GPS Information ────────────────────────────────────────
    if inspection.checkin_latitude:
        story.append(Paragraph(to_pdf_html("जी.पी.एस. आगमन/प्रस्थान विवरण (GPS Check-in/Check-out Details)", bold=True), label))
        gps_data = [
            [Paragraph(to_pdf_html("चेक-इन (आगमन) समय"), normal), Paragraph(to_pdf_html(str(inspection.checkin_time)[:16] if inspection.checkin_time else "N/A"), normal),
             Paragraph(to_pdf_html("चेक-इन जी.पी.एस."), normal), Paragraph(to_pdf_html(f"{inspection.checkin_latitude:.6f}, {inspection.checkin_longitude:.6f}"), normal)],
            [Paragraph(to_pdf_html("चेक-आउट (प्रस्थान) समय"), normal), Paragraph(to_pdf_html(str(inspection.checkout_time)[:16] if inspection.checkout_time else "N/A"), normal),
             Paragraph(to_pdf_html("चेक-आउट जी.पी.एस."), normal), Paragraph(to_pdf_html(f"{inspection.checkout_latitude:.6f}, {inspection.checkout_longitude:.6f}" if inspection.checkout_latitude else "N/A"), normal)],
            [Paragraph(to_pdf_html("चेक-इन (आगमन) स्थल"), normal), Paragraph(to_pdf_html(inspection.checkin_address or "N/A"), normal), "", ""],
        ]
        gps_table = Table(gps_data, colWidths=[4*cm, 5.5*cm, 4*cm, 5.5*cm])
        gps_table.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (0, -1), LIGHT_BG),
            ("BACKGROUND", (2, 0), (2, -1), LIGHT_BG),
            ("FONTSIZE", (0, 0), (-1, -1), 9),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ("PADDING", (0, 0), (-1, -1), 4),
            ("SPAN", (1, 2), (3, 2)),
        ]))
        story.append(gps_table)
        story.append(Spacer(1, 0.15*cm))

    # ── Map Attachment ─────────────────────────────────────────
    if inspection.map_image_path:
        map_file_path = get_absolute_path(inspection.map_image_path)
        if map_file_path.exists():
            story.append(Paragraph(to_pdf_html("निरीक्षण स्थल मानचित्र (Inspection Location Map)", bold=True), label))
            story.append(Spacer(1, 0.1*cm))
            try:
                img = RLImage(str(map_file_path), width=15*cm, height=6.5*cm)
                story.append(KeepTogether([img, Spacer(1, 0.15*cm)]))
            except Exception as e:
                story.append(Paragraph(to_pdf_html(f"मानचित्र छवि लोड करने में विफल: {str(e)}"), normal))

    # ── Observations & Recommendations ─────────────────────────
    for section_title, content in [
        ("मुख्य अवलोकन एवं कमियाँ (Observations)", inspection.observations),
        ("सुझाव एवं संस्तुतियाँ (Recommendations)", inspection.recommendations),
        ("की गई कार्रवाई (Action Taken)", inspection.action_taken),
    ]:
        if content:
            story.append(Paragraph(to_pdf_html(section_title + " :-", bold=True, size=20), label_large))
            story.append(Paragraph(to_pdf_html(content), normal))
            story.append(Spacer(1, 0.15*cm))

    # ── AI Report Draft ────────────────────────────────────────
    if inspection.ai_report_draft:
        story.append(Paragraph(to_pdf_html("विस्तृत निरीक्षण आख्या :-", bold=True, size=20), label_large))
        story.append(Spacer(1, 0.1*cm))
        ai_lines = inspection.ai_report_draft.split('\n')
        for line in ai_lines:
            if line.strip():
                # Check if it looks like a markdown heading
                is_bold = line.strip().startswith('**') or line.strip().startswith('###') or line.strip().startswith('##') or line.strip().startswith('*')
                clean_line = line.strip().replace('**', '').replace('###', '').replace('##', '').replace('*', '').strip()
                story.append(Paragraph(to_pdf_html(clean_line, bold=is_bold), normal))
            else:
                story.append(Spacer(1, 0.05*cm))
        story.append(Spacer(1, 0.15*cm))

    # ── Photos ────────────────────────────────────────────────
    valid_photos = []
    for p in photos:
        if p.file_path:
            abs_p = get_absolute_path(p.file_path)
            if abs_p.exists():
                valid_photos.append((p, abs_p))

    if valid_photos:
        story.append(HRFlowable(width="100%", thickness=1, color=SECONDARY, spaceBefore=8, spaceAfter=8))
        story.append(Paragraph(to_pdf_html("Inspection Site Photographs :-", bold=True, size=20), label_large))
        story.append(Spacer(1, 0.1*cm))

        for i in range(0, len(valid_photos), 2):
            row_photos = valid_photos[i:i+2]
            row_data = []
            for photo, abs_p in row_photos:
                try:
                    img = RLImage(str(abs_p), width=8*cm, height=4.5*cm)
                    caption = f"{photo.caption or 'Site Photograph'}\n{str(photo.captured_at)[:16] if photo.captured_at else ''}"
                    cell = [img, Paragraph(to_pdf_html(caption), ParagraphStyle("Cap", fontSize=8, fontName='Helvetica', alignment=TA_CENTER))]
                except Exception as ex:
                    cell = [Paragraph(to_pdf_html(f"Failed to load photograph: {ex}"), normal)]
                row_data.append(cell)

            if len(row_data) == 1:
                row_data.append([Paragraph("", normal)])

            photo_table = Table([row_data], colWidths=[9*cm, 9*cm])
            photo_table.setStyle(TableStyle([
                ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("PADDING", (0, 0), (-1, -1), 3),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.lightgrey),
            ]))
            story.append(photo_table)
            story.append(Spacer(1, 0.1*cm))

    # ── Approval Table ─────────────────────────────────────────
    if approvals:
        story.append(Spacer(1, 0.15*cm))
        story.append(Paragraph(to_pdf_html("Approval Details", bold=True), label))
        approval_headers = [
            Paragraph(to_pdf_html("Level", bold=True), ParagraphStyle("H5", fontName='Helvetica-Bold', fontSize=9, textColor=colors.white)),
            Paragraph(to_pdf_html("Officer", bold=True), ParagraphStyle("H5", fontName='Helvetica-Bold', fontSize=9, textColor=colors.white)),
            Paragraph(to_pdf_html("Status", bold=True), ParagraphStyle("H5", fontName='Helvetica-Bold', fontSize=9, textColor=colors.white)),
            Paragraph(to_pdf_html("Remarks", bold=True), ParagraphStyle("H5", fontName='Helvetica-Bold', fontSize=9, textColor=colors.white)),
            Paragraph(to_pdf_html("Date", bold=True), ParagraphStyle("H5", fontName='Helvetica-Bold', fontSize=9, textColor=colors.white))
        ]
        
        approval_data = [approval_headers]
        for a in approvals:
            app_name = a.approver.name or a.approver.name_hindi if a.approver else "N/A"
            desig = a.approver.designation or "Officer" if a.approver else ""
            act_labels = {"pending": "Pending", "approved": "Approved", "rejected": "Rejected", "forwarded": "Forwarded"}
            action_val = get_val_str(a.action)
            action_eng = act_labels.get(action_val.lower(), action_val.upper())
            
            approval_data.append([
                Paragraph(to_pdf_html(a.level), normal),
                Paragraph(to_pdf_html(f"{app_name} ({desig})"), normal),
                Paragraph(to_pdf_html(action_eng), normal),
                Paragraph(to_pdf_html(a.remarks or "-"), normal),
                Paragraph(to_pdf_html(str(a.created_at)[:16]), normal),
            ])
        approval_table = Table(approval_data, colWidths=[2*cm, 4.5*cm, 2.5*cm, 6*cm, 3*cm])
        approval_table.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), DARK_BG),
            ("FONTSIZE", (0, 0), (-1, -1), 9),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
            ("PADDING", (0, 0), (-1, -1), 3),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, LIGHT_BG]),
        ]))
        story.append(approval_table)

    # ── Signature ─────────────────────────────────────────────
    story.append(Spacer(1, 0.3*cm))
    witness_name = extract_witness_name(inspection.action_taken)
    if witness_name == "___________________":
        witness_name = extract_witness_name(inspection.description)
    engineer_designation = engineer.designation or "Junior Engineer" if engineer else "N/A"
    if engineer_designation.strip().lower() in ["super admin", "superadmin"]:
        engineer_designation = ""

    sig_data = [
        [Paragraph(to_pdf_html("Signature of Inspecting Officer", bold=True), normal), "", Paragraph(to_pdf_html("Signature of Witness / Representative", bold=True), normal)],
        ["", "", ""],
        [Paragraph(to_pdf_html(f"Name: {engineer_name}"), normal), "",
         Paragraph(to_pdf_html(f"Name: {witness_name}"), normal)],
        [Paragraph(to_pdf_html(f"Designation: {engineer_designation}"), normal), "",
         Paragraph(to_pdf_html(""), normal)],
        [Paragraph(to_pdf_html(f"Date: {datetime.now().strftime('%d/%m/%Y')}"), normal), "",
         Paragraph(to_pdf_html("Date: ___________________"), normal)],
    ]
    sig_table = Table(sig_data, colWidths=[8*cm, 3*cm, 8*cm])
    sig_table.setStyle(TableStyle([
        ("LINEABOVE", (0, 2), (0, 2), 1, colors.black),
        ("LINEABOVE", (2, 2), (2, 2), 1, colors.black),
        ("VALIGN", (0, 0), (-1, -1), "BOTTOM"),
    ]))
    story.append(sig_table)

    # ── Footer ────────────────────────────────────────────────
    story.append(Spacer(1, 0.15*cm))
    story.append(HRFlowable(width="100%", thickness=0.5, color=colors.grey))
    story.append(Paragraph(
        to_pdf_html(f"Auto-generated by Gram Nirikshan Mobile App | {datetime.now().strftime('%d/%m/%Y %H:%M')} | Inspection ID: {inspection.inspection_id}"),
        ParagraphStyle("Footer", fontSize=8, fontName='Helvetica', alignment=TA_CENTER, textColor=colors.grey)
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

    result5 = await db.execute(
        select(Approval)
        .where(Approval.inspection_id == inspection_id)
        .options(selectinload(Approval.approver))
    )
    approvals = result5.scalars().all()

    file_name = f"Report_{inspection.inspection_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf"
    output_path = str(REPORTS_DIR / file_name)

    # Check if AI report draft is missing, generate it dynamically using Gemini
    if not inspection.ai_report_draft:
        try:
            from app.api.routes.ai import call_gemini
            
            prompt = f"""Draft a highly formal and professional Gram Panchayat inspection report (Inspection Memo) in English according to the standards of the Rural Development Department.

Inspection Details:
- Inspection ID: {inspection.inspection_id}
- Title: {inspection.title}
- Gram Panchayat: {panchayat.name or panchayat.name_hindi if panchayat else 'N/A'} (District: {inspection.district or (panchayat.district if panchayat else 'N/A')}, Block: {inspection.block or (panchayat.block if panchayat else 'N/A')})
- Inspector/Engineer: {inspection.investigator_name or (engineer.name or engineer.name_hindi if engineer else 'N/A')} (Designation: {engineer.designation or 'Junior Engineer' if engineer else 'N/A'})
- Project/Work Name: {inspection.project_name or 'N/A'} (Work Code: {inspection.project_code or 'N/A'})
- Inspection Type: {inspection.inspection_type or 'General'}

Observations / Notes:
{inspection.observations or 'Site inspection conducted.'}

Corrective Recommendations:
{inspection.recommendations or 'Appropriate corrective measures should be taken.'}

Draft the full English report under the following sections:
1. **Work Description & Key Findings (What was good)**: Details of the site inspection, work progress, and positive findings.
2. **Deficiencies / Issues Identified (What was lacking)**: Technical, quality-related, or administrative deficiencies observed during the inspection.
3. **Corrective Actions / Recommendations (What can be resolved)**: Necessary corrective actions and recommendations to resolve the identified deficiencies.
4. **Conclusion**: Final remarks on work quality and next steps.

Ensure the report is professional, grammatically correct, and written in clear technical English suitable for senior administration."""
            
            ai_draft = await call_gemini(prompt, language="en")
            if ai_draft and not ai_draft.startswith("AI Error:"):
                inspection.ai_report_draft = ai_draft
                await db.flush()
        except Exception as e:
            import logging
            logging.getLogger(__name__).error(f"Failed to auto-generate Gemini report draft: {e}")

    try:
        build_pdf_report(inspection, panchayat, engineer, list(photos), list(approvals), output_path)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"PDF generation failed: {str(e)}")

    # Save PDF report record
    file_size_kb = Path(output_path).stat().st_size // 1024
    report = Report(
        inspection_id=inspection_id,
        generated_by=current_user.id,
        file_path=output_path,
        file_name=file_name,
        file_size_kb=file_size_kb,
        report_format="pdf",
    )
    db.add(report)

    # DOCX Generation
    docx_file_name = f"Report_{inspection.inspection_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.docx"
    docx_output_path = str(REPORTS_DIR / docx_file_name)
    try:
        build_docx_report(inspection, panchayat, engineer, list(photos), list(approvals), docx_output_path)
        docx_file_size_kb = Path(docx_output_path).stat().st_size // 1024
        docx_report = Report(
            inspection_id=inspection_id,
            generated_by=current_user.id,
            file_path=docx_output_path,
            file_name=docx_file_name,
            file_size_kb=docx_file_size_kb,
            report_format="docx",
        )
        db.add(docx_report)
    except Exception as docx_err:
        import logging
        logging.getLogger(__name__).error(f"DOCX generation failed: {docx_err}")

    return MessageResponse(
        message="Reports generated successfully",
        success=True,
        data={"file_name": file_name, "size_kb": file_size_kb},
    )


@router.get("/download/{inspection_id}")
async def download_report(
    inspection_id: str,
    format: str = "pdf",
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Download latest report PDF or DOCX for an inspection."""
    result = await db.execute(
        select(Report).where(Report.inspection_id == inspection_id)
        .where(Report.report_format == format)
        .order_by(Report.created_at.desc())
    )
    report = result.scalars().first()
    if not report or not Path(report.file_path).exists():
        raise HTTPException(status_code=404, detail=f"Report in {format} format not found. Generate it first.")

    media_type = "application/pdf" if format == "pdf" else "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    return FileResponse(
        report.file_path,
        media_type=media_type,
        filename=report.file_name,
    )

