import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/auth_widgets.dart';
import 'onboarding_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _termsAccepted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please accept the Terms & Conditions'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final fullName = _nameController.text.trim();

      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      // ── FIX 1: Check if signup actually succeeded ──────────
      // Supabase returns a user even when email confirmation is ON
      // but session will be null until they confirm.
      // We navigate to onboarding regardless — user will login after confirm.
      if (response.user == null) {
        // This only happens in very rare cases (duplicate unconfirmed email)
        _showError('Signup failed. This email may already be registered.');
        return;
      }

      // ── FIX 2: Check if email confirmation is required ─────
      // If session is null → email confirmation is ON in Supabase
      // Show a message instead of navigating (they can't use the app yet)
      if (response.session == null) {
        // Email confirmation required — show info dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: const EdgeInsets.all(28),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_rounded,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Check Your Email',
                  style: AppTextStyles.titleLarge.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 10),
                Text(
                  'We sent a confirmation link to:\n$email\n\nOpen it to activate your account, then sign in.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Go to Sign In'),
                  ),
                ),
              ],
            ),
          ),
        );
        if (mounted) Navigator.pop(context); // back to login
        return;
      }

      // ── Session exists → no email confirmation needed ──────
      // Navigate directly to onboarding
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              OnboardingScreen(
                userName: fullName.split(' ').first,
                userEmail: email,
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      // ── FIX 3: Show the REAL error message in debug ────────
      // Previously catch(e) swallowed all non-AuthExceptions silently
      debugPrint('❌ AuthException: ${e.message} | code: ${e.statusCode}');

      String msg = 'Signup failed. Please try again.';
      final raw = e.message.toLowerCase();

      if (raw.contains('already registered') ||
          raw.contains('already exists') ||
          raw.contains('user already')) {
        msg = 'This email is already registered. Please sign in.';
      } else if (raw.contains('invalid email')) {
        msg = 'Please enter a valid email address.';
      } else if (raw.contains('weak password') ||
          (raw.contains('password') && raw.contains('least'))) {
        msg = 'Password must be at least 8 characters.';
      } else if (raw.contains('rate limit') || raw.contains('too many')) {
        msg = 'Too many attempts. Please wait a moment and try again.';
      } else if (raw.contains('email') && raw.contains('send')) {
        msg = 'Could not send confirmation email. Check your email address.';
      } else {
        // Show actual error so you can debug it
        msg = e.message;
      }

      _showError(msg);
    } catch (e) {
      // ── FIX 4: Don't silently swallow generic errors ───────
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('❌ Signup generic error: $e');
      _showError('Something went wrong: ${e.toString()}');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
                  const SizedBox(height: 20),

                  // ─── Header ───────────────────────────────
                  FadeSlideIn(
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(
                              Icons.arrow_back_rounded,
                              size: 20,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create Account',
                              style: AppTextStyles.titleLarge,
                            ),
                            Text(
                              'Step 1 of 2 — Basic Info',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const AppLogo(size: 36),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ─── Step Progress ────────────────────────
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 100),
                    child: _StepProgressBar(
                      currentStep: 1,
                      totalSteps: 2,
                      labels: const ['Account', 'Health Profile'],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ─── Form Card ────────────────────────────
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: AuthCard(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, future you!',
                                style: AppTextStyles.headlineMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Let's set up your account first.",
                                style: AppTextStyles.bodyMedium,
                              ),
                              const SizedBox(height: 24),

                              // Full Name
                              AuthTextField(
                                controller: _nameController,
                                label: 'Full Name',
                                hint: '',
                                prefixIcon: Icons.person_outline_rounded,
                                focusNode: _nameFocus,
                                validator: Validators.fullName,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) => FocusScope.of(
                                  context,
                                ).requestFocus(_emailFocus),
                              ),
                              const SizedBox(height: 16),

                              // Email
                              AuthTextField(
                                controller: _emailController,
                                label: 'Email Address',
                                hint: '',
                                prefixIcon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                focusNode: _emailFocus,
                                validator: Validators.email,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) => FocusScope.of(
                                  context,
                                ).requestFocus(_phoneFocus),
                              ),
                              const SizedBox(height: 16),

                              // Phone
                              AuthTextField(
                                controller: _phoneController,
                                label: 'Phone Number (optional)',
                                hint: '',
                                prefixIcon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                focusNode: _phoneFocus,
                                validator: Validators.phone,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) => FocusScope.of(
                                  context,
                                ).requestFocus(_passwordFocus),
                              ),
                              const SizedBox(height: 16),

                              // Password
                              AuthTextField(
                                controller: _passwordController,
                                label: 'Password',
                                hint: '',
                                prefixIcon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                focusNode: _passwordFocus,
                                validator: Validators.password,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) => FocusScope.of(
                                  context,
                                ).requestFocus(_confirmPasswordFocus),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Confirm Password
                              AuthTextField(
                                controller: _confirmPasswordController,
                                label: 'Confirm Password',
                                hint: '',
                                prefixIcon: Icons.lock_outline,
                                obscureText: _obscureConfirm,
                                focusNode: _confirmPasswordFocus,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleSignup(),
                                validator: (val) => Validators.confirmPassword(
                                  val,
                                  _passwordController.text,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Terms
                              GestureDetector(
                                onTap: () => setState(
                                  () => _termsAccepted = !_termsAccepted,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: Checkbox(
                                        value: _termsAccepted,
                                        onChanged: (val) => setState(
                                          () => _termsAccepted = val!,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                fontSize: 13,
                                                height: 1.5,
                                              ),
                                          children: const [
                                            TextSpan(text: 'I agree to the '),
                                            TextSpan(
                                              text: 'Terms of Service',
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            TextSpan(text: ' and '),
                                            TextSpan(
                                              text: 'Privacy Policy',
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              PrimaryButton(
                                label: 'Continue to Health Profile',
                                icon: Icons.arrow_forward_rounded,
                                onPressed: _handleSignup,
                                isLoading: _isLoading,
                              ),
                              const SizedBox(height: 20),

                              Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Already have an account? ',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontSize: 14,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: Text(
                                        'Sign in',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

// ─── Step Progress Bar ────────────────────────────────────────
class _StepProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> labels;

  const _StepProgressBar({
    required this.currentStep,
    required this.totalSteps,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (i) {
        final isActive = i < currentStep;
        final isCurrent = i == currentStep - 1;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isActive ? AppColors.primary : AppColors.border,
                      ),
                    ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? AppColors.primary : AppColors.border,
                      border: isCurrent
                          ? Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 3,
                            )
                          : null,
                    ),
                    child: Center(
                      child: isActive && !isCurrent
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            )
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isActive
                                    ? Colors.white
                                    : AppColors.textHint,
                              ),
                            ),
                    ),
                  ),
                  if (i < totalSteps - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i < currentStep - 1
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                labels[i],
                style: AppTextStyles.caption.copyWith(
                  color: isActive ? AppColors.primary : AppColors.textHint,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
