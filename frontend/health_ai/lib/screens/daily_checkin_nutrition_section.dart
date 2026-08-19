// ============================================================
// NUTRISCAN — REPLACEMENT NUTRITION SECTION
// 
// In your daily_checkin_screen.dart, find the NUTRITION
// _SectionCard and replace its entire block with this code.
// 
// Also add these imports to daily_checkin_screen.dart:
//   import 'dart:io';
//   import '../services/nutriscan_service.dart';
//   import '../widgets/nutriscan_sheet.dart';
//
// Add these state variables inside _DailyCheckinScreenState:
//   File? _scannedImage;
//   NutriScanResult? _scanResult;
//   bool _isScanning = false;
// ============================================================

// ── NutriScan method — add to _DailyCheckinScreenState ───────
/*
Future<void> _handleNutriScan({bool fromCamera = true}) async {
  setState(() => _isScanning = true);

  // Step 1: Pick image
  final image = await NutriScanService().pickImage(fromCamera: fromCamera);
  if (image == null) {
    setState(() => _isScanning = false);
    return;
  }

  // Step 2: Send to API
  final result = await NutriScanService().detectFood(image);
  setState(() {
    _scannedImage = image;
    _isScanning = false;
  });

  if (!mounted) return;

  if (result == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'NutriScan server offline. Make sure FastAPI is running.',
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    return;
  }

  if (!result.success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message.isEmpty
            ? 'No food detected. Try a clearer image.'
            : result.message),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    return;
  }

  // Step 3: Show results sheet with portion adjuster
  if (!mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => NutriScanSheet(
      imageFile: image,
      initialResult: result,
      onApply: (calories, protein, carbs, fat) {
        // AUTO-FILL — updates your existing controllers directly
        _caloriesController.text = calories.toStringAsFixed(0);
        _proteinController.text  = protein.toStringAsFixed(1);
        _carbsController.text    = carbs.toStringAsFixed(1);
        _fatController.text      = fat.toStringAsFixed(1);

        setState(() => _scanResult = result);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nutrition filled: ${calories.toStringAsFixed(0)} kcal · '
              '${protein.toStringAsFixed(1)}g protein',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    ),
  );
}
*/

// ── Replace the existing Nutrition _SectionCard with this ─────
// Find: _SectionCard(label: 'Nutrition', child: Column(...))
// Replace entire block with:

/*
_SectionCard(
  label: 'Nutrition',
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      // ── NutriScan button (replaces old _CameraHint) ───────
      Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _isScanning ? null : () => _handleNutriScan(fromCamera: true),
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
                      _isScanning ? 'Scanning...' : 'Scan Food',
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
          // Gallery option
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

      // ── Scan result preview ───────────────────────────────
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
                  'Auto-filled from: ${_scanResult!.detectedFoods.join(", ")}',
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

      // ── Manual entry fields (same as before) ──────────────
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
*/
