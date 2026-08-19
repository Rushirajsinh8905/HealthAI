// ============================================================
// HEALTHAI — HEALTH SCORER
// Physical(40) + Mental(15) + Diet(25) + Risk(15) + Chronic(5)
// Place in: lib/utils/health_scorer.dart
// ============================================================

class HealthScorer {
  static Map<String, double> calculate({
    required double bmi,
    required double sleepHours,
    required double steps,
    required double exerciseMinutes,
    required double heartRateAvg,
    required double sedentaryTimeHours,
    required double postureScore,
    required double moodScore,
    required double stressLevel,
    required double socialMediaUsage,
    required double finalCalories,
    required double finalProtein,
    required double finalCarbs,
    required double finalFat,
    required double waterIntakeL,
    required String dietQuality,
    required String smokingHabit,
    required String alcoholConsumption,
    required String diabetes,
    required String underTreatment,
    required String currentDiseases,
    required String pastDiseases,
  }) {
    final double physical = _physicalScore(
      bmi: bmi,
      sleepHours: sleepHours,
      steps: steps,
      exerciseMinutes: exerciseMinutes,
      heartRateAvg: heartRateAvg,
      sedentaryTimeHours: sedentaryTimeHours,
      postureScore: postureScore,
    );
    final double mental = _mentalScore(
      moodScore: moodScore,
      stressLevel: stressLevel,
      socialMediaUsage: socialMediaUsage,
    );
    final double diet = _dietScore(
      finalCalories: finalCalories,
      finalProtein: finalProtein,
      finalCarbs: finalCarbs,
      finalFat: finalFat,
      waterIntakeL: waterIntakeL,
      dietQuality: dietQuality,
    );
    final double risk = _riskScore(
      smokingHabit: smokingHabit,
      alcoholConsumption: alcoholConsumption,
      diabetes: diabetes,
      underTreatment: underTreatment,
    );
    final double chronic = _chronicScore(
      currentDiseases: currentDiseases,
      pastDiseases: pastDiseases,
      underTreatment: underTreatment,
    );
    final double total = (physical + mental + diet + risk + chronic).clamp(
      0.0,
      100.0,
    );

    return {
      'physical_score': _r(physical),
      'mental_score': _r(mental),
      'diet_score': _r(diet),
      'risk_score': _r(risk),
      'chronic_score': _r(chronic),
      'health_score': _r(total),
    };
  }

  // ── PHYSICAL (max 40) ──────────────────────────────────────
  static double _physicalScore({
    required double bmi,
    required double sleepHours,
    required double steps,
    required double exerciseMinutes,
    required double heartRateAvg,
    required double sedentaryTimeHours,
    required double postureScore,
  }) {
    double score = 0;

    // BMI (max 10)
    if (bmi >= 18.5 && bmi <= 24.9) {
      score += 10;
    } else if (bmi >= 25.0 && bmi <= 29.9) {
      score += 6;
    } else if (bmi >= 17.0 && bmi < 18.5) {
      score += 5;
    } else {
      score += 3;
    }

    // Sleep (max 10)
    if (sleepHours >= 7 && sleepHours <= 9) {
      score += 10;
    } else if (sleepHours >= 9 && sleepHours <= 10) {
      score += 8;
    } else if (sleepHours >= 6 && sleepHours < 7) {
      score += 7;
    } else if (sleepHours >= 5 && sleepHours < 6) {
      score += 4;
    } else {
      score += 2;
    }

    // Steps (max 7)
    if (steps >= 10000) {
      score += 7;
    } else if (steps >= 8000) {
      score += 6;
    } else if (steps >= 6000) {
      score += 4;
    } else if (steps >= 4000) {
      score += 2;
    }
    // else += 0

    // Exercise (max 8)
    if (exerciseMinutes >= 60) {
      score += 8;
    } else if (exerciseMinutes >= 45) {
      score += 6;
    } else if (exerciseMinutes >= 30) {
      score += 5;
    } else if (exerciseMinutes >= 15) {
      score += 3;
    }
    // else += 0

    // Heart Rate (max 5)
    if (heartRateAvg >= 60 && heartRateAvg <= 80) {
      score += 5;
    } else if (heartRateAvg > 80 && heartRateAvg <= 90) {
      score += 3;
    } else if (heartRateAvg >= 50 && heartRateAvg < 60) {
      score += 3;
    } else {
      score += 1;
    }

    // Sedentary penalty (max -2)
    if (sedentaryTimeHours > 10) {
      score -= 2;
    } else if (sedentaryTimeHours > 8) {
      score -= 1;
    }

    // Posture bonus (max +2): scale 1–10 → 0–2
    score += (postureScore / 10.0) * 2.0;

    return score.clamp(0.0, 40.0);
  }

  // ── MENTAL (max 15) ────────────────────────────────────────
  static double _mentalScore({
    required double moodScore,
    required double stressLevel,
    required double socialMediaUsage,
  }) {
    double score = 0;

    // Mood (max 6) — higher is better
    score += (moodScore / 10.0) * 6.0;

    // Stress (max 6) — lower is better, so invert
    score += ((10.0 - stressLevel) / 10.0) * 6.0;

    // Social media (max 3) — lower is better
    if (socialMediaUsage <= 1) {
      score += 3;
    } else if (socialMediaUsage <= 2) {
      score += 2;
    } else if (socialMediaUsage <= 3) {
      score += 1;
    }
    // else += 0

    return score.clamp(0.0, 15.0);
  }

  // ── DIET (max 25) ──────────────────────────────────────────
  static double _dietScore({
    required double finalCalories,
    required double finalProtein,
    required double finalCarbs,
    required double finalFat,
    required double waterIntakeL,
    required String dietQuality,
  }) {
    double score = 0;

    // Calories (max 10)
    if (finalCalories >= 1600 && finalCalories <= 2400) {
      score += 10;
    } else if (finalCalories >= 1400 && finalCalories < 1600) {
      score += 7;
    } else if (finalCalories > 2400 && finalCalories <= 2800) {
      score += 6;
    } else if (finalCalories >= 1200 && finalCalories < 1400) {
      score += 4;
    } else {
      score += 2;
    }

    // Macros — protein + carbs + fat combined (max 8)
    double macro = 0;
    if (finalProtein >= 50 && finalProtein <= 150) {
      macro += 3;
    } else if (finalProtein >= 30) {
      macro += 1.5;
    }
    if (finalCarbs >= 200 && finalCarbs <= 300) {
      macro += 3;
    } else if (finalCarbs >= 150) {
      macro += 1.5;
    }
    if (finalFat >= 44 && finalFat <= 77) {
      macro += 2;
    } else if (finalFat >= 30) {
      macro += 1;
    }
    score += macro.clamp(0.0, 8.0);

    // Water (max 4)
    if (waterIntakeL >= 2.5) {
      score += 4;
    } else if (waterIntakeL >= 2.0) {
      score += 3;
    } else if (waterIntakeL >= 1.5) {
      score += 2;
    } else if (waterIntakeL >= 1.0) {
      score += 1;
    }
    // else += 0

    // Diet Quality (max 6) — matches dataset values exactly
    switch (dietQuality) {
      case 'Balanced':
        score += 6;
        break;
      case 'Vegetarian':
        score += 5;
        break;
      case 'Keto':
        score += 4;
        break;
      case 'Moderate':
        score += 3;
        break;
      case 'Unhealthy':
        score += 0;
        break;
      default:
        score += 2;
        break;
    }

    return score.clamp(0.0, 25.0);
  }

  // ── RISK (max 15) ──────────────────────────────────────────
  static double _riskScore({
    required String smokingHabit,
    required String alcoholConsumption,
    required String diabetes,
    required String underTreatment,
  }) {
    double score = 0;

    // Smoking (max 5)
    switch (smokingHabit) {
      case 'Never':
        score += 5;
        break;
      case 'Former':
        score += 3;
        break;
      case 'Occasional':
        score += 1;
        break;
      case 'Regular':
        score += 0;
        break;
      default:
        score += 2;
        break;
    }

    // Alcohol (max 5)
    switch (alcoholConsumption) {
      case 'Never':
        score += 5;
        break;
      case 'Rarely':
        score += 4;
        break;
      case 'Moderate':
        score += 2;
        break;
      case 'Heavy':
        score += 0;
        break;
      default:
        score += 2;
        break;
    }

    // Diabetes (max 5)
    if (diabetes == 'No') {
      score += 5;
    } else {
      score += 2;
    }

    // Under treatment bonus (+1.5)
    if (underTreatment == 'Yes') {
      score += 1.5;
    }

    return score.clamp(0.0, 15.0);
  }

  // ── CHRONIC (max 5) ────────────────────────────────────────
  static double _chronicScore({
    required String currentDiseases,
    required String pastDiseases,
    required String underTreatment,
  }) {
    double score = 5.0; // start full, deduct for diseases

    final bool hasCurrent =
        currentDiseases != '—' &&
        currentDiseases.isNotEmpty &&
        currentDiseases.toLowerCase() != 'none' &&
        currentDiseases.toLowerCase() != 'missing';

    final bool hasPast =
        pastDiseases != '—' &&
        pastDiseases.isNotEmpty &&
        pastDiseases.toLowerCase() != 'none' &&
        pastDiseases.toLowerCase() != 'missing';

    if (hasCurrent) {
      score -= 3;
    }
    if (hasPast) {
      score -= 2;
    }
    if (underTreatment == 'Yes') {
      score += 1;
    }

    return score.clamp(0.0, 5.0);
  }

  static double _r(double v) => double.parse(v.toStringAsFixed(2));
}
