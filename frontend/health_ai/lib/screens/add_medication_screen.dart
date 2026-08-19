// ============================================================
// HEALTHAI — ADD MEDICATION SCREEN
// Style matches all other screens (same background, same cards)
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../widgets/auth_widgets.dart';

class AddMedicationScreen extends StatefulWidget {
  final String userId;
  const AddMedicationScreen({super.key, required this.userId});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _db = SupabaseService();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<String> _selectedTimes = [];
  String _frequency = 'Daily';
  String _foodRelation = 'After food';
  int _durationDays = 7;
  bool _reminderEnabled = true;
  bool _isLoading = false;

  static const _frequencies = ['Daily', 'Twice a day', 'Weekly', 'As needed'];
  static const _foodRelations = [
    'Before food',
    'After food',
    'With food',
    'Empty stomach',
  ];
  static const _durations = [3, 5, 7, 14, 30, 60, 90];

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final timeStr =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if (_selectedTimes.contains(timeStr)) {
      _showError('Time already added');
      return;
    }
    setState(() {
      _selectedTimes.add(timeStr);
      _selectedTimes.sort();
    });
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

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTimes.isEmpty) {
      _showError('Add at least one reminder time');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final result = await _db.addMedication(
        userId: widget.userId,
        name: _nameController.text.trim(),
        dosage: _dosageController.text.trim(),
        frequency: _frequency,
        times: _selectedTimes,
        foodRelation: _foodRelation,
        startDate: today,
        durationDays: _durationDays,
        reminderEnabled: _reminderEnabled,
        notes: _notesController.text.trim(),
      );

      if (result == null) {
        _showError('Failed to save. Check your connection.');
        setState(() => _isLoading = false);
        return;
      }

      // Schedule medication reminders
      // Uses _nextMedTimeIST internally — always fires at exact time daily
      if (_reminderEnabled) {
        await NotificationService().scheduleMedicationReminders(
          medicationId: result['id'].toString(),
          medicineName: _nameController.text.trim(),
          dosage: _dosageController.text.trim(),
          times: _selectedTimes,
          foodRelation: _foodRelation,
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_nameController.text} saved! '
              'Reminders set for ${_selectedTimes.map(_fmt).join(', ')}',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('addMedication error: $e');
      setState(() => _isLoading = false);
      _showError('Something went wrong. Please try again.');
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
        title: const Text('Add Medication', style: AppTextStyles.titleLarge),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // ── Medicine Details ─────────────────────────
                _SectionCard(
                  label: 'Medicine Details',
                  icon: Icons.medication_rounded,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Name is required'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Medicine Name',
                          hintText: 'e.g. Paracetamol',
                          prefixIcon: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: Icon(Icons.medication_rounded, size: 20),
                          ),
                          prefixIconConstraints: BoxConstraints(minWidth: 52),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dosageController,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Dosage is required'
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Dosage',
                          hintText: 'e.g. 500mg or 1 tablet',
                          prefixIcon: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: Icon(Icons.scale_outlined, size: 20),
                          ),
                          prefixIconConstraints: BoxConstraints(minWidth: 52),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel(label: 'Frequency'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _frequencies
                            .map(
                              (f) => _Chip(
                                label: f,
                                isSelected: _frequency == f,
                                onTap: () => setState(() => _frequency = f),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Reminder Times ───────────────────────────
                _SectionCard(
                  label: 'Reminder Times',
                  icon: Icons.alarm_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedTimes.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedTimes
                              .map(
                                (t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.alarm_rounded,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _fmt(t),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => setState(
                                          () => _selectedTimes.remove(t),
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      GestureDetector(
                        onTap: _addTime,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_alarm_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Add Reminder Time',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to pick time. Add multiple for different doses.',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Food Relation ────────────────────────────
                _SectionCard(
                  label: 'Food Relation',
                  icon: Icons.restaurant_outlined,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _foodRelations
                        .map(
                          (f) => _Chip(
                            label: f,
                            isSelected: _foodRelation == f,
                            onTap: () => setState(() => _foodRelation = f),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Duration ─────────────────────────────────
                _SectionCard(
                  label: 'Duration',
                  icon: Icons.calendar_month_outlined,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _durations
                        .map(
                          (d) => _Chip(
                            label: d == 90 ? '3 months' : '$d days',
                            isSelected: _durationDays == d,
                            onTap: () => setState(() => _durationDays = d),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Additional Info ──────────────────────────
                _SectionCard(
                  label: 'Additional Info',
                  icon: Icons.info_outline_rounded,
                  child: Column(
                    children: [
                      // Reminder toggle
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _reminderEnabled
                              ? AppColors.primary.withValues(alpha: 0.07)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _reminderEnabled
                                ? AppColors.primary
                                : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.notifications_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Reminder Notifications',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: _reminderEnabled
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Switch(
                              value: _reminderEnabled,
                              onChanged: (v) =>
                                  setState(() => _reminderEnabled = v),
                              activeThumbColor: AppColors.primary,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          hintText: 'e.g. Take with warm water',
                          prefixIcon: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: Icon(Icons.notes_rounded, size: 20),
                          ),
                          prefixIconConstraints: BoxConstraints(minWidth: 52),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                PrimaryButton(
                  label: 'Save & Set Reminders',
                  icon: Icons.alarm_add_rounded,
                  onPressed: _handleSave,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section Card — exact same style as daily_checkin_screen ───
class _SectionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget child;
  const _SectionCard({
    required this.label,
    required this.icon,
    required this.child,
  });

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
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
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

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
  );
}

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
