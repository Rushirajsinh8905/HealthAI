// ============================================================
// Health AI — CHAT SERVICE
// FastAPI (Gemini call) + Supabase (message persistence)
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_config.dart';

// URL is defined in app_config.dart — change it there for all services at once
const String _kBaseUrl = kApiBaseUrl;
// ============================================================
// CHAT MESSAGE MODEL
// ============================================================

class ChatMessage {
  final String id;
  final String userId;
  final String role; // "user" or "assistant"
  final String content;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.userId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  bool get isUser => role == 'user';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toHistoryItem() => {'role': role, 'content': content};
}

// ============================================================
// USER CONTEXT — passed to Gemini via FastAPI
// ============================================================

class ChatUserContext {
  final String userId;
  final String userName;
  final int age;
  final String gender;
  final String occupation;
  final String country;
  final double healthScore;
  final double sleepHours;
  final int steps;
  final double waterIntakeL;
  final double moodScore;
  final double stressLevel;
  final double exerciseMinutes;
  final String dietQuality;
  final double? weightKg;
  final double physicalScore;
  final double mentalScore;
  final double dietScore;
  final double riskScore;

  const ChatUserContext({
    required this.userId,
    required this.userName,
    this.age = 0,
    this.gender = '',
    this.occupation = '',
    this.country = '',
    this.healthScore = 0.0,
    this.sleepHours = 0.0,
    this.steps = 0,
    this.waterIntakeL = 0.0,
    this.moodScore = 5.0,
    this.stressLevel = 5.0,
    this.exerciseMinutes = 0.0,
    this.dietQuality = '',
    this.weightKg,
    this.physicalScore = 0.0,
    this.mentalScore = 0.0,
    this.dietScore = 0.0,
    this.riskScore = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'user_name': userName,
    'age': age,
    'gender': gender,
    'occupation': occupation,
    'country': country,
    'health_score': healthScore,
    'sleep_hours': sleepHours,
    'steps': steps,
    'water_intake_l': waterIntakeL,
    'mood_score': moodScore,
    'stress_level': stressLevel,
    'exercise_minutes': exerciseMinutes,
    'diet_quality': dietQuality,
    'weight_kg': weightKg,
    'physical_score': physicalScore,
    'mental_score': mentalScore,
    'diet_score': dietScore,
    'risk_score': riskScore,
  };
}

// ============================================================
// CHAT SERVICE
// ============================================================

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final _client = http.Client();
  final _supabase = Supabase.instance.client;

  // ── Load chat history from Supabase ──────────────────────
  Future<List<ChatMessage>> loadHistory(String userId) async {
    try {
      final authUid = _supabase.auth.currentUser?.id ?? userId;
      final response = await _supabase
          .from('chat_messages')
          .select()
          .eq('user_id', authUid)
          .order('created_at', ascending: true)
          .limit(100);

      return (response as List)
          .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('loadHistory error: $e');
      return [];
    }
  }

  // ── Send message → Gemini via FastAPI → save both to Supabase ──
  Future<ChatMessage?> sendMessage({
    required ChatUserContext context,
    required String message,
    required List<ChatMessage> history,
  }) async {
    final authUid = _supabase.auth.currentUser?.id ?? context.userId;

    // 1. Save user message to Supabase immediately (optimistic)
    final userMsg = await _saveMessage(
      userId: authUid,
      role: 'user',
      content: message,
    );
    if (userMsg == null) return null;

    // 2. Call FastAPI → Gemini
    try {
      final body = {
        ...context.toJson(),
        'message': message,
        'history': history.map((m) => m.toHistoryItem()).toList(),
      };

      final response = await _client
          .post(
            Uri.parse('$_kBaseUrl/chat/message'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = json['reply'] as String;

        // 3. Save AI response to Supabase
        final aiMsg = await _saveMessage(
          userId: authUid,
          role: 'assistant',
          content: reply,
        );
        return aiMsg;
      } else {
        debugPrint('Chat API error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('sendMessage error: $e');
      return null;
    }
  }

  // ── Save a single message to Supabase ────────────────────
  Future<ChatMessage?> _saveMessage({
    required String userId,
    required String role,
    required String content,
  }) async {
    try {
      final response = await _supabase
          .from('chat_messages')
          .insert({'user_id': userId, 'role': role, 'content': content})
          .select()
          .single();
      return ChatMessage.fromJson(response);
    } catch (e) {
      debugPrint('_saveMessage error: $e');
      return null;
    }
  }

  // ── Clear chat history for user ───────────────────────────
  Future<void> clearHistory(String userId) async {
    try {
      final authUid = _supabase.auth.currentUser?.id ?? userId;
      await _supabase.from('chat_messages').delete().eq('user_id', authUid);
    } catch (e) {
      debugPrint('clearHistory error: $e');
    }
  }
}
