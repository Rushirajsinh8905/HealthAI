import os
import warnings
warnings.filterwarnings("ignore")

os.environ["CUDA_VISIBLE_DEVICES"] = ""
os.environ["PYTORCH_MPS_ENABLED"] = "0"

import torch
import numpy as np
import pandas as pd
from dataclasses import dataclass
from typing import List, Tuple, Optional

from pytorch_forecasting import (
    TemporalFusionTransformer,
    TimeSeriesDataSet,
    GroupNormalizer
)
from pytorch_forecasting.data.encoders import NaNLabelEncoder

DATA_PATH = "/Users/rushirajsinhdabhi/Desktop/rushi/8th_Sem_Internship/Code/TFT_MODEL/Dataset/health_lifestyle_dataset.csv"
CHECKPOINT_PATH = "/Users/rushirajsinhdabhi/Desktop/rushi/8th_Sem_Internship/Code/TFT_MODEL/Model/FINAL_TFT_HEALTH_MODEL.ckpt"

USER_ID_TO_ANALYZE = 44

@dataclass
class TFTExplanation:
    user_id: int
    prediction: float
    top_encoder_features: List[Tuple[str, float]]
    top_static_features: List[Tuple[str, float]]
    top_attention_timesteps: List[Tuple[int, float]]

def load_tft_model(checkpoint_path: str) -> TemporalFusionTransformer:
    checkpoint = torch.load(
        checkpoint_path,
        map_location="cpu",
        weights_only=False   
    )

    model = TemporalFusionTransformer(**checkpoint["hyper_parameters"])
    model.load_state_dict(checkpoint["state_dict"], strict=False)
    model.eval()

    for m in model.modules():
        if hasattr(m, "p"):
            m.p = 0.0

    print("✓ Model loaded successfully (CPU via map_location)")
    return model

def load_data(path: str) -> pd.DataFrame:
    df = pd.read_csv(path)

    df["Date"] = pd.to_datetime(df["Date"])
    df = df.sort_values(["UserID", "Date"]).reset_index(drop=True)

    
    for c in df.select_dtypes("object").columns:
        df[c] = df[c].fillna("missing").astype(str).astype("category")

    
    num_cols = df.select_dtypes(include=["int64", "float64"]).columns
    num_cols = [c for c in num_cols if c != "UserID"]

    for c in num_cols:
        df[c] = (
            df.groupby("UserID")[c]
            .apply(lambda x: x.ffill().bfill())
            .reset_index(level=0, drop=True)
        )

    df[num_cols] = df[num_cols].fillna(df[num_cols].median())

    df["time_idx"] = df.groupby("UserID").cumcount()
    df["day_of_week"] = df["Date"].dt.dayofweek.astype(str).astype("category")
    df["is_weekend"] = (
        df["Date"].dt.dayofweek.isin([5, 6])
        .astype(int).astype(str).astype("category")
    )
    df["month"] = df["Date"].dt.month

    print(f"✓ Data loaded: {len(df):,} rows, {df['UserID'].nunique()} users")
    return df

def build_dataset(df: pd.DataFrame) -> TimeSeriesDataSet:
    return TimeSeriesDataSet(
        df,
        time_idx="time_idx",
        target="Health_Score",
        group_ids=["UserID"],
        max_encoder_length=28,
        max_prediction_length=1,
        static_categoricals=[
            "Gender", "Occupation", "Country",
            "Smoking_Habit", "Alcohol_Consumption",
            "Diabetes", "Mental_Health_Condition",
            "under_treatment"
        ],
        static_reals=["Age", "Height_cm"],
        time_varying_known_categoricals=["day_of_week", "is_weekend", "Season"],
        time_varying_known_reals=["month"],
        time_varying_unknown_categoricals=["Diet_Quality"],
        time_varying_unknown_reals=[
            "Weight_kg", "BMI", "Sleep_Hours",
            "Exercise_Minutes", "Steps",
            "Heart_Rate_Avg", "Physical_Activity_Hours",
            "Mood_Score", "Stress_Level",
            "Social_Media_Usage", "final_calories",
            "final_protein", "final_carbs", "final_fat",
            "Water_Intake_L", "sedentary_time_hours",
            "active_time_hours", "posture_score",
            "Physical_Score", "Mental_Score",
            "Diet_Score", "Risk_Score", "Chronic_Score"
        ],
        categorical_encoders={
            c: NaNLabelEncoder(add_nan=True)
            for c in [
                "Gender", "Occupation", "Country",
                "Smoking_Habit", "Alcohol_Consumption",
                "Diabetes", "Mental_Health_Condition",
                "under_treatment", "day_of_week",
                "is_weekend", "Season", "Diet_Quality"
            ]
        },
        target_normalizer=GroupNormalizer(
            groups=["UserID"], transformation="softplus"
        ),
        add_relative_time_idx=True,
        add_target_scales=True,
        add_encoder_length=True,
        allow_missing_timesteps=True
    )

def explain_user(
    model: TemporalFusionTransformer,
    dataset: TimeSeriesDataSet,
    df: pd.DataFrame,
    user_id: int
) -> Optional[TFTExplanation]:

    user_df = df[df["UserID"] == user_id].sort_values("time_idx")
    if len(user_df) < dataset.max_encoder_length:
        print("Not enough history for user")
        return None

    user_ds = TimeSeriesDataSet.from_dataset(
        dataset,
        user_df,
        stop_randomization=True,
        predict_mode=True
    )

    loader = user_ds.to_dataloader(
        train=False, batch_size=1, num_workers=0
    )

    with torch.no_grad():
        x, _ = next(iter(loader))
        raw_output = model(x)

    #Prediction
    prediction = float(raw_output["prediction"].squeeze().cpu().numpy())

    #Interpretability
    interpretation = model.interpret_output(
        raw_output, reduction="none"
    )

    # Encoder variables
    enc_raw = interpretation["encoder_variables"][0]

    if enc_raw.ndim == 0:
        enc_imp = np.array([float(enc_raw.cpu().numpy())])
    elif enc_raw.ndim == 1:
        enc_imp = enc_raw.cpu().numpy()
    else:
        enc_imp = enc_raw.mean(0).cpu().numpy()

    enc_names = (
        dataset.time_varying_known_categoricals +
        dataset.time_varying_known_reals +
        dataset.time_varying_unknown_categoricals +
        dataset.time_varying_unknown_reals
    )

    n = min(len(enc_names), len(enc_imp))
    top_encoder = sorted(
        zip(enc_names[:n], enc_imp[:n]),
        key=lambda x: x[1],
        reverse=True
    )[:10]

    #Static variables
    stat_raw = interpretation["static_variables"][0]
    stat_imp = stat_raw.cpu().numpy()

    stat_names = dataset.static_categoricals + dataset.static_reals
    n = min(len(stat_names), len(stat_imp))

    top_static = sorted(
        zip(stat_names[:n], stat_imp[:n]),
        key=lambda x: x[1],
        reverse=True
    )[:10]

    #Temporal attention
    attn = interpretation["attention"][0]
    attn = attn.mean(-1).cpu().numpy() if attn.ndim > 1 else attn.cpu().numpy()

    top_time = sorted(
        [(i, attn[-(i + 1)]) for i in range(len(attn))],
        key=lambda x: x[1],
        reverse=True
    )[:10]

    return TFTExplanation(
        user_id=user_id,
        prediction=round(prediction, 2),
        top_encoder_features=[(k, round(float(v), 3)) for k, v in top_encoder],
        top_static_features=[(k, round(float(v), 3)) for k, v in top_static],
        top_attention_timesteps=[(k, round(float(v), 3)) for k, v in top_time],
    )

def main():
    print("TFT")
    df = load_data(DATA_PATH)
    dataset = build_dataset(df)
    model = load_tft_model(CHECKPOINT_PATH)

    explanation = explain_user(
        model=model,
        dataset=dataset,
        df=df,
        user_id=USER_ID_TO_ANALYZE
    )

    print("\nRESULT")
    print(explanation)

if __name__ == "__main__":
    main()
