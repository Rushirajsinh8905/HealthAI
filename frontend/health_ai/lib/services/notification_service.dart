import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'api_service.dart';

// ── Global navigator key — assign in MaterialApp ──────────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ── Notification IDs ──────────────────────────────────────────
class _NId {
  static const int dailyReminder = 1;
  static const int eveningSummary = 2;
  static const int scoreConfirm = 3;
  static const int tftInsight = 4;
  static const int test = 99;
  // Medication IDs: dynamic via (medicationId + time).hashCode % 100000
  // Range: 0–99999  (safe — never collides with fixed IDs above)
}

// ── Tap payloads — match route names in main.dart ─────────────
class _Payload {
  static const String checkin = '/checkin';
  static const String dashboard = '/dashboard';
  static const String recommendations = '/recommendations';
  static const String medications = '/medications';
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _tz = 'Asia/Kolkata';
  static const _chMain = 'healthai_main';
  static const _chReminder = 'healthai_reminder';
  static const _chInsight = 'healthai_insight';
  static const _chMed = 'healthai_medication';

  // ─────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────
  Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_tz));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: _onTapBackground,
    );

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    // ── Step 1: POST_NOTIFICATIONS permission (Android 13+) ───────────
    await androidImpl?.requestNotificationsPermission();

    // ── Step 2: SCHEDULE_EXACT_ALARM permission (Android 12+) ─────────
    // This is a SPECIAL PERMISSION — not granted automatically at install.
    // Without it, zonedSchedule + exactAllowWhileIdle silently never fires.
    // requestExactAlarmsPermission() opens Settings if not yet granted.
    final exactGranted =
        await androidImpl?.requestExactAlarmsPermission() ?? false;

    if (!exactGranted) {
      debugPrint(
        'NotificationService ⚠️  Exact alarm NOT granted.\n'
        'Go to: Settings → Apps → Special App Access → Alarms & Reminders',
      );
    }

    debugPrint('NotificationService ✅  IST locked | exactAlarm=$exactGranted');
  }

  // ─────────────────────────────────────────────────────────
  // 1. INSTANT SCORE CONFIRMATION
  // ─────────────────────────────────────────────────────────
  Future<void> sendScoreConfirmation({
    required double score,
    required String userName,
  }) async {
    final emoji = _scoreEmoji(score);
    final label = _scoreLabel(score);
    await _show(
      id: _NId.scoreConfirm,
      title: '$emoji Check-in saved, $userName!',
      body:
          'Your score: ${score.toStringAsFixed(1)}/100 — $label. '
          'AI is now analysing your data for a personalised insight…',
      channel: _chMain,
      chName: 'HealthAI Notifications',
      chDesc: 'Health score updates',
      payload: _Payload.dashboard,
    );
  }

  // ─────────────────────────────────────────────────────────
  // 2. TFT-POWERED RECOMMENDATION NOTIFICATION
  // ─────────────────────────────────────────────────────────
  Future<void> sendTFTInsight({
    required RecommendResult result,
    required String userName,
  }) async {
    if (result.recommendations.isEmpty) return;

    final top = result.recommendations.first;
    final delta = top.delta.toStringAsFixed(1);
    final cur = top.currentFormatted;
    final target = top.targetFormatted;
    final feat = top.displayName;
    final baseline = result.baselineScore.toStringAsFixed(1);
    final after = (result.baselineScore + top.delta).toStringAsFixed(1);
    final tip = _firstSentence(top.tip);

    await _show(
      id: _NId.tftInsight,
      title: '🧠 AI Insight for $userName',
      body:
          '$feat: $cur → $target could add +$delta pts '
          '($baseline → $after). $tip',
      channel: _chInsight,
      chName: 'AI Health Insights',
      chDesc: 'Personalised TFT-powered recommendations',
      importance: Importance.high,
      priority: Priority.high,
      payload: _Payload.recommendations,
    );
    debugPrint('TFT insight sent → $feat +$delta pts');
  }

  // ─────────────────────────────────────────────────────────
  // 3. DAILY 9 AM REMINDER (contextual)
  // ─────────────────────────────────────────────────────────
  Future<void> scheduleDailyCheckInReminder({double? lastScore}) async {
    await _plugin.cancel(_NId.dailyReminder);

    final String title;
    final String body;

    if (lastScore == null || lastScore <= 0) {
      title = '👋 Good morning! Start your health journey';
      body =
          'Log today\'s data and let your AI coach calculate your first score.';
    } else if (lastScore >= 80) {
      title = '🔥 Can you keep the streak going?';
      body =
          'Yesterday: ${lastScore.toStringAsFixed(1)}/100 — Excellent. '
          'Log today and defend your top rating!';
    } else if (lastScore >= 65) {
      title = '📈 Good yesterday — can you beat it today?';
      body =
          'You scored ${lastScore.toStringAsFixed(1)} yesterday. '
          'Your AI coach has a tip to push it even higher.';
    } else if (lastScore >= 50) {
      title = '💪 Your AI coach is ready with today\'s plan';
      body =
          'Yesterday: ${lastScore.toStringAsFixed(1)}/100. '
          'Log in — your #1 improvement area is already identified.';
    } else {
      title = '🌱 Every check-in makes the AI smarter for you';
      body =
          'Yesterday: ${lastScore.toStringAsFixed(1)}/100. '
          'One small change today can meaningfully improve your score.';
    }

    await _plugin.zonedSchedule(
      _NId.dailyReminder,
      title,
      body,
      _nextTimeIST(9, 0),
      _notifDetails(
        channel: _chReminder,
        chName: 'Daily Reminders',
        chDesc: 'Daily check-in reminder at 9 AM',
        importance: Importance.high,
        priority: Priority.high,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: _Payload.checkin,
    );
    debugPrint('Daily reminder scheduled 9:00 AM IST ✅');
  }

  // ─────────────────────────────────────────────────────────
  // 4. 8 PM EVENING SUMMARY
  // ─────────────────────────────────────────────────────────
  Future<void> scheduleEveningSummary({
    required double healthScore,
    RecommendResult? tftResult,
  }) async {
    await _plugin.cancel(_NId.eveningSummary);

    final emoji = _scoreEmoji(healthScore);
    final label = _scoreLabel(healthScore);
    final String body;

    if (tftResult != null && tftResult.recommendations.isNotEmpty) {
      final top = tftResult.recommendations.first;
      final delta = top.delta.toStringAsFixed(1);
      body =
          '$emoji ${healthScore.toStringAsFixed(1)}/100 — $label today. '
          'Tomorrow: improve ${top.displayName} for a predicted +$delta pts.';
    } else {
      body =
          '$emoji ${healthScore.toStringAsFixed(1)}/100 — $label. '
          'Tap to see your full score breakdown.';
    }

    await _plugin.zonedSchedule(
      _NId.eveningSummary,
      '📊 Today\'s Health Summary',
      body,
      _nextTimeIST(20, 0),
      _notifDetails(
        channel: _chReminder,
        chName: 'Daily Reminders',
        chDesc: 'Evening health summary at 8 PM',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        silent: true,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: _Payload.dashboard,
    );
    debugPrint('Evening summary scheduled 8:00 PM IST ✅');
  }

  // ─────────────────────────────────────────────────────────
  // 5. MEDICATION REMINDERS
  //
  // WHY separate from health notifications:
  //   Health reminders use _nextTimeIST which has a "demo hack"
  //   (fires in 5s if time has passed) — fine for single-fire notifs.
  //
  //   Medication uses matchDateTimeComponents: DateTimeComponents.time
  //   for daily repeats. If we used the demo hack:
  //     - User sets 8:00 AM reminder at 2:00 PM
  //     - Demo hack fires at 14:00:05 (now + 5s)
  //     - matchDateTimeComponents locks 14:00:05 as daily repeat time
  //     - Result: notification repeats at 2:00 PM every day ❌
  //
  //   _nextMedTimeIST always advances to the NEXT real occurrence:
  //     - If 8:00 AM hasn't happened today → schedule today 8:00 AM
  //     - If 8:00 AM already passed → schedule tomorrow 8:00 AM
  //   Then matchDateTimeComponents correctly repeats at 8:00 AM daily ✅
  // ─────────────────────────────────────────────────────────
  Future<void> scheduleMedicationReminders({
    required String medicationId,
    required String medicineName,
    required String dosage,
    required List<String> times,
    String foodRelation = 'After food',
  }) async {
    for (final timeStr in times) {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      // Stable unique ID: same medicine + time always gets same ID
      // so rescheduling replaces rather than duplicates
      final notifId = (medicationId + timeStr).hashCode.abs() % 100000;

      final fireTime = _nextMedTimeIST(hour, minute);

      await _plugin.zonedSchedule(
        notifId,
        '💊 Time for your medicine',
        '$medicineName ($dosage) · $foodRelation',
        fireTime,
        _notifDetails(
          channel: _chMed,
          chName: 'Medication Reminders',
          chDesc: 'Daily medication reminders',
          importance: Importance.max, // highest priority for meds
          priority: Priority.max,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // repeats daily
        payload: _Payload.medications,
      );

      debugPrint(
        'Medication reminder ✅  $medicineName at $timeStr '
        '(ID=$notifId, fires: $fireTime)',
      );
    }
  }

  // ── Cancel all reminders for a medication ─────────────────
  Future<void> cancelMedicationReminders({
    required String medicationId,
    required List<String> times,
  }) async {
    for (final time in times) {
      final notifId = (medicationId + time).hashCode.abs() % 100000;
      await _plugin.cancel(notifId);
      debugPrint('Cancelled medication reminder ID=$notifId');
    }
  }

  // ─────────────────────────────────────────────────────────
  // DEV: test notification fires in 10 s
  // ─────────────────────────────────────────────────────────
  Future<void> sendTestNotification() async {
    final fire = tz.TZDateTime.now(
      tz.getLocation(_tz),
    ).add(const Duration(seconds: 10));
    await _plugin.zonedSchedule(
      _NId.test,
      '🧪 Test — HealthAI',
      'Tap → opens Daily Check-in screen.',
      fire,
      _notifDetails(
        channel: _chReminder,
        chName: 'Daily Reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: _Payload.checkin,
    );
    debugPrint('Test notification fires in 10 s ✅');
  }

  Future<void> cancelAll() async => _plugin.cancelAll();

  // ─────────────────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────────────────

  static void _onTap(NotificationResponse r) => _route(r.payload);

  @pragma('vm:entry-point')
  static void _onTapBackground(NotificationResponse r) => _route(r.payload);

  static void _route(String? payload) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || payload == null) return;
    Navigator.of(ctx).pushNamed(payload);
  }

  NotificationDetails _notifDetails({
    required String channel,
    required String chName,
    String chDesc = '',
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
    bool silent = false,
  }) => NotificationDetails(
    android: AndroidNotificationDetails(
      channel,
      chName,
      channelDescription: chDesc,
      importance: importance,
      priority: priority,
      autoCancel: true,
      icon: '@mipmap/ic_launcher',
      playSound: !silent,
      enableVibration: !silent,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: !silent,
    ),
  );

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channel,
    required String chName,
    String chDesc = '',
    Importance importance = Importance.high,
    Priority priority = Priority.high,
    String payload = '',
    bool silent = false,
  }) => _plugin.show(
    id,
    title,
    body,
    _notifDetails(
      channel: channel,
      chName: chName,
      chDesc: chDesc,
      importance: importance,
      priority: priority,
      silent: silent,
    ),
    payload: payload,
  );

  // ── For health notifications (demo: fires in 5s if past) ──
  tz.TZDateTime _nextTimeIST(int hour, int minute) {
    final loc = tz.getLocation(_tz);
    final now = tz.TZDateTime.now(loc);
    var t = tz.TZDateTime(loc, now.year, now.month, now.day, hour, minute);
    if (t.isBefore(now)) {
      return now.add(const Duration(seconds: 5)); // demo convenience
    }
    return t;
  }

  // ── For medication reminders (ALWAYS correct daily repeat) ──
  //
  // RULE:
  //   • If the time today is still in the future → schedule TODAY
  //   • If the time today already passed → schedule TOMORROW
  //
  // WHY NOT now+5s: matchDateTimeComponents locks the fire time as the
  // daily repeat anchor. If we used now+5s, it repeats at the wrong time.
  //
  // TESTING TIP:
  //   To test within minutes, pick a time 3-5 min from now in the
  //   time picker. The notification will fire at that exact time today.
  //   If you pick a time that's already past, it fires tomorrow.
  tz.TZDateTime _nextMedTimeIST(int hour, int minute) {
    final loc = tz.getLocation(_tz);
    final now = tz.TZDateTime.now(loc);
    var t = tz.TZDateTime(loc, now.year, now.month, now.day, hour, minute);
    if (t.isBefore(now)) {
      // Time already passed today — schedule for tomorrow
      t = t.add(const Duration(days: 1));
      debugPrint(
        '_nextMedTimeIST: $hour:$minute already passed → scheduling tomorrow',
      );
    }
    return t;
  }

  String _firstSentence(String tip) {
    final i = tip.indexOf('. ');
    return i != -1 ? '${tip.substring(0, i)}.' : tip;
  }

  String _scoreEmoji(double s) {
    if (s >= 80) return '🏆';
    if (s >= 65) return '✅';
    if (s >= 50) return '📈';
    return '💪';
  }

  String _scoreLabel(double s) {
    if (s >= 80) return 'Excellent';
    if (s >= 65) return 'Good';
    if (s >= 50) return 'Fair';
    return 'Needs Work';
  }
}
