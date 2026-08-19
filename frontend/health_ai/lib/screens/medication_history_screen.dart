// ============================================================
// HEALTHAI — MEDICATION HISTORY SCREEN (Simple)
// Just shows the list of all medications with details
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

class MedicationHistoryScreen extends StatefulWidget {
  final String userId;
  const MedicationHistoryScreen({super.key, required this.userId});

  @override
  State<MedicationHistoryScreen> createState() =>
      _MedicationHistoryScreenState();
}

class _MedicationHistoryScreenState extends State<MedicationHistoryScreen> {
  final _db = SupabaseService();
  List<Map<String, dynamic>> _medications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final meds = await _db.getMedications(widget.userId);
    if (mounted) {
      setState(() {
        _medications = meds;
        _isLoading = false;
      });
    }
  }

  String _fmt(String t) {
    final p = t.split(':');
    final h = int.parse(p[0]);
    final m = int.parse(p[1]);
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:${m.toString().padLeft(2, '0')} $period';
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
        title: const Text(
          'Medication History',
          style: AppTextStyles.titleLarge,
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _medications.isEmpty
          ? _buildEmpty()
          : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medication_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No medications added yet',
              style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Add medicines from the Medications screen.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.medication_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  '${_medications.length} active medication${_medications.length > 1 ? 's' : ''}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'All Medicines',
            style: AppTextStyles.titleLarge.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 12),

          // Medication list
          ..._medications.map(
            (med) => _MedHistoryCard(medication: med, formatTime: _fmt),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Medication History Card ───────────────────────────────────
class _MedHistoryCard extends StatelessWidget {
  final Map<String, dynamic> medication;
  final String Function(String) formatTime;

  const _MedHistoryCard({required this.medication, required this.formatTime});

  Color _color(String name) {
    final colors = [
      const Color(0xFFFF6B6B),
      AppColors.primary,
      AppColors.accent,
      const Color(0xFF7B61FF),
      const Color(0xFF2DC653),
      const Color(0xFFFFB703),
    ];
    return colors[name.length % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final name = medication['name'] as String;
    final dosage = medication['dosage'] as String;
    final times = List<String>.from(medication['times'] as List);
    final frequency = medication['frequency'] as String? ?? 'Daily';
    final foodRelation = medication['food_relation'] as String? ?? 'After food';
    final startDate = medication['start_date'] as String? ?? '—';
    final duration = medication['duration_days'] as int? ?? 0;
    final notes = medication['notes'] as String? ?? '';
    final reminderOn = medication['reminder_enabled'] as bool? ?? true;
    final color = _color(name);

    // Calculate end date
    String endDate = '—';
    try {
      final start = DateTime.parse(startDate);
      final end = start.add(Duration(days: duration));
      endDate = '${end.day}/${end.month}/${end.year}';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.medication_rounded, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.labelLarge.copyWith(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dosage,
                        style: AppTextStyles.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Active badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '● Active',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Details ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reminder times
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: times
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: color.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.alarm_rounded, size: 12, color: color),
                              const SizedBox(width: 4),
                              Text(
                                formatTime(t),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),

                const SizedBox(height: 12),
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 12),

                // Info rows
                _InfoRow(
                  icon: Icons.repeat_rounded,
                  label: 'Frequency',
                  value: frequency,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.restaurant_outlined,
                  label: 'Food',
                  value: foodRelation,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Start',
                  value: startDate,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.event_outlined,
                  label: 'End',
                  value: endDate,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.timelapse_rounded,
                  label: 'Duration',
                  value: '$duration days',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.notifications_outlined,
                  label: 'Reminder',
                  value: reminderOn ? 'On' : 'Off',
                  valueColor: reminderOn
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),

                // Notes
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.notes_rounded,
                    label: 'Notes',
                    value: notes,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Row ──────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.caption.copyWith(
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
