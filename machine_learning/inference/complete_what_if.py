import os
import warnings
import json
from typing import List, Dict, Tuple, Optional

warnings.filterwarnings("ignore")
os.environ["CUDA_VISIBLE_DEVICES"] = ""
os.environ["PYTORCH_MPS_ENABLED"] = "0"

import torch
import numpy as np
import pandas as pd

from pytorch_forecasting import (
    TemporalFusionTransformer,
    TimeSeriesDataSet,
    GroupNormalizer
)
from pytorch_forecasting.data.encoders import NaNLabelEncoder


from pathlib import Path

USER_ID = 100
TOP_K_FEATURES = 7
INTERVENTION_DAYS = 7

BASE_DIR = Path(__file__).resolve().parents[2]

DATA_PATH = BASE_DIR / "data" / "health_lifestyle_dataset.csv"
CHECKPOINT_PATH = BASE_DIR / "machine_learning" / "models" / "FINAL_TFT_HEALTH_MODEL.ckpt"
RESULTS_DIR = BASE_DIR / "machine_learning" / "results"
OUTPUT_JSON_PATH = RESULTS_DIR / f"what_if_user_{USER_ID}.json"




def load_tft_model(checkpoint_path: str) -> TemporalFusionTransformer:
    checkpoint = torch.load(checkpoint_path, map_location="cpu", weights_only=False)
    model = TemporalFusionTransformer(**checkpoint["hyper_parameters"])
    model.load_state_dict(checkpoint["state_dict"], strict=False)
    model.eval()
    
    for m in model.modules():
        if hasattr(m, "p"):
            m.p = 0.0
    
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


def get_prediction_and_explanation(
    model: TemporalFusionTransformer,
    dataset: TimeSeriesDataSet,
    df: pd.DataFrame,
    user_id: int
) -> Tuple[float, Dict[str, float], List[Tuple[int, float]]]:
    
    user_df = df[df["UserID"] == user_id].sort_values("time_idx")
    
    if len(user_df) < dataset.max_encoder_length:
        raise ValueError(f"User {user_id} has insufficient data")
    
    user_ds = TimeSeriesDataSet.from_dataset(
        dataset, user_df, stop_randomization=True, predict_mode=True
    )
    
    loader = user_ds.to_dataloader(train=False, batch_size=1, num_workers=0)
    
    with torch.no_grad():
        x, _ = next(iter(loader))
        output = model(x)
        interpretation = model.interpret_output(output, reduction="none")
    
    prediction = float(output["prediction"].squeeze().cpu().numpy())
    
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
    vsn_weights = {enc_names[i]: float(enc_imp[i]) for i in range(n)}
    
    attn = interpretation["attention"][0]
    attn = attn.mean(-1).cpu().numpy() if attn.ndim > 1 else attn.cpu().numpy()
    
    attention = [(i, float(attn[-(i + 1)])) for i in range(len(attn))]
    attention = sorted(attention, key=lambda x: x[1], reverse=True)
    
    return prediction, vsn_weights, attention


def apply_intervention(
    df: pd.DataFrame,
    user_id: int,
    feature_name: str,
    target_value: float,
    last_n_days: int,
    dataset: TimeSeriesDataSet
) -> pd.DataFrame:
    
    cf_df = df.copy()
    user_mask = cf_df["UserID"] == user_id
    user_data = cf_df[user_mask].copy()
    
    if len(user_data) < dataset.max_encoder_length:
        raise ValueError(f"User {user_id}: Insufficient history")
    
    intervention_indices = user_data.iloc[-last_n_days:].index
    cf_df.loc[intervention_indices, feature_name] = target_value
    
    return cf_df


def generate_realistic_values(feature_name: str, current_value: float) -> List[float]:
    
    if feature_name == "Steps":
        return [3000, 5000, 7000, 8000, 10000, 12000, 15000]
    
    elif feature_name == "Exercise_Minutes":
        return [0, 15, 30, 45, 60, 75, 90]
    
    elif feature_name == "Sleep_Hours":
        return [4.0, 5.5, 6.5, 7.0, 7.5, 8.0, 9.0, 10.0]
    
    elif feature_name == "Water_Intake_L":
        return [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]
    
    elif feature_name == "Stress_Level":
        return [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    
    elif feature_name == "Physical_Activity_Hours":
        return [0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0]
    
    elif feature_name == "sedentary_time_hours":
        return [2, 4, 6, 8, 10, 12, 14]
    
    elif feature_name == "Diet_Score":
        return [3, 4, 5, 6, 7, 8, 9, 10]
    
    elif feature_name == "Mood_Score":
        return [3, 4, 5, 6, 7, 8, 9, 10]
    
    else:
        if current_value <= 0:
            current_value = 1.0
        
        return [
            round(current_value * 0.5, 2),
            round(current_value * 0.7, 2),
            round(current_value * 0.85, 2),
            round(current_value, 2),
            round(current_value * 1.15, 2),
            round(current_value * 1.3, 2),
            round(current_value * 1.5, 2)
        ]


def run_what_if_analysis(
    model: TemporalFusionTransformer,
    dataset: TimeSeriesDataSet,
    df: pd.DataFrame,
    user_id: int,
    top_k_features: int,
    intervention_days: int
) -> Dict:
    
    print(f"Analyzing User {user_id}...")
    
    baseline_pred, baseline_vsn, baseline_attn = get_prediction_and_explanation(
        model, dataset, df, user_id
    )
    
    print(f"Baseline Health Score: {baseline_pred:.2f}")
    
    actionable_features = [
        "Steps", "Exercise_Minutes", "Sleep_Hours",
        "Water_Intake_L", "Stress_Level", "Diet_Score",
        "Physical_Activity_Hours", "sedentary_time_hours",
        "Mood_Score", "Physical_Score", "Mental_Score"
    ]
    
    top_features = [
        (feat, weight) for feat, weight in 
        sorted(baseline_vsn.items(), key=lambda x: x[1], reverse=True)
        if feat in actionable_features
    ][:top_k_features]
    
    print(f"\nTop {top_k_features} actionable features:")
    for feat, weight in top_features:
        print(f"  • {feat}: {weight:.4f}")
    
    user_df = df[df["UserID"] == user_id].sort_values("time_idx")
    current_values = {}
    for feat, _ in top_features:
        current_values[feat] = round(float(user_df[feat].iloc[-intervention_days:].mean()), 2)
    
    what_if_results = {}
    best_per_feature = {}
    
    for feature_name, baseline_weight in top_features:
        print(f"\nTesting {feature_name} (current: {current_values[feature_name]})...")
        
        test_values = generate_realistic_values(feature_name, current_values[feature_name])
        feature_results = []
        
        for test_value in test_values:
            cf_df = apply_intervention(
                df, user_id, feature_name, test_value, intervention_days, dataset
            )
            
            cf_pred, cf_vsn, _ = get_prediction_and_explanation(
                model, dataset, cf_df, user_id
            )
            
            delta = cf_pred - baseline_pred
            vsn_weight_change = cf_vsn.get(feature_name, 0) - baseline_weight
            
            result = {
                "value": round(float(test_value), 2),
                "prediction": round(cf_pred, 2),
                "delta": round(delta, 2),
                "vsn_weight": round(cf_vsn.get(feature_name, 0), 4),
                "vsn_weight_change": round(vsn_weight_change, 4)
            }
            
            feature_results.append(result)
            
            print(f"  {test_value:>6.1f} → {cf_pred:.2f} ({delta:+.2f})")
        
        what_if_results[feature_name] = feature_results
        
        best_scenario_for_feature = max(feature_results, key=lambda x: x["delta"])
        best_per_feature[feature_name] = {
            "feature": feature_name,
            "value": best_scenario_for_feature["value"],
            "prediction": best_scenario_for_feature["prediction"],
            "delta": best_scenario_for_feature["delta"],
            "vsn_weight_change": best_scenario_for_feature["vsn_weight_change"]
        }
    
    overall_best = max(best_per_feature.values(), key=lambda x: x["delta"])
    
    top_3_features = sorted(
        best_per_feature.values(), 
        key=lambda x: x["delta"], 
        reverse=True
    )[:3]
    
    baseline_top_features = [
        {"feature": feat, "weight": round(weight, 4)}
        for feat, weight in sorted(baseline_vsn.items(), key=lambda x: x[1], reverse=True)[:10]
    ]
    
    temporal_attention = [
        {"days_ago": days, "weight": round(weight, 4)}
        for days, weight in baseline_attn[:10]
    ]
    
    output = {
        "user_id": user_id,
        "baseline": {
            "prediction": round(baseline_pred, 2),
            "current_values": current_values
        },
        "what_if_analysis": what_if_results,
        "best_scenario": {
            "feature": overall_best["feature"],
            "value": overall_best["value"],
            "current_value": current_values[overall_best["feature"]],
            "change_percent": round(
                ((overall_best["value"] - current_values[overall_best["feature"]]) / 
                 current_values[overall_best["feature"]]) * 100, 1
            ) if current_values[overall_best["feature"]] != 0 else 0,
            "prediction": overall_best["prediction"],
            "delta": overall_best["delta"],
            "vsn_weight_shift": overall_best["vsn_weight_change"]
        },
        "top_3_features": [
            {
                "rank": i + 1,
                "feature": s["feature"],
                "value": s["value"],
                "current_value": current_values[s["feature"]],
                "prediction": s["prediction"],
                "delta": s["delta"]
            }
            for i, s in enumerate(top_3_features)
        ],
        "baseline_vsn_weights": baseline_top_features,
        "temporal_attention": temporal_attention,
        "temporal_attention_summary": {
            "top_days": [baseline_attn[i][0] for i in range(min(5, len(baseline_attn)))],
            "mean_weight": round(np.mean([w for _, w in baseline_attn[:10]]), 4),
            "focus_pattern": "recent_past" if baseline_attn[0][0] < 10 else "distant_past"
        }
    }
    
    return output


def main():
    print("TFT PER-USER WHAT-IF ANALYSIS")
    
    print("\nLoading data and model")
    df = load_data(DATA_PATH)
    dataset = build_dataset(df)
    model = load_tft_model(CHECKPOINT_PATH)
    print(f"✓ Loaded {len(df):,} rows, {df['UserID'].nunique()} users")
    
    results = run_what_if_analysis(
        model=model,
        dataset=dataset,
        df=df,
        user_id=USER_ID,
        top_k_features=TOP_K_FEATURES,
        intervention_days=INTERVENTION_DAYS
    )
    
    OUTPUT_JSON_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_JSON_PATH, "w") as f:
        json.dump(results, f, indent=2)
    
    print("RESULTS")
    print(f"\nBaseline: {results['baseline']['prediction']}")
    print(f"Best scenario: {results['best_scenario']['feature']} = {results['best_scenario']['value']}")
    print(f"Prediction: {results['best_scenario']['prediction']} ( {results['best_scenario']['delta']:+.2f})")
    print(f"\nResults saved to: {OUTPUT_JSON_PATH}")

    print("\nWHAT-IF SUMMARY")
    for feature, scenarios in results["what_if_analysis"].items():
        print(f"\n{feature}:")
        for s in scenarios:
            print(f"  {s['value']:>6} → {s['prediction']:>6.2f} ( {s['delta']:>+6.2f})")
    
    print("\nTOP 3 FEATURES (best value per feature)")
    for feat in results["top_3_features"]:
        print(f"{feat['rank']}. {feat['feature']} = {feat['value']}")
        print(f"   Current: {feat['current_value']} → Predicted: {feat['prediction']} ( {feat['delta']:+.2f})")


if __name__ == "__main__":
    main()