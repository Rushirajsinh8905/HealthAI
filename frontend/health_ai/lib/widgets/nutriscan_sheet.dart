// ============================================================
// HEALTHAI — NUTRISCAN BOTTOM SHEET
// File: lib/widgets/nutriscan_sheet.dart
// Shows scan results with S/M/L portion adjuster before auto-fill
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/nutriscan_service.dart';

class NutriScanSheet extends StatefulWidget {
  final File imageFile;
  final NutriScanResult initialResult;

  /// Called when user taps "Auto-fill" — passes final nutrition totals
  final void Function(double calories, double protein, double carbs, double fat)
  onApply;

  const NutriScanSheet({
    super.key,
    required this.imageFile,
    required this.initialResult,
    required this.onApply,
  });

  @override
  State<NutriScanSheet> createState() => _NutriScanSheetState();
}

class _NutriScanSheetState extends State<NutriScanSheet> {
  late List<DetectedFood> _foods;
  bool _isRecalculating = false;

  // Running totals from current food list
  double get _totalCalories => _foods.fold(0.0, (s, f) => s + f.calories);
  double get _totalProtein => _foods.fold(0.0, (s, f) => s + f.protein);
  double get _totalCarbs => _foods.fold(0.0, (s, f) => s + f.carbs);
  double get _totalFat => _foods.fold(0.0, (s, f) => s + f.fat);

  @override
  void initState() {
    super.initState();
    // Only show found items
    _foods = widget.initialResult.itemsBreakdown.where((f) => f.found).toList();
  }

  // ── User changed S/M/L for one item ────────────────────────
  Future<void> _onPortionChanged(int index, String newPortion) async {
    // Update portion label immediately (optimistic UI)
    setState(() {
      _foods[index] = _foods[index].withPortion(newPortion);
      _isRecalculating = true;
    });

    // Re-fetch nutrition from server with updated portions
    final result = await NutriScanService().rescanWithPortions(
      widget.imageFile,
      _foods,
    );

    if (!mounted) return;
    setState(() {
      _isRecalculating = false;
      if (result != null && result.itemsBreakdown.isNotEmpty) {
        _foods = result.itemsBreakdown.where((f) => f.found).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ──────────────────────────────────
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // ── Header ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.camera_enhance_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NutriScan Results',
                          style: AppTextStyles.titleLarge.copyWith(
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          _foods.isEmpty
                              ? 'No food detected'
                              : '${_foods.length} item${_foods.length != 1 ? "s" : ""} detected',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  // Recalculating spinner
                  if (_isRecalculating)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Nutrition totals banner ───────────────────────
            if (_foods.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MacroPill(
                        label: 'Calories',
                        value: '${_totalCalories.toStringAsFixed(0)} kcal',
                      ),
                      _MacroPill(
                        label: 'Protein',
                        value: '${_totalProtein.toStringAsFixed(1)}g',
                      ),
                      _MacroPill(
                        label: 'Carbs',
                        value: '${_totalCarbs.toStringAsFixed(1)}g',
                      ),
                      _MacroPill(
                        label: 'Fat',
                        value: '${_totalFat.toStringAsFixed(1)}g',
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 14),

            // ── Food items list OR empty state ────────────────
            if (_foods.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    const Icon(
                      Icons.no_food_outlined,
                      color: AppColors.textSecondary,
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No food items recognized.',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try a closer photo with food filling the frame.',
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              // Scrollable list in case there are many items
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.35,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _foods.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: AppColors.divider, height: 1),
                  itemBuilder: (ctx, i) => _FoodRow(
                    food: _foods[i],
                    onPortionChanged: (p) => _onPortionChanged(i, p),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // ── Action buttons ────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Row(
                children: [
                  // Cancel
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Auto-fill button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _foods.isEmpty
                          ? null
                          : () {
                              Navigator.pop(context);
                              widget.onApply(
                                _totalCalories,
                                _totalProtein,
                                _totalCarbs,
                                _totalFat,
                              );
                            },
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                      label: const Text('Auto-fill Nutrition'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single food row with S/M/L selector ──────────────────────
class _FoodRow extends StatelessWidget {
  final DetectedFood food;
  final ValueChanged<String> onPortionChanged;

  const _FoodRow({required this.food, required this.onPortionChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Food icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Name + nutrition summary
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.displayName.isEmpty
                      ? food.foodName.replaceAll('_', ' ')
                      : food.displayName,
                  style: AppTextStyles.labelLarge.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '${food.calories.toStringAsFixed(0)} kcal  ·  '
                  'P ${food.protein.toStringAsFixed(1)}g  ·  '
                  'C ${food.carbs.toStringAsFixed(1)}g  ·  '
                  'F ${food.fat.toStringAsFixed(1)}g',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  '${(food.confidence * 100).toStringAsFixed(0)}% confidence',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // S / M / L portion toggle
          _PortionToggle(selected: food.portion, onChanged: onPortionChanged),
        ],
      ),
    );
  }
}

// ── S/M/L Toggle ─────────────────────────────────────────────
class _PortionToggle extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _PortionToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['small', 'medium', 'large'].map((p) {
          final isSelected = p == selected;
          return GestureDetector(
            onTap: () => onChanged(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                p[0].toUpperCase(), // S / M / L
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Macro pill for the gradient banner ───────────────────────
class _MacroPill extends StatelessWidget {
  final String label;
  final String value;
  const _MacroPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }
}
