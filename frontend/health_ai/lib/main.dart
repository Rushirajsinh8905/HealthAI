import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/daily_checkin_screen.dart';
import 'screens/recommendations_screen.dart';
import 'screens/medication_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/reset_password_screen.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await Supabase.initialize(
    url: 'https://pnjaolucdpngynmlcgjc.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBuamFvbHVjZHBuZ3lubWxjZ2pjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIxNzIyNDYsImV4cCI6MjA4Nzc0ODI0Nn0.1lbHz9FF7ZS_WZasXWEM5EEJKg3JdZ7scFLewc69jWA',
  );

  // ── Restore session → _activeEmail stays valid across restarts ──
  final session = Supabase.instance.client.auth.currentSession;
  if (session != null) {
    final email = session.user.email ?? '';
    if (email.isNotEmpty) SupabaseService().setActiveUser(email);
  }

  // ── Start the app immediately so there's no white screen ──────
  // Notification permission is requested AFTER the first frame renders,
  // so the app UI is visible before any permission dialogs appear.
  runApp(const HealthAIApp());

  // ── Request permissions + schedule reminders after first frame ─
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await NotificationService().init();
    await NotificationService().scheduleDailyCheckInReminder();
  });
}

class HealthAIApp extends StatefulWidget {
  const HealthAIApp({super.key});

  @override
  State<HealthAIApp> createState() => _HealthAIAppState();
}

class _HealthAIAppState extends State<HealthAIApp> {

  @override
  void initState() {
    super.initState();
    // ─ Listen for Supabase auth events, including passwordRecovery (deep link) ─
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        // Deep link landed → navigate to the reset password screen
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
          (_) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    final hasSession = session != null;

    return MaterialApp(
      title: 'Health AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,

      // ─ Required for notification tap + deep link navigation ─────
      navigatorKey: navigatorKey,

      initialRoute: hasSession ? '/dashboard' : '/login',

      // ─ Named routes match NotificationService payloads ────────
      routes: {
        '/login':           (_) => const LoginScreen(),
        '/reset-password':  (_) => const ResetPasswordScreen(),
        '/dashboard': (_) {
          final email = Supabase.instance.client.auth.currentUser?.email ?? '';
          return DashboardScreen(userEmail: email);
        },
        '/checkin':         (_) => const DailyCheckinScreen(),
        '/recommendations': (_) => const RecommendationsScreen(),
        '/medications':     (_) => const MedicationScreen(),
      },
    );
  }
}
