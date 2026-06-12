"""
Gemini AI Assistant routes: chat, inspection guidance, report suggestions.
Supports Hindi and English language responses.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import google.generativeai as genai
import logging

from app.db.database import get_db
from app.models.models import Inspection, Panchayat, User
from app.schemas.schemas import AIChatRequest, AIChatResponse, AIReportSuggestion, MessageResponse
from app.core.dependencies import get_current_user
from app.core.config import settings

router = APIRouter(prefix="/ai", tags=["AI Assistant"])
logger = logging.getLogger(__name__)

# Configure Gemini
if settings.GEMINI_API_KEY:
    genai.configure(api_key=settings.GEMINI_API_KEY)


SYSTEM_PROMPT_EN = """You are the Gram Nirikshan AI Assistant - an expert assistant for 
Gram Panchayat field engineers in India. You help with:
1. Inspection guidance and best practices
2. Report writing suggestions
3. Government scheme information
4. Technical queries about rural infrastructure
5. Compliance and documentation requirements

Provide practical, actionable advice. Be concise but thorough.
When answering about government schemes, cite the scheme name clearly."""

SYSTEM_PROMPT_HI = """आप ग्राम निरीक्षण AI सहायक हैं - भारत में ग्राम पंचायत क्षेत्र 
इंजीनियरों के लिए एक विशेषज्ञ सहायक। आप इनमें मदद करते हैं:
1. निरीक्षण मार्गदर्शन और सर्वोत्तम अभ्यास
2. रिपोर्ट लेखन सुझाव
3. सरकारी योजना की जानकारी
4. ग्रामीण बुनियादी ढांचे के बारे में तकनीकी प्रश्न
5. अनुपालन और दस्तावेज़ीकरण आवश्यकताएं

व्यावहारिक, कार्रवाई योग्य सलाह दें। संक्षिप्त लेकिन विस्तृत रहें।"""


async def call_gemini(prompt: str, language: str = "en") -> str:
    """Call Gemini API with the given prompt."""
    if not settings.GEMINI_API_KEY:
        return ("AI सहायक उपलब्ध नहीं है। कृपया Gemini API key सेट करें।"
                if language == "hi" else
                "AI Assistant not available. Please configure GEMINI_API_KEY.")

    try:
        # Prepend system instruction to prompt for backwards compatibility with older google-generativeai versions (e.g. 0.3.2)
        system_instruction = SYSTEM_PROMPT_HI if language == "hi" else SYSTEM_PROMPT_EN
        full_prompt = f"{system_instruction}\n\nUser Query:\n{prompt}"
        
        model = genai.GenerativeModel(
            model_name=settings.GEMINI_MODEL,
        )
        response = model.generate_content(full_prompt)
        return response.text
    except Exception as e:
        logger.error(f"Gemini API error: {e}")
        return f"AI Error: {str(e)}"


@router.post("/chat", response_model=AIChatResponse)
async def ai_chat(
    request: AIChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """AI chat for inspection assistance."""
    context = ""
    if request.inspection_id:
        result = await db.execute(select(Inspection).where(Inspection.id == request.inspection_id))
        inspection = result.scalar_one_or_none()
        if inspection:
            result2 = await db.execute(select(Panchayat).where(Panchayat.id == inspection.panchayat_id))
            panchayat = result2.scalar_one_or_none()
            context = f"""
Context:
- Inspection: {inspection.title}
- Panchayat: {panchayat.name if panchayat else 'N/A'} ({panchayat.district if panchayat else 'N/A'})
- Type: {inspection.inspection_type or 'General'}
- Status: {inspection.status.value}
- Observations: {inspection.observations or 'None yet'}
"""

    prompt = f"{context}\nEngineer Query: {request.message}"
    response_text = await call_gemini(prompt, request.language)

    # Extract suggestions (lines starting with - or numbered)
    lines = response_text.split("\n")
    suggestions = [l.strip("- ").strip() for l in lines if l.startswith(("-", "1.", "2.", "3.")) and len(l) > 10][:5]

    return AIChatResponse(response=response_text, suggestions=suggestions if suggestions else None)


@router.post("/suggest-report", response_model=AIChatResponse)
async def suggest_report(
    request: AIReportSuggestion,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Generate AI report suggestions for an inspection."""
    result = await db.execute(select(Inspection).where(Inspection.id == request.inspection_id))
    inspection = result.scalar_one_or_none()
    if not inspection:
        raise HTTPException(status_code=404, detail="Inspection not found")

    result2 = await db.execute(select(Panchayat).where(Panchayat.id == inspection.panchayat_id))
    panchayat = result2.scalar_one_or_none()

    prompt = f"""Generate a professional inspection report draft for the following inspection:
    
Inspection Title: {inspection.title}
Panchayat: {panchayat.name if panchayat else 'N/A'}, {panchayat.district if panchayat else 'N/A'}
Inspection Type: {inspection.inspection_type or 'General'}
Project: {inspection.project_name or 'N/A'}
Observations: {inspection.observations or 'Field inspection conducted'}
Engineer Notes: {inspection.description or 'Standard inspection'}

Please write:
1. Executive Summary (2-3 sentences)
2. Key Findings (bullet points)
3. Recommendations (numbered list)
4. Next Steps

Format it professionally for a government department report."""

    response = await call_gemini(prompt, "en")

    # Store AI draft
    inspection.ai_report_draft = response
    await db.flush()

    return AIChatResponse(response=response)


@router.post("/inspection-guide", response_model=AIChatResponse)
async def inspection_guide(
    inspection_type: str = "general",
    language: str = "hi",
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get AI guidance for conducting a specific type of inspection."""
    prompt = f"""Provide a step-by-step inspection checklist and guidance for:
    
Inspection Type: {inspection_type}
Context: Gram Panchayat field inspection in India

Include:
1. Pre-inspection preparation
2. On-site checklist (10-15 items)
3. Documentation requirements
4. Common issues to look for
5. Safety guidelines

Language: {'Hindi' if language == 'hi' else 'English'}"""

    response = await call_gemini(prompt, language)
    return AIChatResponse(response=response)
