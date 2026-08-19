// ============================================================
// HEALTH AI — RESET PASSWORD SCREEN
// Reached via deep link after user clicks the email reset link.
// Supabase automatically restores the session token from the URL,
// so we just need to call updateUser() with the new password.
// ============================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey         = GlobalKey<FormState>();
  final _passwordCtrl    = TextEditingController();
  final _confirmCtrl     = TextEditingController();
  final _passwordFocus   = FocusNode();
  final _confirmFocus    = FocusNode();

  bool _obscurePassword  = true;
  bool _obscureConfirm   = true;
  bool _isLoading        = false;
  bool _isDone           = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  // ─── Validate + save new password ────────────────────────
  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordCtrl.text),
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isDone    = true;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update password. Try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
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
                children: [
                  const SizedBox(height: 40),

                  // Logo
                  const AppLogo(),
                  const SizedBox(height: 32),

                  // Card
                  AuthCard(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: _isDone ? _buildSuccessBody() : _buildFormBody(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Success state ────────────────────────────────────────
  Widget _buildSuccessBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 60,
          color: AppColors.success,
        ),
        const SizedBox(height: 16),
        Text('Password Updated!', style: AppTextStyles.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Your password has been changed successfully.\nYou can now sign in with your new password.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium,
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Go to Sign In',
          icon: Icons.login_rounded,
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (_) => false,
            );
          },
        ),
      ],
    );
  }

  // ─── Form state ───────────────────────────────────────────
  Widget _buildFormBody() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Set New Password', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Enter and confirm your new password below.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 28),

          // New password
          AuthTextField(
            controller: _passwordCtrl,
            label: 'New Password',
            hint: '',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscurePassword,
            focusNode: _passwordFocus,
            textInputAction: TextInputAction.next,
            validator: Validators.password,
            onFieldSubmitted: (_) =>
                FocusScope.of(context).requestFocus(_confirmFocus),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),

          const SizedBox(height: 16),

          // Confirm password
          AuthTextField(
            controller: _confirmCtrl,
            label: 'Confirm Password',
            hint: '',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscureConfirm,
            focusNode: _confirmFocus,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleReset(),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Please confirm your password';
              if (val != _passwordCtrl.text) return 'Passwords do not match';
              return null;
            },
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),

          const SizedBox(height: 28),

          PrimaryButton(
            label: 'Update Password',
            icon: Icons.check_rounded,
            onPressed: _handleReset,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }
}
