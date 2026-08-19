# ============================================================
# HEALTH AI — CHAT ROUTER (RAG ENABLED)
# Flutter → FastAPI → pgvector retrieval → Gemini 2.5 Flash
#
# RAG Flow:
#   1. User message arrives
#   2. Embed message → similarity search in pgvector
#   3. Retrieve top 5 relevant health data chunks
#   4. Inject chunks into Gemini system prompt
#   5. Gemini answers with full user context (not just today)
# ============================================================

import os
from typing import Any, List, Optional

from dotenv import load_dotenv
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import google.generativeai as genai

from rag_service import RAGService

# ── Load .env ─────────────────────────────────────────────────
load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
if not GEMINI_API_KEY:
    print("WARNING: GEMINI_API_KEY not set. Chat endpoint will return 503.")
else:
    genai.configure(api_key=GEMINI_API_KEY)
    print(f"Gemini configured ✅ (key ends with ...{GEMINI_API_KEY[-6:]})")

router = APIRouter(prefix="/chat", tags=["chat"])

# ── RAG service singleton ─────────────────────────────────────
_rag = RAGService()

# ============================================================
# MODELS
# ============================================================

class ConversationMessage(BaseModel):
    role: str       # "user" or "assistant"
    content: str

class ChatRequest(BaseModel):
    user_id: str
    message: str

    # User context — passed from Flutter with every message
    user_name: str = "User"
    age: int = 0
    gender: str = ""
    occupation: str = ""
    country: str = ""

    # Latest health data (today's check-in)
    health_score: float = 0.0
    sleep_hours: float = 0.0
    steps: int = 0
    water_intake_l: float = 0.0
    mood_score: float = 5.0
    stress_level: float = 5.0
    exercise_minutes: float = 0.0
    diet_quality: str = ""
    weight_kg: Optional[float] = None

    # Domain scores
    physical_score: float = 0.0
    mental_score: float = 0.0
    diet_score: float = 0.0
    risk_score: float = 0.0

    # Conversation history (last 20 messages)
    history: List[ConversationMessage] = []

class ChatResponse(BaseModel):
    reply: str
    user_id: str

# ============================================================
# SYSTEM PROMPT BUILDER — Now includes RAG context
# ============================================================

def _build_system_prompt(req: ChatRequest, rag_context: str) -> str:
    name = req.user_name if req.user_name else "there"

    # ── Health score label ────────────────────────────────────
    health_status = "Not yet calculated"
    if req.health_score > 0:
        if req.health_score >= 80:
            health_status = f"{req.health_score:.1f}/100 — Excellent"
        elif req.health_score >= 65:
            health_status = f"{req.health_score:.1f}/100 — Good"
        elif req.health_score >= 50:
            health_status = f"{req.health_score:.1f}/100 — Fair"
        else:
            health_status = f"{req.health_score:.1f}/100 — Needs Work"

    # ── Profile lines ─────────────────────────────────────────
    profile_lines = []
    if req.age > 0:
        profile_lines.append(f"Age: {req.age}")
    if req.gender:
        profile_lines.append(f"Gender: {req.gender}")
    if req.occupation:
        profile_lines.append(f"Occupation: {req.occupation}")
    if req.country:
        profile_lines.append(f"Country: {req.country}")

    # ── Today's check-in lines ────────────────────────────────
    checkin_lines = [f"Health Score: {health_status}"]
    if req.sleep_hours > 0:
        checkin_lines.append(f"Sleep: {req.sleep_hours:.1f} hrs (target: 8 hrs)")
    if req.steps > 0:
        checkin_lines.append(f"Steps: {req.steps:,} (target: 8,000)")
    if req.water_intake_l > 0:
        checkin_lines.append(f"Water: {req.water_intake_l:.1f} L (target: 2.5 L)")
    if req.exercise_minutes > 0:
        checkin_lines.append(f"Exercise: {req.exercise_minutes:.0f} min")
    if req.mood_score > 0:
        checkin_lines.append(f"Mood: {req.mood_score:.0f}/10")
    if req.stress_level > 0:
        checkin_lines.append(f"Stress: {req.stress_level:.0f}/10")
    if req.diet_quality:
        checkin_lines.append(f"Diet Quality: {req.diet_quality}")
    if req.weight_kg:
        checkin_lines.append(f"Weight: {req.weight_kg:.1f} kg")

    # ── Domain scores ─────────────────────────────────────────
    domain_lines = []
    if req.physical_score > 0:
        domain_lines.append(f"Physical: {req.physical_score:.1f}/40")
    if req.mental_score > 0:
        domain_lines.append(f"Mental: {req.mental_score:.1f}/15")
    if req.diet_score > 0:
        domain_lines.append(f"Diet: {req.diet_score:.1f}/25")
    if req.risk_score > 0:
        domain_lines.append(f"Risk: {req.risk_score:.1f}/15")

    # ── RAG context section ───────────────────────────────────
    rag_section = ""
    if rag_context.strip():
        rag_section = f"""
RETRIEVED HEALTH HISTORY (from user's past logs, medications, recommendations):
Use this to give specific, personalised answers based on the user's real data history.
{rag_context}
"""

    return f"""You are Health AI — a personal health assistant built into the Health AI app.
You are warm, empathetic, evidence-based, and motivating. You give concise, practical advice.

USER PROFILE:
Name: {name}
{chr(10).join(profile_lines) if profile_lines else 'Profile not yet set up'}

TODAY'S HEALTH CHECK-IN:
{chr(10).join(checkin_lines)}
{f"Domain Scores — {', '.join(domain_lines)}" if domain_lines else ""}
{rag_section}
INSTRUCTIONS:
- Address the user by first name: {name}
- Use the RETRIEVED HEALTH HISTORY section above to give specific answers about their trends
- For example: if they ask 'how was my sleep this week?' — use the retrieved log data to answer
- If retrieved data is not relevant to the question, just use today's check-in data
- Reference their real health numbers when answering — never make up data
- Give specific, actionable advice tied to their actual numbers
- Be encouraging — celebrate wins, reframe setbacks positively
- Keep responses concise: 2–4 short paragraphs or a brief bullet list
- For serious medical conditions or medication dosages, always advise consulting a doctor
- Never fabricate data — only reference what is provided above
- You can explain health concepts, suggest lifestyle tweaks, decode their scores, and motivate
- If the user hasn't done a check-in yet (score = 0), encourage them to do one
- Respond in the same language the user writes in
- Do NOT use markdown formatting like **bold** or ## headers — write in plain conversational text
"""

# ============================================================
# ENDPOINT
# ============================================================

@router.post("/message", response_model=ChatResponse)
async def send_message(req: ChatRequest):
    """
    RAG-enhanced chat endpoint.

    Steps:
    1. Retrieve relevant health history from pgvector (using question as query)
    2. Inject retrieved context into Gemini system prompt
    3. Call Gemini 2.5 Flash with full conversation history
    4. Return grounded, personalised response
    """
    if not GEMINI_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="GEMINI_API_KEY not configured on server"
        )

    try:
        # ── STEP 1: RAG Retrieval ─────────────────────────────
        # Embed the user's question and find the most relevant
        # health data chunks from pgvector
        rag_context = _rag.retrieve(
            user_id=req.user_id,
            query=req.message,
            top_k=5
        )

        # ── STEP 2: Build system prompt with RAG context ──────
        system_prompt = _build_system_prompt(req, rag_context)

        # ── STEP 3: Build Gemini conversation history ─────────
        gemini_history = []
        for msg in req.history[-20:]:
            gemini_history.append({
                "role":  "user" if msg.role == "user" else "model",
                "parts": [msg.content],
            })

        # ── STEP 4: Call Gemini 2.5 Flash ────────────────────
        model = genai.GenerativeModel(
            model_name="gemini-2.5-flash",
            system_instruction=system_prompt,
        )

        chat     = model.start_chat(history=gemini_history)  # type: ignore[arg-type]
        response = chat.send_message(req.message)

        return ChatResponse(
            reply=response.text.strip(),
            user_id=req.user_id,
        )

    except Exception as e:
        print(f"Chat error: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Chat error: {str(e)}"
        )


# ============================================================
# EMBEDDING ENDPOINTS
# Flutter calls these after saving profile / medication to Supabase
# ============================================================

class ProfileEmbedRequest(BaseModel):
    user_id: str
    age: Optional[int] = None
    gender: str = ""
    occupation: str = ""
    country: str = ""
    height_cm: Optional[float] = None
    smoking_habit: str = ""
    alcohol_consumption: str = ""
    diabetes: str = "No"
    under_treatment: str = "No"
    mental_health_condition: str = "None"
    current_diseases: str = "—"
    past_diseases: str = "—"

class MedicationEmbedRequest(BaseModel):
    user_id: str
    name: str
    dosage: str
    frequency: str = "Daily"
    times: List[str] = []
    food_relation: str = "After food"
    duration_days: int = 7
    start_date: str = ""
    notes: str = ""


@router.post("/embed/profile")
async def embed_profile(req: ProfileEmbedRequest):
    """
    Flutter calls this after saving/updating health profile.
    Embeds profile into pgvector so Gemini knows user's medical background.
    """
    try:
        _rag.store_profile(req.user_id, req.model_dump())
        return {"status": "ok", "message": "Profile embedded successfully"}
    except Exception as e:
        print(f"embed_profile error: {e}")
        return {"status": "error", "message": str(e)}


@router.post("/embed/medication")
async def embed_medication(req: MedicationEmbedRequest):
    """
    Flutter calls this after adding a new medication.
    Embeds medication into pgvector so Gemini knows the user's medicine schedule.
    """
    try:
        _rag.store_medication(req.user_id, req.model_dump())
        return {"status": "ok", "message": "Medication embedded successfully"}
    except Exception as e:
        print(f"embed_medication error: {e}")
        return {"status": "error", "message": str(e)}
