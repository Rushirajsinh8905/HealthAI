// ============================================================
// HEALTHAI — GROUP LEADERBOARD SCREEN
// Daily ranking: score desc, improvement as tie-breaker
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import 'group_requests_screen.dart';

class GroupLeaderboardScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String currentUserId;
  final bool isAdmin;

  const GroupLeaderboardScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.currentUserId,
    required this.isAdmin,
  });

  @override
  State<GroupLeaderboardScreen> createState() => _GroupLeaderboardScreenState();
}

class _GroupLeaderboardScreenState extends State<GroupLeaderboardScreen> {
  final _db = SupabaseService();
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;
  int? _myRank;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    final data = await _db.getGroupLeaderboard(widget.groupId);
    if (mounted) {
      // Sort: today's score desc, improvement desc as tie-breaker
      data.sort((a, b) {
        final scoreA = (a['today_score'] as num?)?.toDouble() ?? 0.0;
        final scoreB = (b['today_score'] as num?)?.toDouble() ?? 0.0;
        if (scoreB != scoreA) return scoreB.compareTo(scoreA);
        final impA = (a['improvement'] as num?)?.toDouble() ?? 0.0;
        final impB = (b['improvement'] as num?)?.toDouble() ?? 0.0;
        return impB.compareTo(impA);
      });

      // Find my rank
      int? rank;
      for (int i = 0; i < data.length; i++) {
        if (data[i]['user_id'].toString() == widget.currentUserId) {
          rank = i + 1;
          break;
        }
      }

      setState(() {
        _leaderboard = data;
        _myRank = rank;
        _isLoading = false;
      });
    }
  }

  String _rankEmoji(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#$rank';
    }
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return AppColors.textHint;
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.groupName, style: AppTextStyles.titleLarge),
            const Text(
              'Today\'s Leaderboard',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (widget.isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupRequestsScreen(
                        groupId: widget.groupId,
                        groupName: widget.groupName,
                      ),
                    ),
                  );
                  _loadLeaderboard();
                },
                icon: const Icon(Icons.how_to_reg_rounded, size: 16),
                label: const Text('Requests'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ),
          IconButton(
            onPressed: _loadLeaderboard,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // ── My Rank Banner (if in list) ─────────────
                  if (_myRank != null) _MyRankBanner(rank: _myRank!),
                  if (_myRank != null) const SizedBox(height: 20),

                  // ── Full Ranking ─────────────────────────────
                  if (_leaderboard.isNotEmpty) ...[
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
                        Text(
                          'Full Ranking',
                          style: AppTextStyles.titleLarge.copyWith(
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_leaderboard.length} members',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: _leaderboard.asMap().entries.map((entry) {
                          final rank = entry.key + 1;
                          final member = entry.value;
                          final isMe =
                              member['user_id'].toString() ==
                              widget.currentUserId;
                          final name =
                              (member['full_name'] as String?) ?? 'Unknown';
                          final score =
                              (member['today_score'] as num?)?.toDouble() ??
                              0.0;
                          final improvement =
                              (member['improvement'] as num?)?.toDouble() ??
                              0.0;
                          final hasScore = score > 0;

                          return Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                color: isMe
                                    ? AppColors.primary.withValues(alpha: 0.04)
                                    : Colors.transparent,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      // Rank
                                      SizedBox(
                                        width: 36,
                                        child: rank <= 3
                                            ? Text(
                                                _rankEmoji(rank),
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                ),
                                                textAlign: TextAlign.center,
                                              )
                                            : Text(
                                                '#$rank',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: _rankColor(rank),
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                      ),
                                      const SizedBox(width: 10),
                                      // Avatar
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? AppColors.primary.withValues(
                                                  alpha: 0.15,
                                                )
                                              : AppColors.surfaceVariant,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: isMe
                                              ? Border.all(
                                                  color: AppColors.primary,
                                                  width: 1.5,
                                                )
                                              : null,
                                        ),
                                        child: Center(
                                          child: Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: isMe
                                                  ? AppColors.primary
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Name
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  isMe ? '$name (You)' : name,
                                                  style: AppTextStyles
                                                      .labelLarge
                                                      .copyWith(
                                                        fontSize: 13,
                                                        color: isMe
                                                            ? AppColors.primary
                                                            : AppColors
                                                                  .textPrimary,
                                                      ),
                                                ),
                                              ],
                                            ),
                                            if (improvement != 0)
                                              Text(
                                                improvement > 0
                                                    ? '+${improvement.toStringAsFixed(1)} from yesterday'
                                                    : '${improvement.toStringAsFixed(1)} from yesterday',
                                                style: AppTextStyles.caption
                                                    .copyWith(
                                                      color: improvement > 0
                                                          ? AppColors.success
                                                          : AppColors.error,
                                                      fontSize: 11,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      // Score
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: hasScore
                                              ? (rank == 1
                                                    ? const Color(
                                                        0xFFFFD700,
                                                      ).withValues(alpha: 0.12)
                                                    : AppColors.primary
                                                          .withValues(
                                                            alpha: 0.08,
                                                          ))
                                              : AppColors.surfaceVariant,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          hasScore
                                              ? score.toStringAsFixed(1)
                                              : '--',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: hasScore
                                                ? (rank == 1
                                                      ? const Color(0xFFB8860B)
                                                      : AppColors.primary)
                                                : AppColors.textHint,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (entry.key < _leaderboard.length - 1)
                                const Divider(
                                  color: AppColors.divider,
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ] else
                    _EmptyLeaderboard(),

                  const SizedBox(height: 16),

                  // ── Footer note ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Rankings update after each daily check-in. '
                            'Sorted by today\'s score, with yesterday\'s improvement as tie-breaker.',
                            style: AppTextStyles.caption.copyWith(height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

// ── My Rank Banner ────────────────────────────────────────────
class _MyRankBanner extends StatelessWidget {
  final int rank;
  const _MyRankBanner({required this.rank});

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isTop3
            ? const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isTop3 ? null : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: isTop3 ? null : Border.all(color: AppColors.border),
        boxShadow: isTop3
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Text(
            rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '🏅',
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Rank Today',
                  style: TextStyle(
                    fontSize: 11,
                    color: isTop3 ? Colors.white70 : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  rank == 1
                      ? '1st Place 🔥'
                      : rank == 2
                      ? '2nd Place'
                      : rank == 3
                      ? '3rd Place'
                      : '#$rank in the group',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isTop3 ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (isTop3)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Top 3!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Empty Leaderboard ─────────────────────────────────────────
class _EmptyLeaderboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.leaderboard_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No check-ins today',
              style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Members need to complete today\'s\ncheck-in to appear on the leaderboard.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
