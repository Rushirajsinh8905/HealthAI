// ============================================================
// HEALTHAI — ONBOARDING SCREEN
// Single scrollable screen with all TFT static features
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';
import 'dashboard_screen.dart';
import '../services/supabase_service.dart';

class OnboardingScreen extends StatefulWidget {
  final String userName;
  final String userEmail;

  const OnboardingScreen({
    super.key,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _db = SupabaseService();

  // ── static_reals ──────────────────────────────────────────
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();

  // ── static_categoricals ──────────────────────────────────
  String? _gender;
  String? _smokingHabit;
  String? _alcoholConsumption;
  String? _occupation;
  String? _dietQuality;
  String? _mentalHealthCondition;
  String? _country;
  String _hasDiabetes = 'No';
  String _underTreatment = 'No';

  bool _isLoading = false;

  // ── Options ───────────────────────────────────────────────
  static const _genders = ['Male', 'Female', 'Non-binary'];
  static const _smokingOptions = ['Never', 'Former', 'Occasional', 'Regular'];
  static const _alcoholOptions = ['Never', 'Rarely', 'Moderate', 'Heavy'];
  static const _dietOptions = [
    'Balanced',
    'Keto',
    'Moderate',
    'Unhealthy',
    'Vegetarian',
  ];
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
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────
  bool _validate() {
    if (_ageController.text.isEmpty || _heightController.text.isEmpty) {
      _showError('Please enter age and height');
      return false;
    }
    final age = int.tryParse(_ageController.text);
    if (age == null || age < 13 || age > 120) {
      _showError('Enter a valid age (13–120)');
      return false;
    }
    final height = double.tryParse(_heightController.text);
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
    if (_dietQuality == null) {
      _showError('Please select diet quality');
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

  // ── Submit ────────────────────────────────────────────────
  Future<void> _handleComplete() async {
    if (!_validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    // Health profile map — matches TFT field names exactly
    final healthProfile = {
      'Age': int.parse(_ageController.text),
      'Height_cm': double.parse(_heightController.text),
      'Gender': _gender,
      'Smoking_Habit': _smokingHabit,
      'Alcohol_Consumption': _alcoholConsumption,
      'Occupation': _occupation,
      'Diet_Quality': _dietQuality,
      'Diabetes': _hasDiabetes,
      'Mental_Health_Condition': _mentalHealthCondition,
      'under_treatment': _underTreatment,
      'Country': _country,
    };

    debugPrint('Health Profile: $healthProfile');

    // ── Save to Supabase ─────────────────────────────────
    // saveProfile returns Map<String, dynamic>? (the saved row)
    final profile = await _db.saveProfile(
      fullName: widget.userName,
      email: widget.userEmail,
      age: int.parse(_ageController.text),
      heightCm: double.parse(_heightController.text),
      gender: _gender!,
      occupation: _occupation!,
      country: _country!,
      smokingHabit: _smokingHabit!,
      alcoholConsumption: _alcoholConsumption!,
      diabetes: _hasDiabetes,
      mentalHealthCondition: _mentalHealthCondition!,
      underTreatment: _underTreatment,
    );

    if (profile == null && mounted) {
      _showError('Failed to save profile. Check your connection.');
      setState(() => _isLoading = false);
      return;
    }

    // Set active user so Dashboard + service know who is logged in
    _db.setActiveUser(widget.userEmail);

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              DashboardScreen(userEmail: widget.userEmail),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),

                  // ── Logo ──────────────────────────────────
                  FadeSlideIn(child: const Center(child: AppLogo())),

                  const SizedBox(height: 28),

                  // ── Page title ────────────────────────────
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Health Profile',
                          style: AppTextStyles.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tell us about yourself, ${widget.userName}',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ══════════════════════════════════════════
                  // BODY STATS
                  // ══════════════════════════════════════════
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 150),
                    child: AuthCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(label: 'Body Stats'),
                            const SizedBox(height: 18),

                            // Age & Height row
                            Row(
                              children: [
                                Expanded(
                                  child: _NumberField(
                                    controller: _ageController,
                                    label: 'Age',
                                    hint: '',
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
                                    hint: '',
                                    suffix: 'cm',
                                    maxLength: 5,
                                    digitsOnly: false,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Gender
                            const Text('Gender', style: _kFieldLabel),
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
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ══════════════════════════════════════════
                  // LIFESTYLE HABITS
                  // ══════════════════════════════════════════
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: AuthCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(label: 'Lifestyle Habits'),
                            const SizedBox(height: 18),

                            // Smoking
                            const Text('Smoking Habit', style: _kFieldLabel),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _smokingOptions
                                  .map(
                                    (o) => _Chip(
                                      label: o,
                                      isSelected: _smokingHabit == o,
                                      onTap: () =>
                                          setState(() => _smokingHabit = o),
                                    ),
                                  )
                                  .toList(),
                            ),

                            const SizedBox(height: 20),

                            // Alcohol
                            const Text(
                              'Alcohol Consumption',
                              style: _kFieldLabel,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _alcoholOptions
                                  .map(
                                    (o) => _Chip(
                                      label: o,
                                      isSelected: _alcoholConsumption == o,
                                      onTap: () => setState(
                                        () => _alcoholConsumption = o,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),

                            const SizedBox(height: 20),

                            // Diet Quality
                            const Text('Diet Quality', style: _kFieldLabel),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _dietOptions
                                  .map(
                                    (o) => _Chip(
                                      label: o,
                                      isSelected: _dietQuality == o,
                                      onTap: () =>
                                          setState(() => _dietQuality = o),
                                    ),
                                  )
                                  .toList(),
                            ),

                            const SizedBox(height: 20),

                            // Occupation
                            const Text('Occupation', style: _kFieldLabel),
                            const SizedBox(height: 10),
                            _SimpleDropdown(
                              value: _occupation,
                              hint: '',
                              options: _occupations,
                              onChanged: (val) =>
                                  setState(() => _occupation = val),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ══════════════════════════════════════════
                  // MEDICAL HISTORY
                  // ══════════════════════════════════════════
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 250),
                    child: AuthCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(label: 'Medical History'),
                            const SizedBox(height: 18),

                            // Diabetes toggle
                            _ToggleRow(
                              label: 'Diabetes',
                              value: _hasDiabetes == 'Yes',
                              onChanged: (val) => setState(
                                () => _hasDiabetes = val ? 'Yes' : 'No',
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Under treatment toggle
                            _ToggleRow(
                              label: 'Under Medical Treatment',
                              value: _underTreatment == 'Yes',
                              onChanged: (val) => setState(
                                () => _underTreatment = val ? 'Yes' : 'No',
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Mental Health
                            const Text(
                              'Mental Health Condition',
                              style: _kFieldLabel,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _mentalHealthOptions
                                  .map(
                                    (o) => _Chip(
                                      label: o,
                                      isSelected: _mentalHealthCondition == o,
                                      onTap: () => setState(
                                        () => _mentalHealthCondition = o,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ══════════════════════════════════════════
                  // LOCATION
                  // ══════════════════════════════════════════
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 300),
                    child: AuthCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(label: 'Location'),
                            const SizedBox(height: 18),

                            const Text('Country', style: _kFieldLabel),
                            const SizedBox(height: 10),
                            _SimpleDropdown(
                              value: _country,
                              hint: '',
                              options: _countries,
                              onChanged: (val) =>
                                  setState(() => _country = val),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Submit button ─────────────────────────
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 350),
                    child: PrimaryButton(
                      label: 'Complete Setup',
                      icon: Icons.check_circle_outline_rounded,
                      onPressed: _handleComplete,
                      isLoading: _isLoading,
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Field label constant ──────────────────────────────────────
const _kFieldLabel = TextStyle(
  fontFamily: 'sans-serif',
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: AppColors.textPrimary,
);

// ── Section Label ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
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
        Text(label, style: AppTextStyles.titleLarge.copyWith(fontSize: 15)),
      ],
    );
  }
}

// ── Single-color Chip ─────────────────────────────────────────
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
            fontFamily: 'sans-serif',
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Number Input Field ────────────────────────────────────────
class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String suffix;
  final int maxLength;
  final bool digitsOnly;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.hint,
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

// ── Simple Dropdown ───────────────────────────────────────────
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
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
      ),
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

// ── Toggle Row ────────────────────────────────────────────────
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
