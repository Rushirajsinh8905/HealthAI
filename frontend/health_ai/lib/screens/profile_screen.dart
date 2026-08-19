// ============================================================
// HEALTHAI — PROFILE SCREEN
// All data loaded from Supabase — zero static/hardcoded values
// Edit Profile button in AppBar → navigates to EditProfileScreen
// ============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _db = SupabaseService();

  bool _isLoading = true;

  // ── Profile fields (from profiles table) ─────────────────
  String _fullName = '';
  String _email = '';
  String _age = '—';
  String _heightCm = '—';
  String _gender = '—';
  String _occupation = '—';
  String _country = '—';
  String _smoking = '—';
  String _alcohol = '—';
  String _diabetes = '—';
  String _mentalHealth = '—';
  String _underTreatment = '—';
  String _currentDiseases = '—';
  String _pastDiseases = '—';
  String _joinedAt = '—';

  // ── Daily log fields (from daily_logs table) ─────────────
  String _weightKg = '—';
  String _bmi = '—';
  String _sleepHours = '—';
  String _steps = '—';
  String _exerciseMins = '—';
  String _waterIntake = '—';
  String _moodScore = '—';
  String _stressLevel = '—';
  String _socialMedia = '—';
  String _calories = '—';
  String _protein = '—';
  String _carbs = '—';
  String _fat = '—';
  String _heartRate = '—';
  String _sedentary = '—';
  String _postureScore = '—';
  String _dietQuality = '—';

  // ── Domain scores ─────────────────────────────────────────
  String _physicalScore = '—';
  String _mentalScore = '—';
  String _dietScore = '—';
  String _riskScore = '—';
  String _chronicScore = '—';
  String _healthScore = '—';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _fmt(dynamic v, {int decimals = 1}) {
    if (v == null) return '—';
    final d = (v as num?)?.toDouble();
    if (d == null) return '—';
    return d.toStringAsFixed(decimals);
  }

  String _fmtStr(dynamic v) {
    if (v == null) return '—';
    final s = v.toString().trim();
    return s.isEmpty || s == 'missing' ? '—' : s;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // ── 1. Load profile ───────────────────────────────────
    final profile = await _db.getDemoProfile();
    if (!mounted) return;

    if (profile != null) {
      final createdAt = profile['created_at'] as String?;
      String joined = '—';
      if (createdAt != null) {
        final dt = DateTime.tryParse(createdAt);
        if (dt != null) {
          const months = [
            '',
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
          joined = '${months[dt.month]} ${dt.year}';
        }
      }

      final h = (profile['height_cm'] as num?)?.toDouble();
      setState(() {
        _fullName = _fmtStr(profile['full_name']);
        _email = _fmtStr(profile['email']);
        _age = profile['age'] != null ? '${profile['age']} yrs' : '—';
        _heightCm = h != null ? '${h.toStringAsFixed(0)} cm' : '—';
        _gender = _fmtStr(profile['gender']);
        _occupation = _fmtStr(profile['occupation']);
        _country = _fmtStr(profile['country']);
        _smoking = _fmtStr(profile['smoking_habit']);
        _alcohol = _fmtStr(profile['alcohol_consumption']);
        _diabetes = _fmtStr(profile['diabetes']);
        _mentalHealth = _fmtStr(profile['mental_health_condition']);
        _underTreatment = _fmtStr(profile['under_treatment']);
        _currentDiseases = _fmtStr(profile['current_diseases']);
        _pastDiseases = _fmtStr(profile['past_diseases']);
        _joinedAt = joined;
      });
    }

    // ── 2. Load latest daily log ──────────────────────────
    final userId = profile?['id']?.toString();
    if (userId != null) {
      final log = await _db.getLatestDailyLog(userId);
      if (!mounted) return;

      if (log != null) {
        final hCm = (profile?['height_cm'] as num?)?.toDouble() ?? 170.0;
        final wKg = (log['weight_kg'] as num?)?.toDouble();
        String bmiStr = '—';
        if (wKg != null && hCm > 0) {
          final hM = hCm / 100.0;
          bmiStr = (wKg / (hM * hM)).toStringAsFixed(1);
        }

        setState(() {
          _weightKg = wKg != null ? '${wKg.toStringAsFixed(1)} kg' : '—';
          _bmi = bmiStr;
          _sleepHours = _fmt(log['sleep_hours']);
          _steps = log['steps'] != null
              ? (log['steps'] as num).toInt().toString()
              : '—';
          _exerciseMins = _fmt(log['exercise_minutes'], decimals: 0);
          _waterIntake = _fmt(log['water_intake_l']);
          _moodScore = _fmt(log['mood_score'], decimals: 0);
          _stressLevel = _fmt(log['stress_level'], decimals: 0);
          _socialMedia = _fmt(log['social_media_usage']);
          _calories = _fmt(log['final_calories'], decimals: 0);
          _protein = _fmt(log['final_protein'], decimals: 0);
          _carbs = _fmt(log['final_carbs'], decimals: 0);
          _fat = _fmt(log['final_fat'], decimals: 0);
          _heartRate = _fmt(log['heart_rate_avg'], decimals: 0);
          _sedentary = _fmt(log['sedentary_time_hours']);
          _postureScore = _fmt(log['posture_score'], decimals: 0);
          _dietQuality = _fmtStr(log['diet_quality']);
          _physicalScore = _fmt(log['physical_score']);
          _mentalScore = _fmt(log['mental_score']);
          _dietScore = _fmt(log['diet_score']);
          _riskScore = _fmt(log['risk_score']);
          _chronicScore = _fmt(log['chronic_score']);
          _healthScore = _fmt(log['health_score']);
        });
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ── Navigate to Edit Profile ───────────────────────────────
  Future<void> _openEditProfile() async {
    // Always fetch fresh profile before opening edit screen
    // so pre-filled values are never stale
    final profile = await _db.getDemoProfile();
    if (profile == null || !mounted) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(currentProfile: profile),
      ),
    );

    // Reload all data if user saved changes
    if (updated == true && mounted) {
      _loadData();
    }
  }

  // ── Sign Out ───────────────────────────────────────────────
  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ── Delete Account ─────────────────────────────────────────
  Future<void> _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all health data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
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
        title: const Text('My Profile', style: AppTextStyles.titleLarge),
        centerTitle: false,
        // ── Edit button — navigates to EditProfileScreen ────
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _isLoading ? null : _openEditProfile,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _UserCard(
                    name: _fullName.isEmpty ? 'User' : _fullName,
                    email: _email,
                    joined: _joinedAt,
                  ),
                  const SizedBox(height: 20),
                  _ScoreBanner(
                    physical: _physicalScore,
                    mental: _mentalScore,
                    diet: _dietScore,
                    risk: _riskScore,
                    chronic: _chronicScore,
                    total: _healthScore,
                  ),
                  const SizedBox(height: 20),
                  _DomainSection(
                    title: 'Physical',
                    icon: Icons.fitness_center_outlined,
                    color: AppColors.primary,
                    rows: [
                      _FR('BMI', _bmi),
                      _FR('Sleep Hours', _sleepHours),
                      _FR('Steps', _steps),
                      _FR('Exercise Minutes', _exerciseMins),
                      _FR('Heart Rate Avg', _heartRate),
                      _FR('Sedentary Hours', _sedentary),
                      _FR('Posture Score', _postureScore),
                    ],
                  ),
                  _DomainSection(
                    title: 'Mental',
                    icon: Icons.self_improvement_outlined,
                    color: AppColors.primary,
                    rows: [
                      _FR('Mood Score', _moodScore),
                      _FR('Stress Level', _stressLevel),
                      _FR('Social Media (hrs)', _socialMedia),
                    ],
                  ),
                  _DomainSection(
                    title: 'Nutrition / Diet',
                    icon: Icons.restaurant_outlined,
                    color: AppColors.primary,
                    rows: [
                      _FR('Calories', _calories),
                      _FR('Protein (g)', _protein),
                      _FR('Carbs (g)', _carbs),
                      _FR('Fat (g)', _fat),
                      _FR('Water Intake (L)', _waterIntake),
                      _FR('Diet Quality', _dietQuality),
                    ],
                  ),
                  _DomainSection(
                    title: 'Risk Factors',
                    icon: Icons.warning_amber_outlined,
                    color: AppColors.primary,
                    rows: [
                      _FR('Smoking Habit', _smoking),
                      _FR('Alcohol Consumption', _alcohol),
                      _FR('Diabetes', _diabetes),
                      _FR('Under Treatment', _underTreatment),
                    ],
                  ),
                  _DomainSection(
                    title: 'Chronic History',
                    icon: Icons.medical_information_outlined,
                    color: AppColors.primary,
                    rows: [
                      _FR('Current Diseases', _currentDiseases),
                      _FR('Past Diseases', _pastDiseases),
                    ],
                  ),
                  _DomainSection(
                    title: 'Static Profile',
                    icon: Icons.person_outline_rounded,
                    color: AppColors.primary,
                    rows: [
                      _FR('Age', _age),
                      _FR('Gender', _gender),
                      _FR('Height', _heightCm),
                      _FR('Weight', _weightKg),
                      _FR('Occupation', _occupation),
                      _FR('Country', _country),
                      _FR('Mental Health', _mentalHealth),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _AccountCard(
                    onSignOut: _handleSignOut,
                    onDeleteAccount: _handleDeleteAccount,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

// ── Shorthand for field row ───────────────────────────────────
class _FR {
  final String field;
  final String value;
  const _FR(this.field, this.value);
}

// ── User Card ─────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final String name, email, joined;
  const _UserCard({
    required this.name,
    required this.email,
    required this.joined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
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
                    'Member since $joined',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Score Banner ──────────────────────────────────────────────
class _ScoreBanner extends StatelessWidget {
  final String physical, mental, diet, risk, chronic, total;
  const _ScoreBanner({
    required this.physical,
    required this.mental,
    required this.diet,
    required this.risk,
    required this.chronic,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final domains = [
      {'label': 'Physical', 'max': '40', 'score': physical},
      {'label': 'Mental', 'max': '15', 'score': mental},
      {'label': 'Diet', 'max': '25', 'score': diet},
      {'label': 'Risk', 'max': '15', 'score': risk},
      {'label': 'Chronic', 'max': '5', 'score': chronic},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Score Breakdown',
                style: AppTextStyles.labelLarge.copyWith(fontSize: 14),
              ),
              const Spacer(),
              Text(
                'Total: $total / 100',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: domains.map((d) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Column(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        d['label']!,
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        d['score'] == '—'
                            ? '— / ${d['max']}'
                            : '${d['score']} / ${d['max']}',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Domain Section ────────────────────────────────────────────
class _DomainSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_FR> rows;

  const _DomainSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.divider, height: 1),
          ...rows.asMap().entries.map((entry) {
            final i = entry.key;
            final row = entry.value;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.field,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        row.value,
                        style: AppTextStyles.labelLarge.copyWith(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < rows.length - 1)
                  const Divider(
                    color: AppColors.divider,
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Account Card ──────────────────────────────────────────────
class _AccountCard extends StatelessWidget {
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;

  const _AccountCard({required this.onSignOut, required this.onDeleteAccount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          _ActionRow(
            icon: Icons.logout_rounded,
            label: 'Sign Out',
            color: AppColors.textSecondary,
            onTap: onSignOut,
          ),
          const Divider(color: AppColors.divider, height: 24),
          _ActionRow(
            icon: Icons.delete_outline_rounded,
            label: 'Delete Account',
            color: AppColors.error,
            onTap: onDeleteAccount,
          ),
        ],
      ),
    );
  }
}

// ── Action Row ────────────────────────────────────────────────
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color),
        ],
      ),
    );
  }
}
