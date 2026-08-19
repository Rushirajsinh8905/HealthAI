# ============================================================
# HEALTH AI — RAG SERVICE
# Handles embedding generation (Gemini) + storage/retrieval (Supabase pgvector)
#
# Flow:
#   STORE: check-in log + TFT recommendations → embed → pgvector
#   RETRIEVE: user question → embed → similarity search → relevant chunks
#   INJECT: retrieved chunks → Gemini system prompt → grounded answer
# ============================================================

import os
from typing import Any, List, Optional
from datetime import datetime

from dotenv import load_dotenv
from google import genai
from google.genai.types import EmbedContentConfig
from supabase import create_client, Client

load_dotenv()

# ── Env vars ─────────────────────────────────────────────────
SUPABASE_URL         = os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "")
GEMINI_API_KEY       = os.getenv("GEMINI_API_KEY", "")

# Gemini embedding model — gemini-embedding-001 (replaces deprecated text-embedding-001/004)
# output_dimensionality=768 keeps backward compatibility with existing Supabase vector(768) column
EMBED_MODEL = "gemini-embedding-001"


# ============================================================
# RAG SERVICE — Singleton
# ============================================================

class RAGService:
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._initialized = False
        return cls._instance

    def __init__(self):
        if self._initialized:
            return
        self._initialized = True

        # ── Supabase client ───────────────────────────────────
        if SUPABASE_URL and SUPABASE_SERVICE_KEY:
            self.supabase: Optional[Client] = create_client(
                SUPABASE_URL, SUPABASE_SERVICE_KEY
            )
            print("RAGService: Supabase connected ✅")
        else:
            self.supabase = None
            print("RAGService ⚠️  Supabase credentials missing — RAG disabled")

        # ── Gemini embedding client (new google-genai SDK) ────
        self._genai_client: Optional[Any] = None
        if GEMINI_API_KEY:
            self._genai_client = genai.Client(api_key=GEMINI_API_KEY)

    # ──────────────────────────────────────────────────────────
    # PRIVATE: Generate embedding vector
    # ──────────────────────────────────────────────────────────
    def _embed(self, text: str, task_type: str = "retrieval_document") -> List[float]:
        """Convert text → 768-dim vector using Gemini Embedding API (google-genai SDK)."""
        if not self._genai_client:
            print("RAGService._embed: Gemini client not initialized (missing API key)")
            return []
        try:
            response = self._genai_client.models.embed_content(
            model=EMBED_MODEL,
            contents=text,
            config=EmbedContentConfig(
            task_type=task_type,
            output_dimensionality=768,   # ← backward compatible with your Supabase vector(768)
    )
)
            return list(response.embeddings[0].values)  # type: ignore[index,return-value]
        except Exception as e:
            print(f"RAGService._embed error: {e}")
            return []

    # ──────────────────────────────────────────────────────────
    # PRIVATE: Delete old embedding before inserting new one
    # Prevents duplicate embeddings for same user + date + type
    # ──────────────────────────────────────────────────────────
    def _delete_old(self, user_id: str, chunk_type: str, chunk_date: Optional[str] = None):
        if not self.supabase:
            return
        try:
            query = self.supabase.table("health_embeddings") \
                .delete() \
                .eq("user_id", user_id) \
                .eq("chunk_type", chunk_type)

            if chunk_date:
                query = query.eq("chunk_date", chunk_date)

            query.execute()
        except Exception as e:
            print(f"RAGService._delete_old error: {e}")

    # ──────────────────────────────────────────────────────────
    # STORE: Daily check-in log
    # Called from /recommend endpoint after TFT analysis
    # ──────────────────────────────────────────────────────────
    def store_daily_log(
        self,
        user_id: str,
        log: dict,
        scores: dict
    ):
        """
        Converts today's check-in data into a readable text chunk,
        embeds it, and stores in pgvector. Old log for same date is deleted first.
        """
        if not self.supabase:
            return

        date = log.get("date", datetime.now().strftime("%Y-%m-%d"))
        health_score = scores.get("health_score", 0)

        # ── Build human-readable text chunk ───────────────────
        content = f"""Daily Health Log — {date}
Overall Health Score: {health_score:.1f} / 100
Sleep: {log.get('Sleep_Hours', 0):.1f} hrs
Steps: {int(log.get('Steps', 0)):,} steps
Water: {log.get('Water_Intake_L', 0):.1f} L
Exercise: {int(log.get('Exercise_Minutes', 0))} min
Mood: {log.get('Mood_Score', 0):.0f} / 10
Stress Level: {log.get('Stress_Level', 0):.0f} / 10
Diet Quality: {log.get('Diet_Quality', 'unknown')}
Calories: {log.get('final_calories', 0):.0f} kcal
Protein: {log.get('final_protein', 0):.0f}g | Carbs: {log.get('final_carbs', 0):.0f}g | Fat: {log.get('final_fat', 0):.0f}g
Physical Score: {scores.get('physical_score', 0):.1f} / 40
Mental Score: {scores.get('mental_score', 0):.1f} / 15
Diet Score: {scores.get('diet_score', 0):.1f} / 25
Risk Score: {scores.get('risk_score', 0):.1f} / 15"""

        try:
            embedding = self._embed(content)
            if not embedding:
                return

            # Delete previous log for same date to avoid duplicates
            self._delete_old(user_id, "daily_log", date)

            self.supabase.table("health_embeddings").insert({
                "user_id":    user_id,
                "content":    content,
                "embedding":  embedding,
                "chunk_type": "daily_log",
                "chunk_date": date,
            }).execute()

            print(f"RAGService: stored daily log embedding for {date} ✅")

        except Exception as e:
            print(f"RAGService.store_daily_log error: {e}")

    # ──────────────────────────────────────────────────────────
    # STORE: TFT Recommendations
    # Called from /recommend endpoint
    # ──────────────────────────────────────────────────────────
    def store_recommendations(
        self,
        user_id: str,
        baseline_score: float,
        recommendations: list,
        date: str
    ):
        """
        Stores TFT-powered recommendations as a text chunk.
        Gemini can reference these when user asks 'what should I improve?'
        """
        if not self.supabase:
            return

        rec_lines = []
        for r in recommendations:
            rec_lines.append(
                f"  #{r['rank']} {r['feature']}: "
                f"{r['current_value']} → {r['target_value']} "
                f"(predicted +{r['delta']:.2f} pts). Tip: {r.get('tip', '')}"
            )

        content = f"""AI Health Recommendations — {date}
Baseline Health Score: {baseline_score:.1f} / 100
Top improvements suggested by AI model:
{chr(10).join(rec_lines)}"""

        try:
            embedding = self._embed(content)
            if not embedding:
                return

            self._delete_old(user_id, "recommendation", date)

            self.supabase.table("health_embeddings").insert({
                "user_id":    user_id,
                "content":    content,
                "embedding":  embedding,
                "chunk_type": "recommendation",
                "chunk_date": date,
            }).execute()

            print(f"RAGService: stored recommendations embedding ✅")

        except Exception as e:
            print(f"RAGService.store_recommendations error: {e}")

    # ──────────────────────────────────────────────────────────
    # STORE: Medication
    # Called from /embed/medication endpoint (Flutter calls after adding med)
    # ──────────────────────────────────────────────────────────
    def store_medication(self, user_id: str, medication: dict):
        """
        Stores medication info so Gemini knows the user's medicine schedule.
        Allows answers like: 'you take Paracetamol after food at 8 AM and 8 PM'
        """
        if not self.supabase:
            return

        times_str = ", ".join(medication.get("times", []))
        med_name  = medication.get("name", "Unknown")

        content = f"""Medication: {med_name} {medication.get('dosage', '')}
Frequency: {medication.get('frequency', 'Daily')}
Reminder Times: {times_str}
Food Relation: {medication.get('food_relation', 'After food')}
Duration: {medication.get('duration_days', 0)} days
Started: {medication.get('start_date', 'unknown')}
Notes: {medication.get('notes', 'None')}"""

        try:
            embedding = self._embed(content)
            if not embedding:
                return

            # Delete old embedding for this medicine before inserting
            # so we don't duplicate on re-add
            self.supabase.table("health_embeddings") \
                .delete() \
                .eq("user_id", user_id) \
                .eq("chunk_type", "medication") \
                .like("content", f"%Medication: {med_name}%") \
                .execute()

            self.supabase.table("health_embeddings").insert({
                "user_id":    user_id,
                "content":    content,
                "embedding":  embedding,
                "chunk_type": "medication",
                "chunk_date": None,
            }).execute()

            print(f"RAGService: stored medication embedding ({med_name}) ✅")

        except Exception as e:
            print(f"RAGService.store_medication error: {e}")

    # ──────────────────────────────────────────────────────────
    # STORE: User Profile
    # Called from /embed/profile endpoint (Flutter calls after profile save)
    # ──────────────────────────────────────────────────────────
    def store_profile(self, user_id: str, profile: dict):
        """
        Stores static profile so Gemini knows conditions, diseases, habits.
        Allows answers like: 'given your hypertension, you should...'
        """
        if not self.supabase:
            return

        content = f"""User Health Profile:
Age: {profile.get('age', 'unknown')} | Gender: {profile.get('gender', 'unknown')}
Occupation: {profile.get('occupation', 'unknown')} | Country: {profile.get('country', 'unknown')}
Height: {profile.get('height_cm', 'unknown')} cm
Smoking Habit: {profile.get('smoking_habit', 'unknown')}
Alcohol Consumption: {profile.get('alcohol_consumption', 'unknown')}
Diabetes: {profile.get('diabetes', 'No')}
Under Medical Treatment: {profile.get('under_treatment', 'No')}
Mental Health Condition: {profile.get('mental_health_condition', 'None')}
Current Diseases: {profile.get('current_diseases', '—')}
Past Diseases: {profile.get('past_diseases', '—')}"""

        try:
            embedding = self._embed(content)
            if not embedding:
                return

            # One profile embedding per user — delete old and replace
            self._delete_old(user_id, "profile")

            self.supabase.table("health_embeddings").insert({
                "user_id":    user_id,
                "content":    content,
                "embedding":  embedding,
                "chunk_type": "profile",
                "chunk_date": None,
            }).execute()

            print(f"RAGService: stored profile embedding ✅")

        except Exception as e:
            print(f"RAGService.store_profile error: {e}")

    # ──────────────────────────────────────────────────────────
    # RETRIEVE: Similarity search for chat
    # Called in /chat/message before Gemini is invoked
    # ──────────────────────────────────────────────────────────
    def retrieve(
        self,
        user_id: str,
        query: str,
        top_k: int = 5
    ) -> str:
        """
        Embeds the user's question, runs cosine similarity search in pgvector,
        returns the top_k most relevant chunks as a single joined string.

        Returns empty string if Supabase is unavailable or no data found.
        """
        if not self.supabase:
            return ""

        try:
            # Embed the query with retrieval_query task type
            query_embedding = self._embed(query, task_type="retrieval_query")
            if not query_embedding:
                return ""

            # Call Supabase RPC function (defined in supabase_setup.sql)
            result = self.supabase.rpc("match_health_embeddings", {
                "query_embedding": query_embedding,
                "match_user_id":   user_id,
                "match_count":     top_k,
            }).execute()

            if not result.data:
                print(f"RAGService.retrieve: no chunks found for user {user_id}")
                return ""

            chunks = [str(row["content"]) for row in result.data]  # type: ignore[index]
            context = "\n\n---\n\n".join(chunks)
            
            print("Retrieved documents:", chunks)


            print(f"RAGService.retrieve: fetched {len(chunks)} chunks ✅")
            return context

        except Exception as e:
            print(f"RAGService.retrieve error: {e}")
            return ""
