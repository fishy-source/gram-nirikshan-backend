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

व्यावहारिक, कार्रवाई योग्य सलाह दें। संक्षिप्त लेकिन विस्तृत रहें।

आपको उत्तर देते समय और पीडीएफ (PDF) रिपोर्ट के लिए आख्या तैयार करते समय निम्नलिखित 10 अनिवार्य नियमों का पूर्णतः पालन करना होगा:
1. हमेशा शुद्ध, व्याकरणिक और मानक हिंदी (Standard Hindi) में उत्तर दें।
2. वर्तनी (Spelling), मात्रा, विराम चिह्न (Punctuation) और व्याकरण (Grammar) में कोई गलती न करें।
3. उत्तर सरल, स्पष्ट और बच्चों सहित सभी आयु वर्ग के लोगों के लिए समझने योग्य हो।
4. अंग्रेज़ी शब्दों का प्रयोग केवल तभी करें जब उनका सामान्य हिंदी विकल्प उपलब्ध न हो।
5. यदि उपयोगकर्ता टूटी-फूटी हिंदी या हिंग्लिश लिखे, तब भी उत्तर शुद्ध और मानक हिंदी में दें।
6. किसी भी उत्तर को भेजने से पहले उसकी वर्तनी और व्याकरण की स्वयं जाँच करें।
7. कठिन शब्दों के स्थान पर सामान्य प्रचलित हिंदी शब्दों का उपयोग करें।
8. सभी संख्याएँ और माप स्पष्ट रूप से लिखें।
9. उत्तर में अनावश्यक अंग्रेज़ी, हिंग्लिश या रोमन हिंदी का प्रयोग न करें।
10. यदि किसी शब्द की वर्तनी संदिग्ध हो, तो सबसे अधिक प्रचलित और मानक हिंदी वर्तनी का उपयोग करें।"""


async def call_gemini(prompt: str, language: str = "en") -> str:
    """Call Gemini API with the given prompt."""
    if not settings.GEMINI_API_KEY:
        return ("AI सहायक उपलब्ध नहीं है। कृपया Gemini API key सेट करें।"
                if language == "hi" else
                "AI Assistant not available. Please configure GEMINI_API_KEY.")

    # List of fallback models to try in order
    model_name = settings.GEMINI_MODEL
    fallback_models = [model_name]
    
    # Add standard available models as fallbacks
    for fallback in ["gemini-2.5-flash", "gemini-2.5-pro", "gemini-2.0-flash"]:
        if fallback not in fallback_models:
            fallback_models.append(fallback)

    last_error = None
    for model_to_try in fallback_models:
        clean_model_name = model_to_try
        if clean_model_name.startswith("models/"):
            clean_model_name = clean_model_name.replace("models/", "")
            
        # Map unsupported/deprecated model names to supported ones
        if clean_model_name == "gemini-1.5-pro":
            clean_model_name = "gemini-2.5-pro"
        elif clean_model_name == "gemini-1.5-flash":
            clean_model_name = "gemini-2.5-flash"
            
        try:
            # Prepend system instruction to prompt for backwards compatibility
            system_instruction = SYSTEM_PROMPT_HI if language == "hi" else SYSTEM_PROMPT_EN
            full_prompt = f"{system_instruction}\n\nUser Query:\n{prompt}"
            
            model = genai.GenerativeModel(
                model_name=clean_model_name,
            )
            response = model.generate_content(full_prompt)
            return response.text
        except Exception as e:
            logger.warning(f"Failed to generate content with model {clean_model_name}: {e}. Trying fallback...")
            last_error = e
            
    logger.error(f"Gemini API error (all fallbacks failed): {last_error}")
    return f"AI Error: {str(last_error)}"


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

    prompt = f"""उत्तर प्रदेश सरकार के ग्राम विकास विभाग के मानकों के अनुसार एक अत्यंत औपचारिक और पेशेवर ग्राम पंचायत निरीक्षण रिपोर्ट (निरीक्षण आख्या) का हिंदी में मसौदा तैयार करें।

निरीक्षण विवरण:
- निरीक्षण का शीर्षक: {inspection.title}
- ग्राम पंचायत: {panchayat.name_hindi or panchayat.name if panchayat else 'N/A'} (जनपद: {inspection.district or (panchayat.district if panchayat else 'N/A')}, विकास खंड: {inspection.block or (panchayat.block if panchayat else 'N/A')})
- निरीक्षण प्रकार: {inspection.inspection_type or 'सामान्य'}
- परियोजना/कार्य का नाम: {inspection.project_name or 'N/A'} (코드/संकेतांक: {inspection.project_code or 'N/A'})
- दिनांक: {str(inspection.inspection_date)[:10] if inspection.inspection_date else 'N/A'}
- जांचकर्ता/इंजीनियर: {inspection.investigator_name or current_user.name_hindi or current_user.name} (पद: {current_user.designation or 'अवर अभियंता'})

निरीक्षण के मुख्य बिंदु (Observations / Notes):
{inspection.observations or 'स्थल निरीक्षण किया गया।'}
{inspection.description or ''}

निम्नलिखित शीर्षकों के अंतर्गत पूर्ण हिंदी रिपोर्ट तैयार करें (कोई अंग्रेजी शब्द या अंग्रेजी/हिंदी का मिश्रण न हो, भाषा विशुद्ध प्रशासनिक/सरकारी राजभाषा हिंदी होनी चाहिए):

1. **कार्य का विवरण व निरीक्षण में क्या पाया गया (क्या अच्छा था)**: कार्य स्थल पर किए गए निरीक्षण का विवरण, कार्य की प्रगति और क्या सकारात्मक/अच्छा पाया गया।
2. **पाई गई कमियां (क्या कमियां थीं)**: निरीक्षण के दौरान पाई गई तकनीकी, गुणवत्ता संबंधी या प्रशासनिक कमियां।
3. **कमियों के सुधार हेतु सुझाव व उपाय (क्या निदान किया जा सकता है)**: पाई गई कमियों को दूर करने के लिए किए जाने वाले आवश्यक सुधार कार्य और निदान।
4. **निष्कर्ष (Conclusion)**: कार्य की गुणवत्ता पर अंतिम टिप्पणी और अग्रिम कार्रवाई हेतु निष्कर्ष।

रिपोर्ट तैयार करते समय निम्नलिखित 10 अनिवार्य नियमों का पूर्णतः पालन करें:
1. हमेशा शुद्ध, व्याकरणिक और मानक हिंदी में ही रिपोर्ट लिखें।
2. वर्तनी (Spelling), मात्रा, विराम चिह्न और व्याकरण में कोई गलती न करें।
3. रिपोर्ट की भाषा सरल, स्पष्ट और सभी के लिए समझने योग्य हो।
4. अंग्रेज़ी शब्दों का प्रयोग केवल तभी करें जब उनका सामान्य हिंदी विकल्प उपलब्ध न हो।
5. इनपुट विवरण में हिंग्लिश या मिश्रित भाषा होने पर भी अंतिम रिपोर्ट विशुद्ध और मानक हिंदी में ही बनाएं।
6. आख्या पूर्ण करने से पहले उसकी वर्तनी और व्याकरण की स्वयं जाँच करें।
7. कठिन शब्दों के स्थान पर सामान्य प्रचलित हिंदी शब्दों का उपयोग करें।
8. सभी संख्याएँ और माप स्पष्ट रूप से लिखें।
9. रिपोर्ट में अनावश्यक अंग्रेज़ी, हिंग्लिश या रोमन हिंदी का प्रयोग न करें।
10. यदि किसी शब्द की वर्तनी संदिग्ध हो, तो सबसे अधिक प्रचलित और मानक हिंदी वर्तनी का उपयोग करें।"""

    response = await call_gemini(prompt, "hi")

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
