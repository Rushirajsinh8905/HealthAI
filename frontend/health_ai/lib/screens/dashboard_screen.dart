// ============================================================
// HEALTHAI — DASHBOARD SCREEN
// ============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import 'daily_checkin_screen.dart';
import 'recommendations_screen.dart';
import 'profile_screen.dart';
import '../services/supabase_service.dart';
import 'medication_screen.dart';
import 'groups_screen.dart';
import 'chat_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userEmail;
  const DashboardScreen({super.key, required this.userEmail});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = SupabaseService();

  String _userName = ''; // loaded from DB
  String _userInitial = '?'; // first letter of full name
  double _healthScore = 0.0;
  final double _prevHealthScore = 0.0;
  bool _isLoadingScore = true;

  // Null = not checked in yet
  double? _sleepHours;
  int? _steps;
  double? _waterLiters;

  bool get _checkedInToday =>
      _sleepHours != null && _steps != null && _waterLiters != null;

  @override
  void initState() {
    super.initState();
    // Tell service which user is active before any fetch
    _db.setActiveUser(widget.userEmail);
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    // Fetch profile (name + userId together)
    final profile = await _db.getDemoProfile();
    if (!mounted) return;

    if (profile != null) {
      final fullName = (profile['full_name'] as String?)?.trim() ?? '';
      final firstName = fullName.isNotEmpty
          ? fullName.split(' ').first
          : widget.userEmail.split('@').first;
      setState(() {
        _userName = firstName;
        _userInitial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';
      });
    }

    // FIXED: daily_logs.user_id = auth.uid() = auth_id, NOT the row 'id'
    final userId = (profile?['auth_id'] as String?)
        ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoadingScore = false);
      return;
    }

    final log = await _db.getLatestDailyLog(userId);
    if (!mounted) return;

    setState(() {
      _isLoadingScore = false;
      if (log != null) {
        _healthScore = (log['health_score'] as num?)?.toDouble() ?? 0.0;
        _sleepHours = (log['sleep_hours'] as num?)?.toDouble();
        _steps = (log['steps'] as num?)?.toInt();
        _waterLiters = (log['water_intake_l'] as num?)?.toDouble();
      }
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  double get _delta => _healthScore - _prevHealthScore;
  // ignore: unused_element
  bool get _scoreUp => _delta >= 0;

  String _scoreLabel(double s) {
    if (s <= 0) return 'Not started';
    if (s >= 80) return 'Excellent';
    if (s >= 65) return 'Good';
    if (s >= 50) return 'Fair';
    return 'Needs Work';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(builder: (_) => const DailyCheckinScreen()),
                );
                if (result != null && mounted) {
                  // Update tiles from local result immediately
                  setState(() {
                    _sleepHours = (result['Sleep_Hours'] as num?)?.toDouble();
                    _steps = (result['Steps'] as num?)?.toInt();
                    _waterLiters = (result['Water_Intake_L'] as num?)
                        ?.toDouble();
                  });
                  // Then reload from Supabase to get latest health_score
                  await _loadDashboardData();
                }
              },
              icon: Icon(
                _checkedInToday
                    ? Icons.check_circle_outline_rounded
                    : Icons.edit_note_rounded,
                size: 20,
              ),
              label: Text(
                _checkedInToday ? 'Update Today\'s Check-in' : 'Daily Check-in',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _checkedInToday
                    ? AppColors.success
                    : AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                textStyle: AppTextStyles.labelLarge.copyWith(fontSize: 15),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // ── Top Bar ──────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_greeting,',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        _userName.isEmpty
                            ? Text(
                                widget.userEmail.split('@').first,
                                style: AppTextStyles.headlineMedium,
                              )
                            : Text(
                                _userName,
                                style: AppTextStyles.headlineMedium,
                              ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          _userInitial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Health Score Card ─────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Health Score',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _scoreLabel(_healthScore),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _isLoadingScore
                            ? const SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : _healthScore > 0
                            ? Text(
                                _healthScore.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 52,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '—',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 52,
                                      fontWeight: FontWeight.w700,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Complete your first check-in ↓',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _healthScore > 0 ? _healthScore / 100 : 0.0,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Today's Stats ─────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.bedtime_outlined,
                      label: 'Sleep',
                      value: _sleepHours != null
                          ? '${_sleepHours!.toStringAsFixed(1)}h'
                          : '--',
                      color: const Color(0xFF7B61FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.directions_walk_outlined,
                      label: 'Steps',
                      value: _steps != null
                          ? '${(_steps! / 1000).toStringAsFixed(1)}k'
                          : '--',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.water_drop_outlined,
                      label: 'Water',
                      value: _waterLiters != null ? '${_waterLiters}L' : '--',
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Nav Cards ─────────────────────────────────
              _NavCard(
                icon: Icons.lightbulb_outline_rounded,
                title: 'Recommendations',
                subtitle: 'Your top AI-ranked actions',
                color: const Color(0xFF7B61FF),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecommendationsScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _NavCard(
                icon: Icons.medication_outlined,
                title: 'Medications',
                subtitle: 'Manage medicines & reminders',
                color: const Color(0xFFFF6B6B),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MedicationScreen()),
                ),
              ),
              const SizedBox(height: 10),
              _NavCard(
                icon: Icons.groups_rounded,
                title: 'Community Groups',
                subtitle: 'Compete on the daily leaderboard',
                color: const Color(0xFF7B61FF),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GroupsScreen()),
                ),
              ),
              const SizedBox(height: 10),
              _NavCard(
                icon: Icons.smart_toy_outlined,
                title: 'Chatbot',
                subtitle: 'Ask anything about health',
                color: const Color(0xFF7B61FF),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatScreen()),
                ),
              ),
              const SizedBox(height: 10),
              _NavCard(
                icon: Icons.person_outline_rounded,
                title: 'My Profile',
                subtitle: 'View and edit your health profile',
                color: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen()),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat Tile ─────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.titleLarge.copyWith(fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

// ── Nav Card ──────────────────────────────────────────────────
class _NavCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.labelLarge.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
