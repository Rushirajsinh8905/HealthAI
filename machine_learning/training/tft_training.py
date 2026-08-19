
import warnings
warnings.filterwarnings("ignore")

import pandas as pd
import numpy as np
import torch
import pytorch_lightning as pl

from pytorch_lightning import Trainer
from pytorch_lightning.callbacks import EarlyStopping, LearningRateMonitor

from pytorch_forecasting import TimeSeriesDataSet, TemporalFusionTransformer
from pytorch_forecasting.data import GroupNormalizer
from pytorch_forecasting.data.encoders import NaNLabelEncoder
from pytorch_forecasting.metrics import MAE

from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score


pl.seed_everything(42)
DEVICE = "mps" if torch.backends.mps.is_available() else "cpu"
print(f"Using device: {DEVICE}")

DATA_PATH = "/Users/rushirajsinhdabhi/Desktop/rushi/8th Sem Internship/Code/TFT_MODEL/Dataset/health_lifestyle_dataset.csv"

print("\nLoading dataset...")
df = pd.read_csv(DATA_PATH)

df["Date"] = pd.to_datetime(df["Date"])
df = df.sort_values(["UserID", "Date"]).reset_index(drop=True)

print(f"Records: {len(df):,}")
print(f"   Users: {df.UserID.nunique()}")


# categoricals
for c in df.select_dtypes("object").columns:
    df[c] = df[c].fillna("missing").astype(str).astype("category")

# numerics
num_cols = df.select_dtypes(include=["int64", "float64"]).columns
num_cols = [c for c in num_cols if c not in ["UserID"]]

for c in num_cols:
    df[c] = (
        df.groupby("UserID")[c]
        .apply(lambda x: x.ffill().bfill())
        .reset_index(level=0, drop=True)
    )

df[num_cols] = df[num_cols].fillna(df[num_cols].median())


df["time_idx"] = df.groupby("UserID").cumcount()
df["day_of_week"] = df["Date"].dt.dayofweek.astype(str).astype("category")
df["is_weekend"] = df["Date"].dt.dayofweek.isin([5, 6]).astype(int).astype(str).astype("category")
df["month"] = df["Date"].dt.month
df["Season"] = df["Season"].astype(str).astype("category")


ENCODER_LEN = 28
PRED_LEN = 1

train_parts, val_parts, test_parts = [], [], []

for _, g in df.groupby("UserID"):
    n = len(g)
    t_end = int(n * 0.6)
    v_end = int(n * 0.8)

    train_parts.append(g.iloc[:t_end])

    #INCLUDE HISTORY
    val_parts.append(g.iloc[t_end - ENCODER_LEN : v_end])
    test_parts.append(g.iloc[v_end - ENCODER_LEN :])

train_df = pd.concat(train_parts).reset_index(drop=True)
val_df   = pd.concat(val_parts).reset_index(drop=True)
test_df  = pd.concat(test_parts).reset_index(drop=True)

print("\nData split (with context):")
print(f"   Train: {len(train_df):,}")
print(f"   Val:   {len(val_df):,}")
print(f"   Test:  {len(test_df):,}")


static_categoricals = [
    "Gender", "Occupation", "Country",
    "Smoking_Habit", "Alcohol_Consumption",
    "Diabetes", "Mental_Health_Condition",
    "under_treatment"
]

static_reals = ["Age", "Height_cm"]

time_varying_known_categoricals = ["day_of_week", "is_weekend", "Season"]
time_varying_known_reals = ["month"]

time_varying_unknown_categoricals = ["Diet_Quality"]

time_varying_unknown_reals = [
    "Weight_kg", "BMI", "Sleep_Hours", "Exercise_Minutes",
    "Steps", "Heart_Rate_Avg", "Physical_Activity_Hours",
    "Mood_Score", "Stress_Level", "Social_Media_Usage",
    "final_calories", "final_protein", "final_carbs", "final_fat",
    "Water_Intake_L", "sedentary_time_hours", "active_time_hours",
    "posture_score",
    "Physical_Score", "Mental_Score",
    "Diet_Score", "Risk_Score", "Chronic_Score"
]

TARGET = "Health_Score"

categorical_encoders = {
    c: NaNLabelEncoder(add_nan=True)
    for c in static_categoricals
    + time_varying_known_categoricals
    + time_varying_unknown_categoricals
}


training = TimeSeriesDataSet(
    train_df,
    time_idx="time_idx",
    target=TARGET,
    group_ids=["UserID"],
    max_encoder_length=ENCODER_LEN,
    max_prediction_length=PRED_LEN,
    static_categoricals=static_categoricals,
    static_reals=static_reals,
    time_varying_known_categoricals=time_varying_known_categoricals,
    time_varying_known_reals=time_varying_known_reals,
    time_varying_unknown_categoricals=time_varying_unknown_categoricals,
    time_varying_unknown_reals=time_varying_unknown_reals,
    categorical_encoders=categorical_encoders,
    target_normalizer=GroupNormalizer(groups=["UserID"], transformation="softplus"),
    add_relative_time_idx=True,
    add_target_scales=True,
    add_encoder_length=True,
)

validation = TimeSeriesDataSet.from_dataset(
    training, val_df, stop_randomization=True
)


train_loader = training.to_dataloader(train=True, batch_size=128, num_workers=0)
val_loader = validation.to_dataloader(train=False, batch_size=256, num_workers=0)


tft = TemporalFusionTransformer.from_dataset(
    training,
    hidden_size=256,
    lstm_layers=2,
    attention_head_size=4,
    dropout=0.1,
    hidden_continuous_size=16,
    learning_rate=1e-3,
    loss=MAE(),
)


trainer = Trainer(
    max_epochs=50,
    accelerator=DEVICE,
    devices=1,
    gradient_clip_val=0.1,
    callbacks=[
        EarlyStopping(monitor="val_loss", patience=10),
        LearningRateMonitor()
    ],
)

print("\n Training started...\n")
trainer.fit(tft, train_loader, val_loader)


trainer.save_checkpoint("tft_health_model.ckpt")
print("\n Training completed successfully")
