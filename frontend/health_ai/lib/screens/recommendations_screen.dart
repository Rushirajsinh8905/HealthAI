// ============================================================
// HEALTHAI — RECOMMENDATIONS SCREEN
// Real what-if results from FastAPI + fallback when offline
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/supabase_service.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final _db = SupabaseService();
  final _api = ApiService();

  bool _isLoading = true;
  bool _serverOffline = false;
  bool _noCheckIn = false;
  double _baselineScore = 0;
  List<RecommendItem> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _serverOffline = false;
      _noCheckIn = false;
    });

    // Step 1: get user id
    final profile = await _db.getDemoProfile();
    final userId = profile?['id'] as String?;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _noCheckIn = true;
      });
      return;
    }

    // Step 2: get latest log from Supabase
    final log = await _db.getLatestDailyLog(userId);
    if (log == null) {
      setState(() {
        _isLoading = false;
        _noCheckIn = true;
      });
      return;
    }

    // Step 3: check if FastAPI is reachable
    final reachable = await _api.isServerReachable();
    if (!reachable) {
      setState(() {
        _isLoading = false;
        _serverOffline = true;
      });
      return;
    }

    // Step 4: build scores map from log
    final scores = {
      'physical': (log['physical_score'] as num?)?.toDouble() ?? 0.0,
      'mental': (log['mental_score'] as num?)?.toDouble() ?? 0.0,
      'diet': (log['diet_score'] as num?)?.toDouble() ?? 0.0,
      'risk': (log['risk_score'] as num?)?.toDouble() ?? 0.0,
      'chronic': (log['chronic_score'] as num?)?.toDouble() ?? 0.0,
      'health_score': (log['health_score'] as num?)?.toDouble() ?? 0.0,
    };

    // Step 5: call FastAPI /recommend
    final result = await _api.recommend(checkinLog: log, scores: scores);

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isLoading = false;
        _serverOffline = true;
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _baselineScore = result.baselineScore;
      _recommendations = result.recommendations;
    });
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
        title: const Text('Recommendations', style: AppTextStyles.titleLarge),
        centerTitle: false,
        actions: [
          // Refresh button
          IconButton(
            onPressed: _loadRecommendations,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _noCheckIn
          ? _buildNoCheckInView()
          : _serverOffline
          ? _buildOfflineView()
          : _buildRecommendations(),
    );
  }

  // ── No check-in yet ───────────────────────────────────────
  Widget _buildNoCheckInView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                size: 40,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Check-in Found',
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Complete your first daily check-in to get personalized AI recommendations.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Go Do Check-in'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Server offline fallback ───────────────────────────────
  Widget _buildOfflineView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.psychology_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'AI Server Offline',
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start the FastAPI server on your laptop to get AI-powered recommendations.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Run this command on your laptop:',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'uvicorn prediction_api:app\n--host 0.0.0.0 --port 8000',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontFamily: 'monospace',
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadRecommendations,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Real recommendations ───────────────────────────────────
  Widget _buildRecommendations() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── AI Banner ────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.psychology_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI-Ranked for You',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Baseline score: ${_baselineScore.toStringAsFixed(1)} · '
                        'Each change ranked by predicted impact',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Top changes to make',
            style: AppTextStyles.titleLarge.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Ranked by predicted score improvement',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),

          // ── Recommendation Cards ──────────────────────────
          ..._recommendations.map((rec) => _RecommendationCard(rec: rec)),

          const SizedBox(height: 16),

          // ── Footer note ───────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recommendations update after every check-in. '
                    'The AI model uses your full history to improve accuracy over time.',
                    style: AppTextStyles.caption.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Recommendation Card ───────────────────────────────────────
class _RecommendationCard extends StatefulWidget {
  final RecommendItem rec;
  const _RecommendationCard({required this.rec});

  @override
  State<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<_RecommendationCard> {
  bool _expanded = false;

  // Icon per feature
  IconData _icon(String feature) {
    switch (feature) {
      case 'Sleep_Hours':
        return Icons.bedtime_outlined;
      case 'Steps':
        return Icons.directions_walk_outlined;
      case 'Water_Intake_L':
        return Icons.water_drop_outlined;
      case 'Stress_Level':
        return Icons.self_improvement_outlined;
      case 'Exercise_Minutes':
      case 'Physical_Activity_Hours':
        return Icons.fitness_center_outlined;
      case 'Mood_Score':
        return Icons.mood_outlined;
      case 'sedentary_time_hours':
        return Icons.chair_outlined;
      default:
        return Icons.trending_up_rounded;
    }
  }

  // Color per rank
  Color _color(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFF7B61FF);
      case 2:
        return AppColors.primary;
      case 3:
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(widget.rec.rank);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded ? color.withValues(alpha: 0.4) : AppColors.border,
            width: _expanded ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.05),
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
                // Icon box
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _icon(widget.rec.feature),
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.rec.displayName,
                        style: AppTextStyles.labelLarge.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${widget.rec.currentFormatted}  →  ${widget.rec.targetFormatted}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                // Delta badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+${widget.rec.delta.toStringAsFixed(1)} pts',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),

            // Expanded tip
            if (_expanded) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 15,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.rec.tip,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
