// ============================================================
// HEALTHAI — NUTRISCAN SERVICE
// File: lib/services/nutriscan_service.dart
// ============================================================

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

// ── Same base URL as your existing ApiService ─────────────────
// Android Emulator  → 10.0.2.2
// Real device       → your laptop WiFi IP e.g. 192.168.1.5
const String _kNutriScanUrl = 'http://10.0.2.2:8000/detect-food';

// ============================================================
// RESULT MODELS
// ============================================================

class DetectedFood {
  final String foodName;
  final String displayName;
  final double confidence;
  final String portion;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final bool found;

  const DetectedFood({
    required this.foodName,
    required this.displayName,
    required this.confidence,
    required this.portion,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.found,
  });

  factory DetectedFood.fromJson(Map<String, dynamic> json) {
    return DetectedFood(
      foodName: json['food_name'] as String? ?? '',
      displayName:
          json['display_name'] as String? ??
          (json['food_name'] as String? ?? ''),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      portion: json['portion'] as String? ?? 'medium',
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      found: json['found_in_db'] as bool? ?? true,
    );
  }

  // Returns a copy with updated portion (for S/M/L selector)
  DetectedFood withPortion(String newPortion) => DetectedFood(
    foodName: foodName,
    displayName: displayName,
    confidence: confidence,
    portion: newPortion,
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
    found: found,
  );
}

// ── ─────────────────────────────────────────────────────────

class NutriScanResult {
  final List<String> detectedFoods;
  final double totalCalories;
  final double totalProtein;
  final double totalCarbs;
  final double totalFat;
  final List<DetectedFood> itemsBreakdown;
  final String message;
  final bool success;

  const NutriScanResult({
    required this.detectedFoods,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.itemsBreakdown,
    required this.message,
    required this.success,
  });

  factory NutriScanResult.fromJson(Map<String, dynamic> json) {
    // Support both response formats (v1 and v2 backend)
    final nutrition = json['nutrition'] as Map<String, dynamic>?;
    final double cal = nutrition != null
        ? (nutrition['total_calories'] as num?)?.toDouble() ?? 0.0
        : (json['total_calories'] as num?)?.toDouble() ?? 0.0;
    final double prot = nutrition != null
        ? (nutrition['total_protein'] as num?)?.toDouble() ?? 0.0
        : (json['total_protein'] as num?)?.toDouble() ?? 0.0;
    final double carbs = nutrition != null
        ? (nutrition['total_carbs'] as num?)?.toDouble() ?? 0.0
        : (json['total_carbs'] as num?)?.toDouble() ?? 0.0;
    final double fat = nutrition != null
        ? (nutrition['total_fat'] as num?)?.toDouble() ?? 0.0
        : (json['total_fat'] as num?)?.toDouble() ?? 0.0;

    // Items come from items_breakdown or items key
    final rawItems = (json['items_breakdown'] ?? json['items']) as List? ?? [];

    final foods = List<String>.from(json['detected_foods'] ?? []);

    return NutriScanResult(
      detectedFoods: foods,
      totalCalories: cal,
      totalProtein: prot,
      totalCarbs: carbs,
      totalFat: fat,
      itemsBreakdown: rawItems
          .map((i) => DetectedFood.fromJson(i as Map<String, dynamic>))
          .toList(),
      message: json['message'] as String? ?? '',
      success: foods.isNotEmpty,
    );
  }

  factory NutriScanResult.empty() => const NutriScanResult(
    detectedFoods: [],
    totalCalories: 0,
    totalProtein: 0,
    totalCarbs: 0,
    totalFat: 0,
    itemsBreakdown: [],
    message: '',
    success: false,
  );
}

// ============================================================
// NUTRISCAN SERVICE
// ============================================================

class NutriScanService {
  static final NutriScanService _instance = NutriScanService._internal();
  factory NutriScanService() => _instance;
  NutriScanService._internal();

  final _picker = ImagePicker();

  // ── Pick image from camera or gallery ──────────────────────
  Future<File?> pickImage({bool fromCamera = true}) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (picked == null) return null;
      return File(picked.path);
    } catch (e) {
      debugPrint('NutriScan pickImage error: $e');
      return null;
    }
  }

  // ── Send image to /detect-food ──────────────────────────────
  Future<NutriScanResult?> detectFood(
    File imageFile, {
    Map<String, String>? portionOverrides,
  }) async {
    try {
      final uri = Uri.parse(_kNutriScanUrl);
      final request = http.MultipartRequest('POST', uri);

      // Attach image file
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // Attach portion overrides if user changed S/M/L
      if (portionOverrides != null && portionOverrides.isNotEmpty) {
        request.fields['portions'] = jsonEncode(portionOverrides);
      }

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        // Check for error key from backend
        if (json.containsKey('error')) {
          debugPrint('NutriScan backend error: ${json['error']}');
          return NutriScanResult.empty();
        }
        return NutriScanResult.fromJson(json);
      } else {
        debugPrint('NutriScan HTTP ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('NutriScan detectFood error: $e');
      return null;
    }
  }

  // ── Re-scan with updated S/M/L portions ────────────────────
  Future<NutriScanResult?> rescanWithPortions(
    File imageFile,
    List<DetectedFood> foods,
  ) async {
    final overrides = {for (final f in foods) f.foodName: f.portion};
    return detectFood(imageFile, portionOverrides: overrides);
  }
}
