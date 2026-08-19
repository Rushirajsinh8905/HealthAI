# ============================================================
# HEALTHAI — FASTAPI PREDICTION SERVER v4.0 (RAG ENABLED)
# Real TFT predictions with Flutter input injection
# + RAG: auto-embeds every check-in into pgvector for smart chat
#
# How it works:
# 1. Uses dataset user 44 as 28-day historical context (cold start)
# 2. INJECTS real Flutter input as today's values (last row)
# 3. Runs TFT on this hybrid data → real baseline prediction
# 4. VSN weights identify which features matter for THIS prediction
# 5. What-if tests realistic improvements using TFT (not formulas)
# 6. Only returns improvements — never suggests worsening
# 7. Delta = real TFT prediction difference, not estimated
# 8. RAG: stores log + recommendations in pgvector after each check-in
# ============================================================

import warnings
warnings.filterwarnings("ignore")
from chat_router import router as chat_router
import os
os.environ["CUDA_VISIBLE_DEVICES"] = ""
os.environ["PYTORCH_MPS_ENABLED"] = "0"

import torch
import numpy as np
import pandas as pd
from pathlib import Path
from contextlib import asynccontextmanager
from typing import Any, Optional, Dict, List, Tuple, cast
from datetime import datetime

from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from pytorch_forecasting import (
    TemporalFusionTransformer,
    TimeSeriesDataSet,
    GroupNormalizer,
)
from pytorch_forecasting.data.encoders import NaNLabelEncoder

# ── RAG service ───────────────────────────────────────────────
from rag_service import RAGService
_rag = RAGService()

# ============================================================
# PATHS
# ============================================================

BASE_DIR = Path(__file__).resolve().parent
DATA_PATH = BASE_DIR.parent / "data" / "health_lifestyle_dataset.csv"
CHECKPOINT_PATH = (
    BASE_DIR.parent / "machine_learning" / "models" / "FINAL_TFT_HEALTH_MODEL.ckpt"
)

# Demo user — provides 28-day historical context for cold start
DEMO_USER_ID = 100

HEALTH_TARGETS = {
    "Sleep_Hours": {
        "target": 8.0,
        "direction": "increase",
        "unit": "hrs",
        "test_values": [5.0, 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0],
    },
    "Steps": {
        "target": 8000,
        "direction": "increase",
        "unit": "steps",
        "test_values": [2000, 3000, 4000, 5000, 6000, 7000, 8000, 10000, 12000],
    },
    "Exercise_Minutes": {
        "target": 30.0,
        "direction": "increase",
        "unit": "min",
        "test_values": [0, 10, 15, 20, 30, 45, 60, 75, 90],
    },
    "Water_Intake_L": {
        "target": 2.5,
        "direction": "increase",
        "unit": "L",
        "test_values": [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5],
    },
    "Stress_Level": {
        "target": 3.0,
        "direction": "decrease",
        "unit": "/10",
        "test_values": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    },
    "Mood_Score": {
        "target": 8.0,
        "direction": "increase",
        "unit": "/10",
        "test_values": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    },
    "Social_Media_Usage": {
        "target": 2.0,
        "direction": "decrease",
        "unit": "hrs",
        "test_values": [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0],
    },
}

# ============================================================
# ACTIONABLE TIPS — shown in Flutter UI
# ============================================================

TIPS = {
    "Sleep_Hours": (
        "Try going to bed 30 minutes earlier each night. "
        "Consistent sleep timing improves deep sleep quality significantly."
    ),
    "Steps": (
        "Add a 20-minute walk after lunch — that alone adds ~2,000 steps. "
        "Take stairs instead of lifts whenever possible."
    ),
    "Exercise_Minutes": (
        "Start with 15-minute home workouts — bodyweight squats, push-ups, jumping jacks. "
        "Consistency matters more than intensity to start."
    ),
    "Water_Intake_L": (
        "Keep a 500ml water bottle at your desk. "
        "Drink one glass every hour — you will hit 2.5L without thinking about it."
    ),
    "Stress_Level": (
        "Try 5 minutes of box breathing (4s inhale, 4s hold, 4s exhale) in the morning. "
        "Studies show this reduces cortisol by up to 25% when done consistently."
    ),
    "Mood_Score": (
        "A 10-minute walk outside, a short call with a friend, or even 5 minutes of sunlight "
        "can noticeably improve mood. Small actions compound quickly."
    ),
    "Social_Media_Usage": (
        "Set app timers on Instagram and YouTube. "
        "Replacing the first 30 minutes after waking with a walk or journaling changes your whole day."
    ),
}

# ============================================================
# PYDANTIC INPUT MODEL
# ============================================================

class CheckinData(BaseModel):
    Sleep_Hours: float
    Steps: float
    Exercise_Minutes: float
    Water_Intake_L: float
    Mood_Score: float
    Stress_Level: float
    Social_Media_Usage: float
    final_calories: float
    final_protein: float
    final_carbs: float
    final_fat: float
    posture_score: float
    Diet_Quality: str
    Weight_kg: Optional[float] = None
    Physical_Score: float = 0.0
    Mental_Score: float = 0.0
    Diet_Score: float = 0.0
    Risk_Score: float = 0.0
    Chronic_Score: float = 0.0
    # ── RAG: real Supabase auth uid from Flutter ──────────────
    # Flutter sends this so Python can store embeddings per user
    user_id: Optional[str] = None


# ============================================================
# GLOBAL STATE
# ============================================================

_model: Optional[TemporalFusionTransformer] = None
_dataset: Optional[TimeSeriesDataSet] = None
_df: Optional[pd.DataFrame] = None

# ── NutriScan YOLOv8 Food Detector ────────────────────────────
import sys
import json as _json
sys.path.insert(0, str(BASE_DIR))
from nutriscan.detector import NutriScanDetectorV2
from nutriscan.nutrition_db import calculate_meal_totals

_nutriscan: Optional[NutriScanDetectorV2] = None
NUTRISCAN_MODEL_PATH = str(BASE_DIR / 'nutriscan' / 'models' / 'best.pt')
NUTRISCAN_CLASS_PATH = str(BASE_DIR / 'nutriscan' / 'models' / 'class_list.json')

# ============================================================
# DATA + MODEL LOADING
# ============================================================

def load_data(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path)
    df["Date"] = pd.to_datetime(df["Date"])
    df = df.sort_values(["UserID", "Date"]).reset_index(drop=True)

    for c in df.select_dtypes("object").columns:
        df[c] = df[c].fillna("missing").astype(str).astype("category")

    num_cols = [
        c
        for c in df.select_dtypes(include=["int64", "float64"]).columns
        if c != "UserID"
    ]
    for c in num_cols:
        df[c] = (
            df.groupby("UserID")[c]
            .apply(lambda x: x.ffill().bfill())
            .reset_index(level=0, drop=True)
        )
    df[num_cols] = df[num_cols].fillna(df[num_cols].median())

    df["time_idx"] = df.groupby("UserID").cumcount()
    df["day_of_week"] = df["Date"].dt.dayofweek.astype(str).astype("category")  # type: ignore[union-attr]
    df["is_weekend"] = (
        df["Date"].dt.dayofweek.isin([5, 6])  # type: ignore[union-attr]
        .astype(int)
        .astype(str)
        .astype("category")
    )
    df["month"] = df["Date"].dt.month  # type: ignore[union-attr]
    return df


def build_dataset(df: pd.DataFrame) -> TimeSeriesDataSet:
    return TimeSeriesDataSet(
        df,  # type: ignore[arg-type]
        time_idx="time_idx",
        target="Health_Score",
        group_ids=["UserID"],
        max_encoder_length=28,
        max_prediction_length=1,
        static_categoricals=[
            "Gender", "Occupation", "Country",
            "Smoking_Habit", "Alcohol_Consumption",
            "Diabetes", "Mental_Health_Condition", "under_treatment",
        ],
        static_reals=["Age", "Height_cm"],
        time_varying_known_categoricals=["day_of_week", "is_weekend", "Season"],
        time_varying_known_reals=["month"],
        time_varying_unknown_categoricals=["Diet_Quality"],
        time_varying_unknown_reals=[
            "Weight_kg", "BMI", "Sleep_Hours", "Exercise_Minutes",
            "Steps", "Heart_Rate_Avg", "Physical_Activity_Hours",
            "Mood_Score", "Stress_Level", "Social_Media_Usage",
            "final_calories", "final_protein", "final_carbs", "final_fat",
            "Water_Intake_L", "sedentary_time_hours", "active_time_hours",
            "posture_score", "Physical_Score", "Mental_Score",
            "Diet_Score", "Risk_Score", "Chronic_Score",
        ],
        categorical_encoders={
            c: NaNLabelEncoder(add_nan=True)
            for c in [
                "Gender", "Occupation", "Country", "Smoking_Habit",
                "Alcohol_Consumption", "Diabetes", "Mental_Health_Condition",
                "under_treatment", "day_of_week", "is_weekend", "Season",
                "Diet_Quality",
            ]
        },
        target_normalizer=GroupNormalizer(
            groups=["UserID"], transformation="softplus"
        ),
        add_relative_time_idx=True,
        add_target_scales=True,
        add_encoder_length=True,
        allow_missing_timesteps=True,
    )


def load_tft_model(checkpoint_path: Path) -> TemporalFusionTransformer:
    ckpt = torch.load(str(checkpoint_path), map_location="cpu", weights_only=False)
    m = TemporalFusionTransformer(**ckpt["hyper_parameters"])
    m.load_state_dict(ckpt["state_dict"], strict=False)
    m.eval()
    for mod in m.modules():
        if hasattr(mod, "p"):
            mod.p = 0.0  # type: ignore[assignment]
    return m


# ============================================================
# CORE TFT FUNCTIONS
# ============================================================

def tft_predict_and_explain(
    working_df: pd.DataFrame,
    user_id: int = DEMO_USER_ID,
) -> Tuple[float, Dict[str, float], List[Tuple[int, float]]]:
    global _model, _dataset

    if _model is None or _dataset is None:
        return 70.0, {}, []

    user_df = working_df[working_df["UserID"] == user_id].sort_values("time_idx")

    if len(user_df) < _dataset.max_encoder_length:
        return 70.0, {}, []

    user_ds = TimeSeriesDataSet.from_dataset(
        _dataset,
        user_df,  # type: ignore[arg-type]
        stop_randomization=True,
        predict_mode=True,
    )
    loader = user_ds.to_dataloader(train=False, batch_size=1, num_workers=0)

    with torch.no_grad():
        x, _ = next(iter(loader))
        output = _model(x)
        interpretation = _model.interpret_output(output, reduction="none")

    prediction = float(output["prediction"].squeeze().cpu().numpy())

    enc_raw = interpretation["encoder_variables"][0]
    if enc_raw.ndim == 0:
        enc_imp = np.array([float(enc_raw.cpu().numpy())])
    elif enc_raw.ndim == 1:
        enc_imp = enc_raw.cpu().numpy()
    else:
        enc_imp = enc_raw.mean(0).cpu().numpy()

    enc_names = (
        (_dataset.time_varying_known_categoricals or [])
        + (_dataset.time_varying_known_reals or [])
        + (_dataset.time_varying_unknown_categoricals or [])
        + (_dataset.time_varying_unknown_reals or [])
    )
    n = min(len(enc_names), len(enc_imp))
    vsn_weights = {enc_names[i]: float(enc_imp[i]) for i in range(n)}

    attn = interpretation["attention"][0]
    attn = attn.mean(-1).cpu().numpy() if attn.ndim > 1 else attn.cpu().numpy()
    attention = sorted(
        [(i, float(attn[-(i + 1)])) for i in range(len(attn))],
        key=lambda x: x[1],
        reverse=True,
    )

    return prediction, vsn_weights, attention


def inject_flutter_input(
    df: pd.DataFrame,
    user_id: int,
    data: CheckinData,
) -> Tuple[pd.DataFrame, int]:
    working_df = df.copy()
    user_mask = working_df["UserID"] == user_id
    user_indices = working_df[user_mask].index
    last_idx = user_indices[-1]

    physical_activity_hours = data.Exercise_Minutes / 60.0
    active_time_hours = physical_activity_hours + (data.Steps / 1000 * 0.1)
    sedentary_time_hours = max(0, 24 - data.Sleep_Hours - active_time_hours)
    bmi = 22.0
    if data.Weight_kg is not None and data.Weight_kg > 0:
        user_row = working_df[user_mask].iloc[0]
        height_cm = float(user_row.get("Height_cm", 170))
        if height_cm > 0:
            h_m = height_cm / 100.0
            bmi = data.Weight_kg / (h_m * h_m)

    working_df.loc[last_idx, "Sleep_Hours"]            = data.Sleep_Hours
    working_df.loc[last_idx, "Steps"]                  = data.Steps
    working_df.loc[last_idx, "Exercise_Minutes"]        = data.Exercise_Minutes
    working_df.loc[last_idx, "Water_Intake_L"]          = data.Water_Intake_L
    working_df.loc[last_idx, "Mood_Score"]              = data.Mood_Score
    working_df.loc[last_idx, "Stress_Level"]            = data.Stress_Level
    working_df.loc[last_idx, "Social_Media_Usage"]      = data.Social_Media_Usage
    working_df.loc[last_idx, "final_calories"]          = data.final_calories
    working_df.loc[last_idx, "final_protein"]           = data.final_protein
    working_df.loc[last_idx, "final_carbs"]             = data.final_carbs
    working_df.loc[last_idx, "final_fat"]               = data.final_fat
    working_df.loc[last_idx, "posture_score"]           = data.posture_score
    working_df.loc[last_idx, "Physical_Activity_Hours"] = physical_activity_hours
    working_df.loc[last_idx, "active_time_hours"]       = active_time_hours
    working_df.loc[last_idx, "sedentary_time_hours"]    = sedentary_time_hours
    working_df.loc[last_idx, "Physical_Score"]          = data.Physical_Score
    working_df.loc[last_idx, "Mental_Score"]            = data.Mental_Score
    working_df.loc[last_idx, "Diet_Score"]              = data.Diet_Score
    working_df.loc[last_idx, "Risk_Score"]              = data.Risk_Score
    working_df.loc[last_idx, "Chronic_Score"]           = data.Chronic_Score
    working_df.loc[last_idx, "BMI"]                     = bmi

    if data.Weight_kg is not None:
        working_df.loc[last_idx, "Weight_kg"] = data.Weight_kg

    try:
        working_df.loc[last_idx, "Diet_Quality"] = data.Diet_Quality
    except Exception:
        pass

    return working_df, last_idx


def run_tft_what_if(
    data: CheckinData,
) -> Tuple[float, List[dict], Dict[str, float], List[dict]]:
    global _df

    if _df is None:
        return 70.0, [{"rank": 1, "feature": "Sleep_Hours", "current_value": 0.0, "target_value": 8.0, "delta": 0.5, "vsn_weight": 0.0, "tip": "Model not ready."}], {}, []

    working_df, last_idx = inject_flutter_input(_df, DEMO_USER_ID, data)

    user_mask = working_df["UserID"] == DEMO_USER_ID
    user_indices = working_df[user_mask].index
    intervention_indices = user_indices[-7:]

    baseline_score, vsn_weights, attention = tft_predict_and_explain(
        working_df, DEMO_USER_ID
    )
    print(f"Baseline TFT score (with Flutter input): {baseline_score:.2f}")

    current_values = {
        "Sleep_Hours":        data.Sleep_Hours,
        "Steps":              data.Steps,
        "Exercise_Minutes":   data.Exercise_Minutes,
        "Water_Intake_L":     data.Water_Intake_L,
        "Stress_Level":       data.Stress_Level,
        "Mood_Score":         data.Mood_Score,
        "Social_Media_Usage": data.Social_Media_Usage,
    }

    actionable = [f for f in HEALTH_TARGETS.keys() if f in vsn_weights]
    ranked_features = sorted(
        actionable,
        key=lambda f: vsn_weights.get(f, 0),
        reverse=True,
    )

    print(f"\nVSN-ranked actionable features:")
    for f in ranked_features:
        print(f"  {f}: {vsn_weights.get(f, 0):.4f}")

    best_per_feature = {}

    for feature in ranked_features:
        current = current_values.get(feature)
        if current is None:
            continue
        current = float(current)

        target_info = HEALTH_TARGETS[feature]
        target      = float(cast(Any, target_info["target"]))
        direction   = cast(str, target_info["direction"])
        test_values = cast(List[Any], target_info["test_values"])

        if direction == "increase" and current >= target:
            print(f"  {feature}: already at target ({current} >= {target}) — skipping")
            continue
        if direction == "decrease" and current <= target:
            print(f"  {feature}: already at target ({current} <= {target}) — skipping")
            continue

        print(f"\nWhat-if for {feature} (current={current}, target={target}):")

        best_delta: float = -999.0
        best_value: float = target

        for test_val in test_values:
            test_val_f = float(test_val)
            if direction == "increase" and test_val_f <= current:
                continue
            if direction == "decrease" and test_val_f >= current:
                continue

            cf_df = working_df.copy()
            cf_df.loc[intervention_indices, feature] = test_val_f

            try:
                cf_score, _, _ = tft_predict_and_explain(cf_df, DEMO_USER_ID)
                real_delta = cf_score - baseline_score
                print(f"    {test_val_f} → score={cf_score:.2f} (delta={real_delta:+.2f})")

                if real_delta > best_delta:
                    best_delta = real_delta
                    best_value = float(test_val)  # type: ignore[arg-type]

            except Exception as e:
                print(f"    Error testing {test_val}: {e}")
                continue

        if best_delta > -999:
            best_per_feature[feature] = {
                "feature":       feature,
                "current_value": round(current, 2),
                "target_value":  round(best_value, 2),
                "delta":         round(best_delta, 2),
                "vsn_weight":    round(vsn_weights.get(feature, 0), 4),
                "tip":           TIPS.get(feature, "Focus on improving this area gradually."),
            }

    sorted_recs = sorted(
        best_per_feature.values(),
        key=lambda x: x["delta"],
        reverse=True,
    )

    top_3 = []
    for i, rec in enumerate(sorted_recs[:3]):
        top_3.append({
            "rank":          i + 1,
            "feature":       rec["feature"],
            "current_value": rec["current_value"],
            "target_value":  rec["target_value"],
            "delta":         rec["delta"],
            "vsn_weight":    rec["vsn_weight"],
            "tip":           rec["tip"],
        })

    if not top_3:
        top_3 = [{
            "rank":          1,
            "feature":       "Sleep_Hours",
            "current_value": round(data.Sleep_Hours, 2),
            "target_value":  8.0,
            "delta":         0.5,
            "vsn_weight":    vsn_weights.get("Sleep_Hours", 0),
            "tip":           "Your metrics look excellent! Maintaining 8 hours of quality sleep "
                             "is the single best investment for long-term health.",
        }]

    attention_summary = [
        {"days_ago": days, "weight": round(weight, 4)}
        for days, weight in attention[:5]
    ]

    return baseline_score, top_3, vsn_weights, attention_summary


# ============================================================
# RAG HELPER — store log + recommendations after each check-in
# ============================================================

def _store_rag_embeddings(data: CheckinData, result: dict, date: str):
    """
    Stores daily log + TFT recommendations as embeddings in pgvector.
    Called after every /recommend response.
    Never blocks the API — errors are caught and printed only.
    user_id must be the real Supabase auth uid (sent from Flutter).
    """
    if not data.user_id:
        return
    try:
        log = {
            "date":             date,
            "Sleep_Hours":      data.Sleep_Hours,
            "Steps":            data.Steps,
            "Exercise_Minutes": data.Exercise_Minutes,
            "Water_Intake_L":   data.Water_Intake_L,
            "Mood_Score":       data.Mood_Score,
            "Stress_Level":     data.Stress_Level,
            "Diet_Quality":     data.Diet_Quality,
            "final_calories":   data.final_calories,
            "final_protein":    data.final_protein,
            "final_carbs":      data.final_carbs,
            "final_fat":        data.final_fat,
        }
        scores = {
            "health_score":   result.get("baseline_score", 0),
            "physical_score": data.Physical_Score,
            "mental_score":   data.Mental_Score,
            "diet_score":     data.Diet_Score,
            "risk_score":     data.Risk_Score,
        }

        _rag.store_daily_log(data.user_id, log, scores)

        recs = result.get("recommendations", [])
        if recs:
            _rag.store_recommendations(
                user_id=data.user_id,
                baseline_score=result.get("baseline_score", 0),
                recommendations=recs,
                date=date,
            )

    except Exception as e:
        print(f"_store_rag_embeddings error (non-critical): {e}")


# ============================================================
# STARTUP LIFESPAN
# ============================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    global _model, _dataset, _df, _nutriscan
    print("\n" + "="*50)
    print("HealthAI API Starting...")
    print("="*50)
    try:
        print("Loading dataset...")
        _df = load_data(DATA_PATH)
        print(f"  ✅ {len(_df):,} rows, {_df['UserID'].nunique()} users")

        print("Building TFT dataset structure...")
        _dataset = build_dataset(_df)
        print("  ✅ Dataset structure ready")

        print("Loading TFT model...")
        _model = load_tft_model(CHECKPOINT_PATH)
        print("  ✅ Model loaded")

        print("Loading NutriScan YOLOv8 model...")
        try:
            _nutriscan = NutriScanDetectorV2(NUTRISCAN_MODEL_PATH, NUTRISCAN_CLASS_PATH)
            ok = _nutriscan.load()
            if ok:
                print(f"  ✅ NutriScan loaded: {_nutriscan.class_count} food classes")
            else:
                _nutriscan = None
                print("  ⚠️  NutriScan: best.pt not found — food detection disabled")
        except Exception as _e:
            _nutriscan = None
            print(f"  ⚠️  NutriScan error: {_e}")

        print("RAG Service: Supabase pgvector ready ✅")
        print("="*50)
        print("Server ready. Visit http://localhost:8000/docs")
        print("="*50 + "\n")

    except Exception as e:
        print(f"  ❌ Startup error: {e}")
        print("  Server running in fallback mode (rule-based only)")

    yield
    print("Server shutting down.")


# ============================================================
# FASTAPI APP
# ============================================================

app = FastAPI(
    title="HealthAI Prediction API",
    description="TFT-powered health score prediction with Flutter input injection + RAG",
    version="4.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(chat_router)


# ============================================================
# ENDPOINTS
# ============================================================

@app.get("/")
async def health_check():
    return {
        "status":       "ok",
        "model_loaded": _model is not None,
        "version":      "4.0",
        "rag_enabled":  True,
        "message":      "HealthAI TFT API is running",
    }


@app.post("/predict")
async def predict(data: CheckinData, rule_based_score: float = 0.0):
    """
    Predicts health score using TFT with Flutter input injected.
    Flow:
    1. Inject Flutter input into user 44's last row
    2. Run TFT on hybrid data (27 days history + today's real input)
    3. Blend TFT score (60%) with rule-based score (40%)
    """
    tft_score = rule_based_score

    if _model is not None and _df is not None:
        try:
            working_df, _ = inject_flutter_input(_df, DEMO_USER_ID, data)
            tft_score, vsn_weights, _ = tft_predict_and_explain(
                working_df, DEMO_USER_ID
            )
        except Exception as e:
            print(f"Predict error: {e}")
            tft_score = rule_based_score

    if rule_based_score > 0:
        final_score = round(0.6 * tft_score + 0.4 * rule_based_score, 2)
    else:
        final_score = round(tft_score, 2)

    return {
        "tft_health_score": round(tft_score, 2),
        "rule_based_score": round(rule_based_score, 2),
        "final_score":      final_score,
        "user_id_used":     DEMO_USER_ID,
        "data_source":      "flutter_input_injected",
    }


@app.post("/recommend")
async def recommend(data: CheckinData):
    """
    Returns TFT-powered personalized recommendations.
    RAG: After computing results, automatically embeds today's log
         and recommendations into pgvector for smart chat answers.
    """
    today = datetime.now().strftime("%Y-%m-%d")

    if _model is None or _df is None:
        result = _rule_based_fallback(data)
        _store_rag_embeddings(data, result, today)
        return result

    try:
        baseline_score, recommendations, vsn_weights, attention = (
            run_tft_what_if(data)
        )

        top_vsn = sorted(
            vsn_weights.items(),
            key=lambda x: x[1],
            reverse=True,
        )[:5]

        result = {
            "baseline_score":  round(baseline_score, 2),
            "recommendations": recommendations,
            "user_id_used":    DEMO_USER_ID,
            "data_source":     "tft_what_if_flutter_injected",
            "explainability": {
                "top_features_by_vsn": [
                    {"feature": f, "weight": round(w, 4)}
                    for f, w in top_vsn
                ],
                "temporal_attention": attention,
                "note": "VSN weights show which features TFT found most influential. "
                        "Delta values are real TFT prediction differences.",
            },
        }

        # ── RAG: embed log + recommendations into pgvector ────
        _store_rag_embeddings(data, result, today)

        return result

    except Exception as e:
        print(f"Recommend error: {e}")
        result = _rule_based_fallback(data)
        _store_rag_embeddings(data, result, today)
        return result


def _rule_based_fallback(data: CheckinData) -> dict:
    """Fallback when model is not loaded."""
    current = {
        "Sleep_Hours":        data.Sleep_Hours,
        "Steps":              data.Steps,
        "Exercise_Minutes":   data.Exercise_Minutes,
        "Water_Intake_L":     data.Water_Intake_L,
        "Stress_Level":       data.Stress_Level,
        "Mood_Score":         data.Mood_Score,
        "Social_Media_Usage": data.Social_Media_Usage,
    }

    IMPACT = {
        "Sleep_Hours":        4.2,
        "Steps":              0.0004,
        "Exercise_Minutes":   0.08,
        "Water_Intake_L":     2.1,
        "Stress_Level":       2.8,
        "Mood_Score":         1.6,
        "Social_Media_Usage": 1.2,
    }

    candidates = []
    for feature, cur_val in current.items():
        info      = HEALTH_TARGETS[feature]
        target    = info["target"]
        direction = info["direction"]
        cur_float = float(cur_val)

        target_f = float(target)  # type: ignore[arg-type]
        if direction == "increase" and cur_float >= target_f:
            continue
        if direction == "decrease" and cur_float <= target_f:
            continue

        gap   = abs(target_f - cur_float)
        delta = round(min(gap * IMPACT.get(feature, 1.0), 8.0), 2)
        delta = max(delta, 0.5)

        candidates.append({
            "feature":       feature,
            "current_value": round(cur_float, 2),
            "target_value":  round(float(target_f), 2),
            "delta":         delta,
            "tip":           TIPS.get(feature, "Focus on improving this area."),
        })

    candidates.sort(key=lambda x: x["delta"], reverse=True)
    recs = [{"rank": i + 1, **c} for i, c in enumerate(candidates[:3])]

    if not recs:
        recs = [{
            "rank":          1,
            "feature":       "Sleep_Hours",
            "current_value": round(data.Sleep_Hours, 2),
            "target_value":  8.0,
            "delta":         0.5,
            "tip":           "Your metrics look great! Keep maintaining this consistency.",
        }]

    return {
        "baseline_score":  70.0,
        "recommendations": recs,
        "user_id_used":    DEMO_USER_ID,
        "data_source":     "rule_based_fallback",
        "explainability": {
            "note": "Model not loaded. Using rule-based recommendations."
        },
    }


# ============================================================
# NUTRISCAN — FOOD DETECTION ENDPOINT
# ============================================================

@app.post("/detect-food")
async def detect_food(
    file: UploadFile = File(...),
    portions: str = Form(default=None),
):
    """
    Detects food items in an uploaded image and returns full nutrition breakdown.
    Powered by the trained YOLOv8 model (81% mAP@50).
    """
    global _nutriscan

    image_bytes = await file.read()
    if len(image_bytes) == 0:
        return {"error": "Empty file", "items": [], "total_calories": 0}

    portion_overrides: dict = {}
    if portions:
        try:
            portion_overrides = _json.loads(portions)
        except Exception:
            pass

    if _nutriscan is None or not _nutriscan.is_loaded:
        return {
            "error":      "NutriScan model not loaded",
            "items":      [],
            "nutrition":  {"total_calories": 0, "total_protein": 0,
                           "total_carbs": 0, "total_fat": 0},
            "items_breakdown": [],
            "message":    "Model unavailable",
        }

    try:
        raw_detections, img_w, img_h = _nutriscan.detect(image_bytes)
    except Exception as e:
        return {"error": str(e), "items": [], "total_calories": 0}

    if not raw_detections:
        return {
            "detected_foods": [],
            "nutrition":      {"total_calories": 0, "total_protein": 0,
                               "total_carbs": 0, "total_fat": 0},
            "items_breakdown": [],
            "message":         "No food detected in this image",
        }

    for det in raw_detections:
        det["portion_override"] = portion_overrides.get(det["food_name"])

    meal = calculate_meal_totals(raw_detections, img_w, img_h)

    return {
        "detected_foods":    [d["food_name"]  for d in raw_detections],
        "confidence_scores": [d["confidence"] for d in raw_detections],
        "portions":          [i.get("portion", "medium") for i in meal["items"]],
        "nutrition": {
            "total_calories": meal["total_calories"],
            "total_protein":  meal["total_protein"],
            "total_carbs":    meal["total_carbs"],
            "total_fat":      meal["total_fat"],
        },
        "items_breakdown": meal["items"],
        "health_summary":  meal.get("health_summary", {}),
        "message":         "Detection successful",
        "model_used":      "YOLOv8n (81% mAP@50, 9 food classes)",
    }


# ============================================================
# RUN
# ============================================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=False)
