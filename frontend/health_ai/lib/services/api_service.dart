// ============================================================
// HEALTHAI — API SERVICE (RAG ENABLED)
// Calls FastAPI prediction server + embedding endpoints
//
// Changes from original:
//   1. _buildRequestBody() — added user_id field
//   2. embedProfile()      — new method, call after profile save
//   3. embedMedication()   — new method, call after adding medication
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// ── URL Configuration ─────────────────────────────────────────
// Android Emulator  → http://10.0.2.2:8000
// iOS Simulator     → http://127.0.0.1:8000
// Real Device       → http://YOUR_LAPTOP_WIFI_IP:8000
const String _kBaseUrl = 'http://10.0.2.2:8000';

// ── Response Models ───────────────────────────────────────────

class PredictResult {
  final double tftScore;
  final double ruleScore;
  final double finalScore;

  const PredictResult({
    required this.tftScore,
    required this.ruleScore,
    required this.finalScore,
  });

  factory PredictResult.fromJson(Map<String, dynamic> json) {
    final tft = (json['tft_health_score'] as num?)?.toDouble() ?? 0.0;
    final final_ = (json['final_score'] as num?)?.toDouble() ?? tft;
    final rule = (json['rule_based_score'] as num?)?.toDouble() ?? final_;
    return PredictResult(tftScore: tft, ruleScore: rule, finalScore: final_);
  }
}

class RecommendItem {
  final int rank;
  final String feature;
  final double currentValue;
  final double targetValue;
  final double delta;
  final String tip;

  const RecommendItem({
    required this.rank,
    required this.feature,
    required this.currentValue,
    required this.targetValue,
    required this.delta,
    required this.tip,
  });

  String get displayName {
    const names = {
      'Sleep_Hours': 'Sleep',
      'Steps': 'Daily Steps',
      'Water_Intake_L': 'Water Intake',
      'Stress_Level': 'Stress Level',
      'Exercise_Minutes': 'Exercise',
      'Physical_Activity_Hours': 'Active Time',
      'sedentary_time_hours': 'Sitting Time',
      'Diet_Score': 'Diet Quality',
      'Mood_Score': 'Mood',
    };
    return names[feature] ?? feature;
  }

  String get currentFormatted => _formatValue(feature, currentValue);
  String get targetFormatted => _formatValue(feature, targetValue);

  static String _formatValue(String feature, double value) {
    switch (feature) {
      case 'Sleep_Hours':
        return '${value.toStringAsFixed(1)} hrs';
      case 'Steps':
        return '${value.toInt().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')} steps';
      case 'Water_Intake_L':
        return '${value.toStringAsFixed(1)} L';
      case 'Exercise_Minutes':
        return '${value.toInt()} min';
      case 'Physical_Activity_Hours':
        return '${value.toStringAsFixed(1)} hrs';
      case 'sedentary_time_hours':
        return '${value.toStringAsFixed(1)} hrs';
      case 'Stress_Level':
      case 'Mood_Score':
      case 'Diet_Score':
        return '${value.toStringAsFixed(0)} / 10';
      default:
        return value.toStringAsFixed(1);
    }
  }

  factory RecommendItem.fromJson(Map<String, dynamic> json) {
    return RecommendItem(
      rank: (json['rank'] as num).toInt(),
      feature: json['feature'] as String,
      currentValue: (json['current_value'] as num).toDouble(),
      targetValue: (json['target_value'] as num).toDouble(),
      delta: (json['delta'] as num).toDouble(),
      tip: json['tip'] as String,
    );
  }
}

class RecommendResult {
  final double baselineScore;
  final List<RecommendItem> recommendations;

  const RecommendResult({
    required this.baselineScore,
    required this.recommendations,
  });

  factory RecommendResult.fromJson(Map<String, dynamic> json) {
    final items = (json['recommendations'] as List)
        .map((r) => RecommendItem.fromJson(r as Map<String, dynamic>))
        .toList();
    return RecommendResult(
      baselineScore: (json['baseline_score'] as num).toDouble(),
      recommendations: items,
    );
  }
}

// ============================================================
// API SERVICE
// ============================================================

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _client = http.Client();

  // ── Check if server is reachable ─────────────────────────
  Future<bool> isServerReachable() async {
    try {
      final response = await _client
          .get(Uri.parse('$_kBaseUrl/'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── POST /predict ─────────────────────────────────────────
  Future<PredictResult?> predict({
    required Map<String, dynamic> checkinLog,
    required Map<String, double> scores,
  }) async {
    try {
      final body = _buildRequestBody(checkinLog, scores);

      final response = await _client
          .post(
            Uri.parse('$_kBaseUrl/predict').replace(
              queryParameters: {
                'rule_based_score': scores['health_score']?.toString() ?? '0',
              },
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return PredictResult.fromJson(json);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── POST /recommend ───────────────────────────────────────
  Future<RecommendResult?> recommend({
    required Map<String, dynamic> checkinLog,
    required Map<String, double> scores,
  }) async {
    try {
      final body = _buildRequestBody(checkinLog, scores);

      final response = await _client
          .post(
            Uri.parse('$_kBaseUrl/recommend'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return RecommendResult.fromJson(json);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ── POST /chat/embed/profile ──────────────────────────────
  // Call this after user saves/updates their health profile.
  // Embeds profile into pgvector for RAG-enhanced chat answers.
  Future<void> embedProfile(Map<String, dynamic> profile) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final body = {
        'user_id': userId,
        'age': profile['age'],
        'gender': profile['gender'] ?? '',
        'occupation': profile['occupation'] ?? '',
        'country': profile['country'] ?? '',
        'height_cm': profile['height_cm'],
        'smoking_habit': profile['smoking_habit'] ?? '',
        'alcohol_consumption': profile['alcohol_consumption'] ?? '',
        'diabetes': profile['diabetes'] ?? 'No',
        'under_treatment': profile['under_treatment'] ?? 'No',
        'mental_health_condition': profile['mental_health_condition'] ?? 'None',
        'current_diseases': profile['current_diseases'] ?? '—',
        'past_diseases': profile['past_diseases'] ?? '—',
      };

      await _client
          .post(
            Uri.parse('$_kBaseUrl/chat/embed/profile'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('ApiService: profile embedded for RAG ✅');
    } catch (e) {
      // Non-critical — chat still works without this
      debugPrint('ApiService.embedProfile error (non-critical): $e');
    }
  }

  // ── POST /chat/embed/medication ───────────────────────────
  // Call this after user adds a new medication.
  // Embeds medication into pgvector so Gemini knows the schedule.
  Future<void> embedMedication({
    required String userId,
    required Map<String, dynamic> medication,
  }) async {
    try {
      final body = {
        'user_id': userId,
        'name': medication['name'] ?? '',
        'dosage': medication['dosage'] ?? '',
        'frequency': medication['frequency'] ?? 'Daily',
        'times': medication['times'] ?? [],
        'food_relation': medication['food_relation'] ?? 'After food',
        'duration_days': medication['duration_days'] ?? 7,
        'start_date': medication['start_date'] ?? '',
        'notes': medication['notes'] ?? '',
      };

      await _client
          .post(
            Uri.parse('$_kBaseUrl/chat/embed/medication'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('ApiService: medication embedded for RAG ✅');
    } catch (e) {
      debugPrint('ApiService.embedMedication error (non-critical): $e');
    }
  }

  // ── Build request body ─────────────────────────────────────
  // CHANGE: Added user_id field so Python server can store RAG embeddings
  Map<String, dynamic> _buildRequestBody(
    Map<String, dynamic> log,
    Map<String, double> scores,
  ) {
    // Get real Supabase auth UID — sent to Python for RAG storage
    final userId = Supabase.instance.client.auth.currentUser?.id;

    return {
      'Sleep_Hours': (log['Sleep_Hours'] as num?)?.toDouble() ?? 7.0,
      'Steps': (log['Steps'] as num?)?.toDouble() ?? 5000.0,
      'Exercise_Minutes': (log['Exercise_Minutes'] as num?)?.toDouble() ?? 0.0,
      'Water_Intake_L': (log['Water_Intake_L'] as num?)?.toDouble() ?? 2.0,
      'Mood_Score': (log['Mood_Score'] as num?)?.toDouble() ?? 5.0,
      'Stress_Level': (log['Stress_Level'] as num?)?.toDouble() ?? 5.0,
      'Social_Media_Usage':
          (log['Social_Media_Usage'] as num?)?.toDouble() ?? 2.0,
      'final_calories': (log['final_calories'] as num?)?.toDouble() ?? 2000.0,
      'final_protein': (log['final_protein'] as num?)?.toDouble() ?? 60.0,
      'final_carbs': (log['final_carbs'] as num?)?.toDouble() ?? 250.0,
      'final_fat': (log['final_fat'] as num?)?.toDouble() ?? 65.0,
      'posture_score': (log['posture_score'] as num?)?.toDouble() ?? 5.0,
      'Diet_Quality': log['Diet_Quality'] as String? ?? 'Moderate',
      'Weight_kg': (log['Weight_kg'] as num?)?.toDouble(),
      'Physical_Score': scores['physical'] ?? 0.0,
      'Mental_Score': scores['mental'] ?? 0.0,
      'Diet_Score': scores['diet'] ?? 0.0,
      'Risk_Score': scores['risk'] ?? 0.0,
      'Chronic_Score': scores['chronic'] ?? 0.0,
      // ── RAG: real user id ─────────────────────────────────
      'user_id': userId,
    };
  }
}
