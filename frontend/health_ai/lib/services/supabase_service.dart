// ============================================================
// HEALTHAI — SUPABASE SERVICE (COMPLETE FIXED VERSION)
// Root fix: profiles.auth_id always = auth.uid()
// group_members.user_id → profiles.auth_id (FK works for joins)
// ============================================================
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // ── Singleton ─────────────────────────────────────────────
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  // ── Active user email (set at login/signup) ───────────────
  String? _activeEmail;

  void setActiveUser(String email) {
    _activeEmail = email;
  }

  // ──────────────────────────────────────────────────────────
  // GET PROFILE BY EMAIL
  // ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getDemoProfile() async {
    final email = (_activeEmail != null && _activeEmail!.isNotEmpty)
        ? _activeEmail!
        : _client.auth.currentUser?.email;

    if (email == null || email.isEmpty) return null;

    if (_activeEmail == null || _activeEmail!.isEmpty) {
      _activeEmail = email;
    }

    try {
      final response = await _client
          .from('profiles')
          .select(
            'id, auth_id, full_name, email, age, height_cm, gender, occupation, '
            'country, smoking_habit, alcohol_consumption, '
            'diabetes, mental_health_condition, under_treatment, '
            'current_diseases, past_diseases, created_at',
          )
          .eq('email', email)
          .single();
      return response;
    } catch (e) {
      debugPrint('getDemoProfile error: $e');
      return null;
    }
  }

  // ── Quick getter for user id ───────────────────────────────
  // Returns auth_id (= auth.uid()) — this is what all tables use
  Future<String?> getDemoUserId() async {
    // Always prefer the real auth UID
    final authUid = _client.auth.currentUser?.id;
    if (authUid != null) return authUid;
    final profile = await getDemoProfile();
    return profile?['auth_id']?.toString() ?? profile?['id']?.toString();
  }

  // ──────────────────────────────────────────────────────────
  // SAVE PROFILE (Onboarding)
  // FIX: always set auth_id = auth.uid() so FK joins work
  // ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> saveProfile({
    required String fullName,
    required String email,
    required int age,
    required double heightCm,
    required String gender,
    required String occupation,
    required String country,
    required String smokingHabit,
    required String alcoholConsumption,
    required String diabetes,
    required String mentalHealthCondition,
    required String underTreatment,
    String currentDiseases = '—',
    String pastDiseases = '—',
  }) async {
    try {
      // ── CRITICAL: always use real auth UID ────────────────
      final authUid = _client.auth.currentUser?.id;

      final response = await _client
          .from('profiles')
          .upsert({
            'auth_id': authUid, // ← syncs FK for all group queries
            'full_name': fullName,
            'email': email,
            'age': age,
            'height_cm': heightCm,
            'gender': gender,
            'occupation': occupation,
            'country': country,
            'smoking_habit': smokingHabit,
            'alcohol_consumption': alcoholConsumption,
            'diabetes': diabetes,
            'mental_health_condition': mentalHealthCondition,
            'under_treatment': underTreatment,
            'current_diseases': currentDiseases,
            'past_diseases': pastDiseases,
          }, onConflict: 'email')
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('saveProfile error: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────
  // SAVE DAILY LOG + DOMAIN SCORES (Check-in)
  // user_id = auth.uid() — consistent with all other tables
  // ──────────────────────────────────────────────────────────
  Future<bool> saveDailyLog({
    required String userId,
    required Map<String, dynamic> log,
    required Map<String, double> scores,
  }) async {
    try {
      // Always use real auth UID for consistency
      final authUid = _client.auth.currentUser?.id ?? userId;
      debugPrint('saveDailyLog → userId=$authUid  date=${log['date']}');
      await _client.from('daily_logs').upsert({
        'user_id': authUid,
        'date': log['date'],
        'sleep_hours': log['Sleep_Hours'],
        'steps': log['Steps'],
        'exercise_minutes': log['Exercise_Minutes'],
        'water_intake_l': log['Water_Intake_L'],
        'mood_score': log['Mood_Score'],
        'stress_level': log['Stress_Level'],
        'social_media_usage': log['Social_Media_Usage'],
        'final_calories': log['final_calories'],
        'final_protein': log['final_protein'],
        'final_carbs': log['final_carbs'],
        'final_fat': log['final_fat'],
        'diet_quality': log['Diet_Quality'],
        'weight_kg': log['Weight_kg'],
        'physical_activity_hours': log['Physical_Activity_Hours'],
        'active_time_hours': log['active_time_hours'],
        'sedentary_time_hours': log['sedentary_time_hours'],
        'posture_score': log['posture_score'],
        'physical_score': scores['physical_score'],
        'mental_score': scores['mental_score'],
        'diet_score': scores['diet_score'],
        'risk_score': scores['risk_score'],
        'chronic_score': scores['chronic_score'],
        'health_score': scores['health_score'],
      }, onConflict: 'user_id,date');
      debugPrint('saveDailyLog ✅ saved successfully');
      return true;
    } catch (e) {
      debugPrint('saveDailyLog ❌ error: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────
  // GET LATEST DAILY LOG (Dashboard)
  // ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getLatestDailyLog(String userId) async {
    try {
      // Always use real auth UID
      final authUid = _client.auth.currentUser?.id ?? userId;
      debugPrint('getLatestDailyLog → querying for userId=$authUid');
      final response = await _client
          .from('daily_logs')
          .select(
            'date, sleep_hours, steps, water_intake_l, weight_kg, '
            'exercise_minutes, mood_score, stress_level, social_media_usage, '
            'final_calories, final_protein, final_carbs, final_fat, '
            'heart_rate_avg, sedentary_time_hours, posture_score, diet_quality, '
            'health_score, physical_score, mental_score, '
            'diet_score, risk_score, chronic_score',
          )
          .eq('user_id', authUid)
          .order('date', ascending: false)
          .limit(1)
          .maybeSingle();
      debugPrint(
        'getLatestDailyLog → ${response == null ? "❌ null" : "✅ found date=${response['date']}"}',
      );
      return response;
    } catch (e) {
      debugPrint('getLatestDailyLog ❌ error: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────
  // GET ALL MEDICATIONS FOR USER
  // ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMedications(String userId) async {
    try {
      final authUid = _client.auth.currentUser?.id ?? userId;
      final response = await _client
          .from('medications')
          .select()
          .eq('user_id', authUid)
          .eq('is_active', true)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('getMedications error: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────
  // ADD NEW MEDICATION
  // ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> addMedication({
    required String userId,
    required String name,
    required String dosage,
    required String frequency,
    required List<String> times,
    required String foodRelation,
    required String startDate,
    required int durationDays,
    required bool reminderEnabled,
    String notes = '',
  }) async {
    try {
      final authUid = _client.auth.currentUser?.id ?? userId;
      final response = await _client
          .from('medications')
          .insert({
            'user_id': authUid,
            'name': name,
            'dosage': dosage,
            'frequency': frequency,
            'times': times,
            'food_relation': foodRelation,
            'start_date': startDate,
            'duration_days': durationDays,
            'reminder_enabled': reminderEnabled,
            'notes': notes,
            'is_active': true,
          })
          .select()
          .single();
      debugPrint('addMedication ✅ saved: $name');
      return response;
    } catch (e) {
      debugPrint('addMedication error: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────
  // SOFT DELETE MEDICATION
  // ──────────────────────────────────────────────────────────
  Future<bool> deleteMedication(String medicationId) async {
    try {
      await _client
          .from('medications')
          .update({'is_active': false})
          .eq('id', medicationId);
      return true;
    } catch (e) {
      debugPrint('deleteMedication error: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────
  // GET WHAT-IF RECOMMENDATIONS
  // ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getLatestWhatIf(String userId) async {
    try {
      final authUid = _client.auth.currentUser?.id ?? userId;
      final response = await _client
          .from('what_if_results')
          .select('baseline_score, top_3_features, best_scenario')
          .eq('user_id', authUid)
          .order('date', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      return null;
    }
  }

  // ── Update health score after TFT prediction ─────────────
  Future<void> updateHealthScore({
    required String userId,
    required double healthScore,
  }) async {
    try {
      final authUid = _client.auth.currentUser?.id ?? userId;
      final today = DateTime.now().toIso8601String().split('T')[0];
      await _client
          .from('daily_logs')
          .update({'health_score': healthScore})
          .eq('user_id', authUid)
          .eq('date', today);
    } catch (e) {
      debugPrint('updateHealthScore error: $e');
    }
  }

  // ============================================================
  // GROUPS METHODS
  // ============================================================

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
      6,
      (i) => chars[(rand >> (i * 5)) % chars.length],
    ).join();
  }

  // ──────────────────────────────────────────────────────────
  // CREATE GROUP
  // Uses auth.uid() directly — no profile ID confusion
  // ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> createGroup({
    required String adminId,
    required String name,
    required String description,
    required int maxMembers,
  }) async {
    try {
      final authUid = _client.auth.currentUser?.id;
      if (authUid == null) {
        debugPrint('createGroup error: No authenticated user');
        return null;
      }

      final inviteCode = _generateCode();

      final group = await _client
          .from('groups')
          .insert({
            'name': name,
            'description': description,
            'admin_id': authUid,
            'max_members': maxMembers,
            'invite_code': inviteCode,
          })
          .select()
          .single();

      await _client.from('group_members').insert({
        'group_id': group['id'],
        'user_id': authUid,
        'status': 'approved',
      });

      debugPrint('createGroup ✅ created: $name (code: $inviteCode)');
      return group;
    } catch (e) {
      debugPrint('createGroup error: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────
  // GET MY GROUPS
  // ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMyGroups(String userId) async {
    try {
      final authUid = _client.auth.currentUser?.id ?? userId;

      final response = await _client
          .from('group_members')
          .select(
            'status, groups(id, name, description, admin_id, invite_code)',
          )
          .eq('user_id', authUid)
          .eq('status', 'approved');

      final List<Map<String, dynamic>> result = [];
      for (final row in response) {
        final g = Map<String, dynamic>.from(row['groups'] as Map);
        final countResp = await _client
            .from('group_members')
            .select('id')
            .eq('group_id', g['id'])
            .eq('status', 'approved');
        result.add({
          ...g,
          'is_admin': g['admin_id'].toString() == authUid,
          'member_count': (countResp as List).length,
        });
      }
      return result;
    } catch (e) {
      debugPrint('getMyGroups error: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────
  // REQUEST TO JOIN GROUP BY INVITE CODE
  // ──────────────────────────────────────────────────────────
  Future<String> requestToJoinGroup({
    required String inviteCode,
    required String userId,
  }) async {
    try {
      final authUid = _client.auth.currentUser?.id;
      if (authUid == null) return 'error';

      final groups = await _client
          .from('groups')
          .select('id')
          .eq('invite_code', inviteCode.toUpperCase().trim());

      if ((groups as List).isEmpty) return 'not_found';
      final groupId = groups.first['id'];

      final existing = await _client
          .from('group_members')
          .select('status')
          .eq('group_id', groupId)
          .eq('user_id', authUid);

      if ((existing as List).isNotEmpty) {
        return existing.first['status'] == 'approved'
            ? 'already_member'
            : 'pending';
      }

      // Check if they're the admin (already added at creation)
      final isAdmin = await _client
          .from('groups')
          .select('id')
          .eq('id', groupId)
          .eq('admin_id', authUid);

      if ((isAdmin as List).isNotEmpty) return 'already_member';

      await _client.from('group_members').insert({
        'group_id': groupId,
        'user_id': authUid,
        'status': 'pending',
      });

      debugPrint('requestToJoinGroup ✅ request sent');
      return 'success';
    } catch (e) {
      debugPrint('requestToJoinGroup error: $e');
      return 'error';
    }
  }

  // ──────────────────────────────────────────────────────────
  // GET PENDING REQUESTS (admin only)
  // FIX: join via profiles.auth_id — this now works with FK
  // ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getPendingRequests(String groupId) async {
    try {
      // After Step 2 of SQL fix, this join works because
      // group_members.user_id → profiles.auth_id FK exists
      final response = await _client
          .from('group_members')
          .select(
            'user_id, profiles!group_members_user_id_fkey(full_name, email)',
          )
          .eq('group_id', groupId)
          .eq('status', 'pending');
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('getPendingRequests error: $e');
      // Fallback: fetch names separately if join still fails
      return await _getPendingRequestsFallback(groupId);
    }
  }

  // Fallback if FK join not yet applied
  Future<List<Map<String, dynamic>>> _getPendingRequestsFallback(
    String groupId,
  ) async {
    try {
      final members = await _client
          .from('group_members')
          .select('user_id')
          .eq('group_id', groupId)
          .eq('status', 'pending');

      final List<Map<String, dynamic>> result = [];
      for (final m in (members as List)) {
        final uid = m['user_id'].toString();
        final profile = await _client
            .from('profiles')
            .select('full_name, email')
            .eq('auth_id', uid)
            .maybeSingle();
        result.add({
          'user_id': uid,
          'profiles': {
            'full_name': profile?['full_name'] ?? 'Unknown',
            'email': profile?['email'] ?? '',
          },
        });
      }
      return result;
    } catch (e) {
      debugPrint('_getPendingRequestsFallback error: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────
  // APPROVE OR REJECT JOIN REQUEST
  // ──────────────────────────────────────────────────────────
  Future<void> handleJoinRequest({
    required String groupId,
    required String userId,
    required bool approve,
  }) async {
    try {
      if (approve) {
        await _client
            .from('group_members')
            .update({'status': 'approved'})
            .eq('group_id', groupId)
            .eq('user_id', userId);
      } else {
        await _client
            .from('group_members')
            .delete()
            .eq('group_id', groupId)
            .eq('user_id', userId);
      }
      debugPrint('handleJoinRequest ✅ ${approve ? "approved" : "rejected"}');
    } catch (e) {
      debugPrint('handleJoinRequest error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  // GET GROUP LEADERBOARD
  // Optimised: single query per member using auth UID
  // ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getGroupLeaderboard(String groupId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .split('T')[0];

      // Get approved members with names via FK join
      List members = [];
      try {
        members = await _client
            .from('group_members')
            .select('user_id, profiles!group_members_user_id_fkey(full_name)')
            .eq('group_id', groupId)
            .eq('status', 'approved');
      } catch (_) {
        // Fallback: separate query
        members = await _client
            .from('group_members')
            .select('user_id')
            .eq('group_id', groupId)
            .eq('status', 'approved');
      }

      final List<Map<String, dynamic>> result = [];

      for (final m in members) {
        final uid = m['user_id'].toString();

        // Get name — from join or separate query
        String fullName = 'Member';
        if (m['profiles'] != null) {
          fullName = (m['profiles']?['full_name'] as String?) ?? 'Member';
        } else {
          // Fallback name lookup
          final p = await _client
              .from('profiles')
              .select('full_name')
              .eq('auth_id', uid)
              .maybeSingle();
          fullName = (p?['full_name'] as String?) ?? 'Member';
        }

        // Today's score
        final todayLog = await _client
            .from('daily_logs')
            .select('health_score')
            .eq('user_id', uid)
            .eq('date', today)
            .maybeSingle();

        // Yesterday's score
        final yestLog = await _client
            .from('daily_logs')
            .select('health_score')
            .eq('user_id', uid)
            .eq('date', yesterday)
            .maybeSingle();

        final todayScore =
            (todayLog?['health_score'] as num?)?.toDouble() ?? 0.0;
        final yestScore = (yestLog?['health_score'] as num?)?.toDouble() ?? 0.0;
        final improvement = yestScore > 0 ? todayScore - yestScore : 0.0;

        result.add({
          'user_id': uid,
          'full_name': fullName,
          'today_score': todayScore,
          'yesterday_score': yestScore,
          'improvement': improvement,
        });
      }

      // Sort: score desc, improvement desc
      result.sort((a, b) {
        final scoreComp = (b['today_score'] as double).compareTo(
          a['today_score'] as double,
        );
        if (scoreComp != 0) return scoreComp;
        return (b['improvement'] as double).compareTo(
          a['improvement'] as double,
        );
      });

      return result;
    } catch (e) {
      debugPrint('getGroupLeaderboard error: $e');
      return [];
    }
  }
}
