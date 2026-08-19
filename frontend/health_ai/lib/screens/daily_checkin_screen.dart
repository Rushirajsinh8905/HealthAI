// ============================================================
// HEALTHAI — DAILY CHECK-IN SCREEN
// Collects all 14 user-input time_varying fields
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import '../services/supabase_service.dart';
import '../utils/health_scorer.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/nutriscan_service.dart';
import '../widgets/nutriscan_sheet.dart';

class DailyCheckinScreen extends StatefulWidget {
  const DailyCheckinScreen({super.key});

  @override
  State<DailyCheckinScreen> createState() => _DailyCheckinScreenState();
}

class _DailyCheckinScreenState extends State<DailyCheckinScreen> {
  final _db = SupabaseService();

  // ── Date
  DateTime _selectedDate = DateTime.now();

  // ── Sleep
  final _sleepController = TextEditingController();

  // ── Activity
  final _stepsController = TextEditingController();
  int? _exerciseMinutes;
  static const _exerciseOptions = [0, 15, 30, 45, 60, 90];

  // ── Hydration
  final _waterController = TextEditingController();

  // ── Mental
  double _moodScore = 5;
  double _stressLevel = 5;
  final _socialMediaController = TextEditingController();

  // ── Nutrition
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  String? _dietQuality;
  static const _dietOptions = [
    'Balanced',
    'Keto',
    'Moderate',
    'Unhealthy',
    'Vegetarian',
  ];

  // ── NutriScan
  // ignore: unused_field
  File? _scannedImage;
  NutriScanResult? _scanResult;
  bool _isScanning = false;

  // ── Posture
  final double _postureScore = 5;

  // ── Body (optional)
  final _weightController = TextEditingController();

  bool _isLoading = false;
  bool _submitted = false;
  Map<String, dynamic>? _lastLog;
  double? _finalHealthScore;

  @override
  void dispose() {
    _sleepController.dispose();
    _stepsController.dispose();
    _waterController.dispose();
    _socialMediaController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ── NutriScan — camera scan + auto-fill ─────────────────────
  Future<void> _handleNutriScan({bool fromCamera = true}) async {
    setState(() => _isScanning = true);

    final image = await NutriScanService().pickImage(fromCamera: fromCamera);
    if (image == null) {
      setState(() => _isScanning = false);
      return;
    }

    final result = await NutriScanService().detectFood(image);
    if (!mounted) return;
    setState(() {
      _scannedImage = image;
      _isScanning = false;
    });

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('NutriScan server offline. Make sure FastAPI is running.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message.isEmpty
            ? 'No food detected. Try a clearer photo.'
            : result.message),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NutriScanSheet(
        imageFile: image,
        initialResult: result,
        onApply: (calories, protein, carbs, fat) {
          _caloriesController.text = calories.toStringAsFixed(0);
          _proteinController.text  = protein.toStringAsFixed(1);
          _carbsController.text    = carbs.toStringAsFixed(1);
          _fatController.text      = fat.toStringAsFixed(1);
          setState(() => _scanResult = result);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              'Auto-filled: ${calories.toStringAsFixed(0)} kcal · '
              '${protein.toStringAsFixed(1)}g protein',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        },
      ),
    );
  }

  bool _validate() {
    if (_sleepController.text.isEmpty) {
      _showError('Please enter sleep hours');
      return false;
    }
    if (_stepsController.text.isEmpty) {
      _showError('Please enter steps count');
      return false;
    }
    if (_exerciseMinutes == null) {
      _showError('Please select exercise duration');
      return false;
    }
    if (_waterController.text.isEmpty) {
      _showError('Please enter water intake');
      return false;
    }
    if (_socialMediaController.text.isEmpty) {
      _showError('Please enter social media usage');
      return false;
    }
    if (_dietQuality == null) {
      _showError('Please select diet quality');
      return false;
    }
    return true;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Map<String, double> _calcDerived() {
    final sleep = double.tryParse(_sleepController.text) ?? 0;
    final steps = double.tryParse(_stepsController.text) ?? 0;
    final exercise = (_exerciseMinutes ?? 0).toDouble();
    final physicalActivityHours = exercise / 60.0;
    final activeTimeHours = physicalActivityHours + (steps / 1000 * 0.1);
    final sedentaryTimeHours = (24 - sleep - activeTimeHours).clamp(0.0, 24.0);
    return {
      'Physical_Activity_Hours': physicalActivityHours,
      'active_time_hours': activeTimeHours,
      'sedentary_time_hours': sedentaryTimeHours,
    };
  }

  Future<void> _handleSubmit() async {
    if (!_validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final derived = _calcDerived();
      final log = {
        'date': _selectedDate.toIso8601String().split('T')[0],
        'Sleep_Hours': double.tryParse(_sleepController.text) ?? 0,
        'Steps': double.tryParse(_stepsController.text) ?? 0,
        'Exercise_Minutes': _exerciseMinutes ?? 0,
        'Water_Intake_L': double.tryParse(_waterController.text) ?? 0,
        'Mood_Score': _moodScore,
        'Stress_Level': _stressLevel,
        'Social_Media_Usage': double.tryParse(_socialMediaController.text) ?? 0,
        'final_calories': double.tryParse(_caloriesController.text) ?? 0,
        'final_protein': double.tryParse(_proteinController.text) ?? 0,
        'final_carbs': double.tryParse(_carbsController.text) ?? 0,
        'final_fat': double.tryParse(_fatController.text) ?? 0,
        'Diet_Quality': _dietQuality,
        'posture_score': _postureScore,
        'Weight_kg': _weightController.text.isEmpty
            ? null
            : double.tryParse(_weightController.text),
        ...derived,
      };

      // ── Load profile for scoring ──────────────────────────
      Map<String, dynamic>? profile;
      try {
        profile = await _db.getDemoProfile();
      } catch (_) {
        profile = null;
      }

      if (profile != null) {
        final String userId = profile['id'].toString();
        final double heightCm =
            (profile['height_cm'] as num?)?.toDouble() ?? 170.0;
        final String smoking = (profile['smoking_habit'] as String?) ?? 'Never';
        final String alcohol =
            (profile['alcohol_consumption'] as String?) ?? 'Never';
        final String diabetes = (profile['diabetes'] as String?) ?? 'No';
        final String treatment =
            (profile['under_treatment'] as String?) ?? 'No';
        final String curDiseases =
            (profile['current_diseases'] as String?) ?? '—';
        final String pastDis = (profile['past_diseases'] as String?) ?? '—';

        // ── Calculate BMI ─────────────────────────────────
        final double? weightKg = (log['Weight_kg'] as num?)?.toDouble();
        final double bmi = (weightKg != null && heightCm > 0)
            ? weightKg / ((heightCm / 100.0) * (heightCm / 100.0))
            : 22.0;

        // ── Calculate domain scores ───────────────────────
        final scores = HealthScorer.calculate(
          bmi: bmi,
          sleepHours: (log['Sleep_Hours'] as num).toDouble(),
          steps: (log['Steps'] as num).toDouble(),
          exerciseMinutes: (log['Exercise_Minutes'] as num).toDouble(),
          heartRateAvg: 75.0,
          sedentaryTimeHours: (log['sedentary_time_hours'] as num).toDouble(),
          postureScore: _postureScore,
          moodScore: (log['Mood_Score'] as num).toDouble(),
          stressLevel: (log['Stress_Level'] as num).toDouble(),
          socialMediaUsage: (log['Social_Media_Usage'] as num).toDouble(),
          finalCalories: (log['final_calories'] as num).toDouble(),
          finalProtein: (log['final_protein'] as num).toDouble(),
          finalCarbs: (log['final_carbs'] as num).toDouble(),
          finalFat: (log['final_fat'] as num).toDouble(),
          waterIntakeL: (log['Water_Intake_L'] as num).toDouble(),
          dietQuality: (log['Diet_Quality'] as String?) ?? 'Moderate',
          smokingHabit: smoking,
          alcoholConsumption: alcohol,
          diabetes: diabetes,
          underTreatment: treatment,
          currentDiseases: curDiseases,
          pastDiseases: pastDis,
        );

        // ── Save to Supabase ──────────────────────────────
        try {
          await _db.saveDailyLog(userId: userId, log: log, scores: scores);
        } catch (e) {
          debugPrint('Supabase save failed: $e');
        }

        // ── Build scores map ──────────────────────────────
        final scoresMap = {
          'physical': scores['physical_score'] ?? 0.0,
          'mental': scores['mental_score'] ?? 0.0,
          'diet': scores['diet_score'] ?? 0.0,
          'risk': scores['risk_score'] ?? 0.0,
          'chronic': scores['chronic_score'] ?? 0.0,
          'health_score': scores['health_score'] ?? 0.0,
        };

        // ── Extract first name for personalised notifications ─
        final fullName = (profile['full_name'] as String?)?.trim() ?? '';
        final firstName = fullName.isNotEmpty
            ? fullName.split(' ').first
            : 'there';

        // ── Call TFT prediction (silent fail) ─────────────
        final tftResult = await ApiService().predict(
          checkinLog: log,
          scores: scoresMap,
        );

        final double finalScore;
        if (tftResult != null) {
          try {
            await _db.updateHealthScore(
              userId: userId,
              healthScore: tftResult.finalScore,
            );
          } catch (_) {}
          finalScore = tftResult.finalScore;
          scoresMap['health_score'] = finalScore;
        } else {
          finalScore = scores['health_score'] ?? 0.0;
        }

        if (mounted) setState(() => _finalHealthScore = finalScore);

        // ── STEP A: Instant score confirmation ────────────
        // Fires immediately — confirms logging, no TFT needed
        NotificationService()
            .sendScoreConfirmation(score: finalScore, userName: firstName)
            .catchError((_) {});

        // ── STEP B: TFT-powered insight (background) ──────
        // Calls /recommend which runs multiple TFT what-ifs (~30–60 s).
        // UI already shows success — notification arrives while user
        // has moved on, feeling like the AI "thought about it".
        _fireTFTInsightInBackground(
          log: log,
          scoresMap: scoresMap,
          userName: firstName,
          score: finalScore,
        );
      }

      // ── Always show success ───────────────────────────────
      if (mounted) {
        setState(() {
          _isLoading = false;
          _submitted = true;
          _lastLog = log;
        });
      }
    } catch (e) {
      debugPrint('_handleSubmit error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Something went wrong. Please try again.');
      }
    }
  }

  // ── TFT insight pipeline (runs fully in background) ──────
  // Calls /recommend → gets real TFT what-if deltas →
  // sends rich notification + schedules evening summary.
  // Never blocks the UI — called with unawaited fire-and-forget.
  void _fireTFTInsightInBackground({
    required Map<String, dynamic> log,
    required Map<String, double> scoresMap,
    required String userName,
    required double score,
  }) {
    Future(() async {
      try {
        final result = await ApiService().recommend(
          checkinLog: log,
          scores: scoresMap,
        );

        if (result != null) {
          // Send TFT-powered insight notification
          await NotificationService().sendTFTInsight(
            result: result,
            userName: userName,
          );

          // Schedule evening summary with TFT top-rec preview
          await NotificationService().scheduleEveningSummary(
            healthScore: score,
            tftResult: result,
          );

          // Update daily reminder with latest score (contextual message)
          await NotificationService().scheduleDailyCheckInReminder(
            lastScore: score,
          );

          debugPrint('TFT notification pipeline complete ✅');
        } else {
          // Server offline — still schedule evening summary
          await NotificationService().scheduleEveningSummary(
            healthScore: score,
          );
          await NotificationService().scheduleDailyCheckInReminder(
            lastScore: score,
          );
        }
      } catch (e) {
        debugPrint('_fireTFTInsightInBackground error: $e');
      }
    });
  }

  String _formatDate(DateTime d) {
    final diff = DateTime.now().difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        title: const Text('Daily Check-in', style: AppTextStyles.titleLarge),
        centerTitle: false,
      ),
      body: _submitted ? _buildSuccessView() : _buildForm(),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 44,
              ),
            ),
            const SizedBox(height: 24),
            Text('Check-in Complete!', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 10),
            if (_finalHealthScore != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monitor_heart_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Health Score: ${_finalHealthScore!.toStringAsFixed(1)}',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              'Your health data has been saved successfully.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'Back to Dashboard',
              onPressed: () => Navigator.pop(context, _lastLog),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _submitted = false),
              child: const Text('Edit this entry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Date selector
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Date',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _formatDate(_selectedDate),
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.primary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // SLEEP
            _SectionCard(
              label: 'Sleep',
              child: _NumberInput(
                controller: _sleepController,
                label: 'Sleep Hours',
                hint: '7.5',
                suffix: 'hrs',
                decimal: true,
                max: 14,
              ),
            ),
            const SizedBox(height: 14),

            // ACTIVITY
            _SectionCard(
              label: 'Activity',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NumberInput(
                    controller: _stepsController,
                    label: 'Steps',
                    hint: '8000',
                    suffix: 'steps',
                    decimal: false,
                    max: 99999,
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel(label: 'Exercise Duration'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _exerciseOptions
                        .map(
                          (min) => _Chip(
                            label: min == 0 ? 'None' : '$min min',
                            isSelected: _exerciseMinutes == min,
                            onTap: () => setState(() => _exerciseMinutes = min),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // HYDRATION
            _SectionCard(
              label: 'Hydration',
              child: _NumberInput(
                controller: _waterController,
                label: 'Water Intake',
                hint: '2.5',
                suffix: 'L',
                decimal: true,
                max: 10,
              ),
            ),
            const SizedBox(height: 14),

            // MENTAL WELLBEING
            _SectionCard(
              label: 'Mental Wellbeing',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SliderField(
                    label: 'Mood Score',
                    value: _moodScore,
                    min: 1,
                    max: 10,
                    lowLabel: 'Very Low',
                    highLabel: 'Very High',
                    onChanged: (v) => setState(() => _moodScore = v),
                  ),
                  const SizedBox(height: 16),
                  _SliderField(
                    label: 'Stress Level',
                    value: _stressLevel,
                    min: 1,
                    max: 10,
                    lowLabel: 'Calm',
                    highLabel: 'Very Stressed',
                    onChanged: (v) => setState(() => _stressLevel = v),
                  ),
                  const SizedBox(height: 16),
                  _NumberInput(
                    controller: _socialMediaController,
                    label: 'Social Media Usage',
                    hint: '2.5',
                    suffix: 'hrs',
                    decimal: true,
                    max: 24,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // NUTRITION
            _SectionCard(
              label: 'Nutrition',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── NutriScan camera button ────────────────
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _isScanning
                              ? null
                              : () => _handleNutriScan(fromCamera: true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _isScanning
                                  ? AppColors.surfaceVariant
                                  : AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isScanning)
                                  const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.camera_enhance_rounded,
                                    size: 18, color: AppColors.primary,
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  _isScanning ? 'Scanning...' : 'Scan Food (AI)',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _isScanning
                            ? null
                            : () => _handleNutriScan(fromCamera: false),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(
                            Icons.photo_library_outlined,
                            size: 18, color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── Auto-fill result badge ─────────────────
                  if (_scanResult != null && _scanResult!.success) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16, color: AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Filled from: ${_scanResult!.detectedFoods.join(", ")}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.success,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _handleNutriScan(),
                            child: const Text(
                              'Re-scan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── Manual entry fields ────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _NumberInput(
                          controller: _caloriesController,
                          label: 'Calories',
                          hint: '2000',
                          suffix: 'kcal',
                          decimal: false,
                          max: 9999,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumberInput(
                          controller: _proteinController,
                          label: 'Protein',
                          hint: '60',
                          suffix: 'g',
                          decimal: true,
                          max: 999,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _NumberInput(
                          controller: _carbsController,
                          label: 'Carbs',
                          hint: '250',
                          suffix: 'g',
                          decimal: true,
                          max: 999,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NumberInput(
                          controller: _fatController,
                          label: 'Fat',
                          hint: '65',
                          suffix: 'g',
                          decimal: true,
                          max: 999,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel(label: 'Diet Quality'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _dietOptions
                        .map(
                          (o) => _Chip(
                            label: o,
                            isSelected: _dietQuality == o,
                            onTap: () => setState(() => _dietQuality = o),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // BODY (optional)
            _SectionCard(
              label: 'Body (optional)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NumberInput(
                    controller: _weightController,
                    label: 'Weight',
                    hint: '70.5',
                    suffix: 'kg',
                    decimal: true,
                    max: 300,
                  ),
                  const SizedBox(height: 8),
                  Text('Leave blank to skip', style: AppTextStyles.caption),
                ],
              ),
            ),

            const SizedBox(height: 28),

            PrimaryButton(
              label: 'Submit Check-in',
              icon: Icons.check_circle_outline_rounded,
              onPressed: _handleSubmit,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Section Card ──────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String label;
  final Widget child;
  const _SectionCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: AppTextStyles.titleLarge.copyWith(fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Field Label ───────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}

// ── Number Input ──────────────────────────────────────────────
class _NumberInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String suffix;
  final bool decimal;
  final double max;

  const _NumberInput({
    required this.controller,
    required this.label,
    required this.hint,
    required this.suffix,
    required this.decimal,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      inputFormatters: [
        if (decimal)
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
        else
          FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(7),
      ],
      style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        suffixStyle: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        counterText: '',
      ),
    );
  }
}

// ── Slider Field ──────────────────────────────────────────────
class _SliderField extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String lowLabel;
  final String highLabel;
  final ValueChanged<double> onChanged;

  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.lowLabel,
    required this.highLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _FieldLabel(label: label),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                value.toStringAsFixed(0),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.divider,
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.1),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(lowLabel, style: AppTextStyles.caption),
            Text(highLabel, style: AppTextStyles.caption),
          ],
        ),
      ],
    );
  }
}

// ── Chip ──────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Camera Hint ───────────────────────────────────────────────
// ignore: unused_element
class _CameraHint extends StatelessWidget {
  final String message;
  const _CameraHint({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
