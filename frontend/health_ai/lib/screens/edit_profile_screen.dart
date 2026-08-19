// ============================================================
// HEALTHAI — EDIT PROFILE SCREEN
// Lets users update their static health profile at any time.
// Pre-fills all current values from Supabase.
// Reuses saveProfile (upsert on email) — no new DB method needed.
//
// HOW TO ADD TO YOUR APP:
//   1. Place this file in lib/screens/edit_profile_screen.dart
//   2. In profile_screen.dart AppBar, add an edit action (shown below)
//   3. That's it — saveProfile already handles upsert correctly.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import '../widgets/auth_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  /// Pass the current profile map so fields are pre-filled.
  final Map<String, dynamic> currentProfile;

  const EditProfileScreen({super.key, required this.currentProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _db = SupabaseService();
  bool _isLoading = false;

  // ── Controllers ───────────────────────────────────────────
  late final TextEditingController _ageController;
  late final TextEditingController _heightController;
  late final TextEditingController _currentDiseasesController;
  late final TextEditingController _pastDiseasesController;

  // ── Selected values (pre-filled from current profile) ─────
  String? _gender;
  String? _smokingHabit;
  String? _alcoholConsumption;
  String? _occupation;
  String? _mentalHealthCondition;
  String? _country;
  String _hasDiabetes = 'No';
  String _underTreatment = 'No';

  // ── Options (same as OnboardingScreen) ────────────────────
  static const _genders = ['Male', 'Female', 'Non-binary'];
  static const _smokingOptions = ['Never', 'Former', 'Occasional', 'Regular'];
  static const _alcoholOptions = ['Never', 'Rarely', 'Moderate', 'Heavy'];
  static const _mentalHealthOptions = [
    'None',
    'Anxiety',
    'Depression',
    'Other',
  ];
  static const _occupations = [
    'Student',
    'Software Engineer',
    'Doctor',
    'Teacher',
    'Business',
    'Healthcare',
    'Engineering',
    'Finance',
    'Arts & Design',
    'Retired',
    'Other',
  ];
  static const _countries = [
    'India',
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
    'Germany',
    'France',
    'Japan',
    'Brazil',
    'Singapore',
    'UAE',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.currentProfile;

    // Pre-fill controllers from existing profile data
    _ageController = TextEditingController(text: p['age']?.toString() ?? '');
    _heightController = TextEditingController(
      text: (p['height_cm'] as num?)?.toStringAsFixed(0) ?? '',
    );
    _currentDiseasesController = TextEditingController(
      text: _cleanDash(p['current_diseases']),
    );
    _pastDiseasesController = TextEditingController(
      text: _cleanDash(p['past_diseases']),
    );

    // Pre-select dropdown / chip values
    _gender = _validOrNull(p['gender'], _genders);
    _smokingHabit = _validOrNull(p['smoking_habit'], _smokingOptions);
    _alcoholConsumption = _validOrNull(
      p['alcohol_consumption'],
      _alcoholOptions,
    );
    _occupation = _validOrNull(p['occupation'], _occupations);
    _mentalHealthCondition = _validOrNull(
      p['mental_health_condition'],
      _mentalHealthOptions,
    );
    _country = _validOrNull(p['country'], _countries);
    _hasDiabetes = (p['diabetes'] == 'Yes') ? 'Yes' : 'No';
    _underTreatment = (p['under_treatment'] == 'Yes') ? 'Yes' : 'No';
  }

  // Returns value only if it exists in the allowed list, otherwise null
  String? _validOrNull(dynamic val, List<String> options) {
    if (val == null) return null;
    final s = val.toString().trim();
    return options.contains(s) ? s : null;
  }

  // Replace '—' placeholder with empty string for text fields
  String _cleanDash(dynamic val) {
    if (val == null) return '';
    final s = val.toString().trim();
    return (s == '—' || s == 'missing') ? '' : s;
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _currentDiseasesController.dispose();
    _pastDiseasesController.dispose();
    super.dispose();
  }

  // ── Validation ─────────────────────────────────────────────
  bool _validate() {
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 13 || age > 120) {
      _showError('Enter a valid age (13–120)');
      return false;
    }
    final height = double.tryParse(_heightController.text.trim());
    if (height == null || height < 50 || height > 250) {
      _showError('Enter a valid height (50–250 cm)');
      return false;
    }
    if (_gender == null) {
      _showError('Please select gender');
      return false;
    }
    if (_smokingHabit == null) {
      _showError('Please select smoking habit');
      return false;
    }
    if (_alcoholConsumption == null) {
      _showError('Please select alcohol consumption');
      return false;
    }
    if (_occupation == null) {
      _showError('Please select occupation');
      return false;
    }
    if (_mentalHealthCondition == null) {
      _showError('Please select mental health condition');
      return false;
    }
    if (_country == null) {
      _showError('Please select country');
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

  // ── Save ────────────────────────────────────────────────────
  Future<void> _handleSave() async {
    if (!_validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    // Diseases: store '—' if user left blank
    final currentDiseases = _currentDiseasesController.text.trim().isEmpty
        ? '—'
        : _currentDiseasesController.text.trim();
    final pastDiseases = _pastDiseasesController.text.trim().isEmpty
        ? '—'
        : _pastDiseasesController.text.trim();

    final result = await _db.saveProfile(
      // fullName and email are NOT editable here — keep existing values
      fullName: (widget.currentProfile['full_name'] as String?) ?? '',
      email: (widget.currentProfile['email'] as String?) ?? '',
      age: int.parse(_ageController.text.trim()),
      heightCm: double.parse(_heightController.text.trim()),
      gender: _gender!,
      occupation: _occupation!,
      country: _country!,
      smokingHabit: _smokingHabit!,
      alcoholConsumption: _alcoholConsumption!,
      diabetes: _hasDiabetes,
      mentalHealthCondition: _mentalHealthCondition!,
      underTreatment: _underTreatment,
      currentDiseases: currentDiseases,
      pastDiseases: pastDiseases,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      // Pop and signal the profile screen to reload
      Navigator.pop(context, true);
    } else {
      _showError('Failed to save. Check your connection.');
    }
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
          'Edit Health Profile',
          style: AppTextStyles.titleLarge,
        ),
        centerTitle: false,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Info banner explaining WHY this exists ──────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Update your health profile whenever your situation changes — '
                        'new diagnosis, lifestyle change, or medication status. '
                        'Your AI health score will reflect the update from the next check-in.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ══════════════════════════════════════════════
              // BODY STATS
              // ══════════════════════════════════════════════
              _SectionCard(
                label: 'Body Stats',
                icon: Icons.monitor_weight_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _NumberField(
                            controller: _ageController,
                            label: 'Age',
                            suffix: 'yrs',
                            maxLength: 3,
                            digitsOnly: true,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _NumberField(
                            controller: _heightController,
                            label: 'Height',
                            suffix: 'cm',
                            maxLength: 5,
                            digitsOnly: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const _FieldLabel(label: 'Gender'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _genders
                          .map(
                            (g) => _Chip(
                              label: g,
                              isSelected: _gender == g,
                              onTap: () => setState(() => _gender = g),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              _SectionCard(
                label: 'Medical Status',
                icon: Icons.local_hospital_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ToggleRow(
                      label: 'Diabetes',
                      value: _hasDiabetes == 'Yes',
                      onChanged: (v) =>
                          setState(() => _hasDiabetes = v ? 'Yes' : 'No'),
                    ),
                    const SizedBox(height: 12),
                    _ToggleRow(
                      label: 'Under Medical Treatment',
                      value: _underTreatment == 'Yes',
                      onChanged: (v) =>
                          setState(() => _underTreatment = v ? 'Yes' : 'No'),
                    ),
                    const SizedBox(height: 16),

                    const _FieldLabel(label: 'Mental Health Condition'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _mentalHealthOptions
                          .map(
                            (o) => _Chip(
                              label: o,
                              isSelected: _mentalHealthCondition == o,
                              onTap: () =>
                                  setState(() => _mentalHealthCondition = o),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),

                    // Current diseases free-text
                    TextFormField(
                      controller: _currentDiseasesController,
                      textCapitalization: TextCapitalization.sentences,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Current Diseases / Conditions',
                        hintText: 'e.g. Hypertension, Asthma (or leave blank)',
                        prefixIcon: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Icon(Icons.sick_outlined, size: 20),
                        ),
                        prefixIconConstraints: BoxConstraints(minWidth: 52),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Past diseases free-text
                    TextFormField(
                      controller: _pastDiseasesController,
                      textCapitalization: TextCapitalization.sentences,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Past Diseases / Conditions',
                        hintText: 'e.g. Typhoid, Fracture (or leave blank)',
                        prefixIcon: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Icon(Icons.history_edu_outlined, size: 20),
                        ),
                        prefixIconConstraints: BoxConstraints(minWidth: 52),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ══════════════════════════════════════════════
              // LIFESTYLE HABITS
              // ══════════════════════════════════════════════
              _SectionCard(
                label: 'Lifestyle Habits',
                icon: Icons.self_improvement_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel(label: 'Smoking Habit'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _smokingOptions
                          .map(
                            (o) => _Chip(
                              label: o,
                              isSelected: _smokingHabit == o,
                              onTap: () => setState(() => _smokingHabit = o),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    const _FieldLabel(label: 'Alcohol Consumption'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _alcoholOptions
                          .map(
                            (o) => _Chip(
                              label: o,
                              isSelected: _alcoholConsumption == o,
                              onTap: () =>
                                  setState(() => _alcoholConsumption = o),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ══════════════════════════════════════════════
              // OCCUPATION & LOCATION
              // ══════════════════════════════════════════════
              _SectionCard(
                label: 'Occupation & Location',
                icon: Icons.work_outline_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel(label: 'Occupation'),
                    const SizedBox(height: 10),
                    _SimpleDropdown(
                      value: _occupation,
                      options: _occupations,
                      hint: 'Select occupation',
                      onChanged: (val) => setState(() => _occupation = val),
                    ),
                    const SizedBox(height: 16),
                    const _FieldLabel(label: 'Country'),
                    const SizedBox(height: 10),
                    _SimpleDropdown(
                      value: _country,
                      options: _countries,
                      hint: 'Select country',
                      onChanged: (val) => setState(() => _country = val),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              PrimaryButton(
                label: 'Save Profile Changes',
                icon: Icons.check_circle_outline_rounded,
                onPressed: _handleSave,
                isLoading: _isLoading,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// REUSABLE WIDGETS (same style as onboarding_screen.dart)
// ─────────────────────────────────────────────────────────────

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

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;
  final int maxLength;
  final bool digitsOnly;
  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.maxLength,
    required this.digitsOnly,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: digitsOnly
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        if (digitsOnly)
          FilteringTextInputFormatter.digitsOnly
        else
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        LengthLimitingTextInputFormatter(maxLength),
      ],
      style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        counterText: '',
        suffixStyle: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SimpleDropdown extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  const _SimpleDropdown({
    required this.value,
    required this.hint,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 20,
        color: AppColors.textSecondary,
      ),
      style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
      dropdownColor: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      decoration: InputDecoration(hintText: hint),
      items: options
          .map(
            (o) => DropdownMenuItem(
              value: o,
              child: Text(
                o,
                style: AppTextStyles.bodyMedium.copyWith(fontSize: 14),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: value
            ? AppColors.primary.withValues(alpha: 0.07)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? AppColors.primary : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
              color: value ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
