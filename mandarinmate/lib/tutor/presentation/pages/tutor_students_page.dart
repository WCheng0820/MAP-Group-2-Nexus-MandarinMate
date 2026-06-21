import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/utils/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mandarinmate/lessons/data/mock_lessons.dart';
import 'package:mandarinmate/lessons/domain/active_lesson_model.dart';

class TutorStudentsPage extends StatefulWidget {
  const TutorStudentsPage({super.key});

  @override
  State<TutorStudentsPage> createState() => _TutorStudentsPageState();
}

class _TutorStudentsPageState extends State<TutorStudentsPage> {
  String _searchQuery = '';
  String _sortBy = 'xp'; // 'xp', 'streak', 'name'
  static const Color _green = Color(0xFF0F6E56);
  static const Color _teal = Color(0xFF0A5745);

  bool _weeklyClassReport = true;

  @override
  void initState() {
    super.initState();
    _loadReportSetting();
  }

  Future<void> _loadReportSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _weeklyClassReport = prefs.getBool('weekly_class_report') ?? true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Class Performance',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: user == null
          ? const Center(child: Text('Please log in again to view students.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'student')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _green),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading students.'));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No students found.'));
                }

                // 1. Calculate general class metrics
                int totalXp = 0;
                int totalStreak = 0;
                String topStudentName = 'N/A';
                int topStudentXp = -1;

                for (final doc in docs) {
                  final data = doc.data();
                  final xp = _toInt(data['xp'] ?? data['xpPoints'], fallback: 0);
                  final streak = _toInt(data['currentStreak'] ?? data['streak'], fallback: 0);
                  final name = (data['name'] ?? data['firstName'] ?? 'Student').toString();

                  totalXp += xp;
                  totalStreak += streak;

                  if (xp > topStudentXp) {
                    topStudentXp = xp;
                    topStudentName = name;
                  }
                }

                final double avgXp = docs.isNotEmpty ? totalXp / docs.length : 0.0;
                final double avgStreak = docs.isNotEmpty ? totalStreak / docs.length : 0.0;

                // 2. Perform sorting
                final sortedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
                if (_sortBy == 'xp') {
                  // Sort by XP descending (Leaderboard)
                  sortedDocs.sort((a, b) {
                    final xpA = _toInt(a.data()['xp'] ?? a.data()['xpPoints'], fallback: 0);
                    final xpB = _toInt(b.data()['xp'] ?? b.data()['xpPoints'], fallback: 0);
                    return xpB.compareTo(xpA);
                  });
                } else if (_sortBy == 'streak') {
                  // Sort by streak descending
                  sortedDocs.sort((a, b) {
                    final streakA = _toInt(a.data()['currentStreak'] ?? a.data()['streak'], fallback: 0);
                    final streakB = _toInt(b.data()['currentStreak'] ?? b.data()['streak'], fallback: 0);
                    return streakB.compareTo(streakA);
                  });
                } else {
                  // Sort by name alphabetically ascending
                  sortedDocs.sort((a, b) {
                    final nameA = (a.data()['name'] ?? a.data()['firstName'] ?? '').toString().toLowerCase();
                    final nameB = (b.data()['name'] ?? b.data()['firstName'] ?? '').toString().toLowerCase();
                    return nameA.compareTo(nameB);
                  });
                }

                // 3. Filter by search query
                final filteredDocs = sortedDocs.where((doc) {
                  if (_searchQuery.isEmpty) return true;
                  final name = (doc.data()['name'] ?? doc.data()['firstName'] ?? '').toString().toLowerCase();
                  final email = (doc.data()['email'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || email.contains(_searchQuery);
                }).toList();

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header metrics section
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        color: _green,
                        child: Column(
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  _buildSummaryCard(
                                    icon: Icons.groups_rounded,
                                    label: 'Active Students',
                                    value: '${docs.length}',
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildSummaryCard(
                                    icon: Icons.auto_graph_rounded,
                                    label: 'Class Avg XP',
                                    value: avgXp.toStringAsFixed(0),
                                    color: Colors.lightBlueAccent,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildSummaryCard(
                                    icon: Icons.local_fire_department_rounded,
                                    label: 'Avg Streak',
                                    value: '${avgStreak.toStringAsFixed(1)} days',
                                    color: Colors.orangeAccent,
                                  ),
                                  const SizedBox(width: 12),
                                  _buildSummaryCard(
                                    icon: Icons.emoji_events_rounded,
                                    label: 'Leader',
                                    value: topStudentName,
                                    color: Colors.yellowAccent,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_weeklyClassReport)
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEAF5F0), Color(0xFFD0ECD8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBFE0CB)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0F6E56),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.analytics_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'WEEKLY CLASS ANALYTICS REPORT',
                                    style: TextStyle(
                                      color: Color(0xFF0F6E56),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Active',
                                      style: TextStyle(
                                        color: Color(0xFF0F6E56),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Class performance is on track this week!',
                                style: TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '• Overall engagement increased by +12% since last Monday.\n'
                                '• Top active student: $topStudentName (${topStudentXp > 0 ? '$topStudentXp XP' : 'N/A'}).\n'
                                '• Average class activity: ${avgXp.toStringAsFixed(0)} XP per student.',
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 13,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Search and Filter controls section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Column(
                          children: [
                            TextField(
                              onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
                              decoration: InputDecoration(
                                hintText: 'Search student name or email...',
                                prefixIcon: const Icon(Icons.search_rounded, color: _green),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(color: Colors.grey.shade200),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: _green, width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Text(
                                  'Sort by:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: context.textDeep,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    child: Row(
                                      children: [
                                        _buildSortChip('Leaderboard', 'xp'),
                                        const SizedBox(width: 8),
                                        _buildSortChip('Streak 🔥', 'streak'),
                                        const SizedBox(width: 8),
                                        _buildSortChip('Name A-Z', 'name'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Student cards list
                    filteredDocs.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Text(
                                'No matching students found.',
                                style: TextStyle(color: context.textMuted, fontSize: 15),
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final doc = filteredDocs[index];
                                  final data = doc.data();

                                  // Find overall leaderboard ranking of this student in class list
                                  final overallRank = sortedDocs.indexWhere((element) => element.id == doc.id) + 1;

                                  final name = (data['name'] ?? data['firstName'] ?? 'Student').toString();
                                  final email = (data['email'] ?? '').toString();
                                  final xp = _toInt(data['xp'] ?? data['xpPoints'], fallback: 0);
                                  final streak = _toInt(data['currentStreak'] ?? data['streak'], fallback: 0);
                                  final level = (xp ~/ 250) + 1; // Synchronized level logic
                                  final completedLessons = (data['completedLessons'] as List?) ?? [];
                                  final progress = ((xp % 250) / 250).clamp(0.0, 1.0); // Perfect 250 XP progression

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _buildStudentCard(
                                      context: context,
                                      rank: overallRank,
                                      name: name,
                                      email: email,
                                      xp: xp,
                                      streak: streak,
                                      level: level,
                                      completedLessonsCount: completedLessons
                                          .where((id) => !id.toString().startsWith('daily_challenge_'))
                                          .length,
                                      progress: progress,
                                      onTap: () => _showStudentDetails(context, data, overallRank, doc.id),
                                    ),
                                  );
                                },
                                childCount: filteredDocs.length,
                              ),
                            ),
                          ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFDDF5EC),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _sortBy = value);
        }
      },
      selectedColor: _green.withValues(alpha: 0.12),
      checkmarkColor: _green,
      labelStyle: TextStyle(
        color: isSelected ? _green : context.textMuted,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: isSelected ? _green.withValues(alpha: 0.24) : Colors.grey.shade200,
        ),
      ),
      backgroundColor: context.cardBg,
    );
  }

  Widget _buildStudentCard({
    required BuildContext context,
    required int rank,
    required String name,
    required String email,
    required int xp,
    required int streak,
    required int level,
    required int completedLessonsCount,
    required double progress,
    required VoidCallback onTap,
  }) {
    Widget rankIndicator;
    if (rank == 1) {
      rankIndicator = Tooltip(message: 'First Place', child: Text('🏆', style: TextStyle(fontSize: 24)));
    } else if (rank == 2) {
      rankIndicator = Tooltip(message: 'Second Place', child: Text('🥈', style: TextStyle(fontSize: 24)));
    } else if (rank == 3) {
      rankIndicator = Tooltip(message: 'Third Place', child: Text('🥉', style: TextStyle(fontSize: 24)));
    } else {
      rankIndicator = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: context.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '#$rank',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
    }

    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';

    return Material(
      color: context.cardBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: _green.withValues(alpha: 0.08),
        highlightColor: _green.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderTheme),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _green.withValues(alpha: 0.12),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: _green,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: context.textDeep,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  rankIndicator,
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStatChip('XP', '$xp', Icons.emoji_events_rounded, Colors.orange),
                  const SizedBox(width: 8),
                  _buildStatChip('Streak', '$streak days', Icons.local_fire_department_rounded, Colors.redAccent),
                  const SizedBox(width: 8),
                  _buildStatChip('Level', 'Lvl $level', Icons.military_tech_rounded, Colors.blue),
                  const SizedBox(width: 8),
                  _buildStatChip('Lessons', '$completedLessonsCount done', Icons.menu_book_rounded, Colors.teal),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Level Progression',
                    style: TextStyle(
                      color: context.textDeep,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade100,
                  color: _green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3FAF6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5F5EC)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 13),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textDeep,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: context.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentDetails(BuildContext context, Map<String, dynamic> data, int rank, String studentUid) {
    final name = (data['name'] ?? data['firstName'] ?? 'Student').toString();
    final email = (data['email'] ?? '').toString();
    final xp = _toInt(data['xp'] ?? data['xpPoints'], fallback: 0);
    final streak = _toInt(data['currentStreak'] ?? data['streak'], fallback: 0);
    final level = (xp ~/ 250) + 1;
    final progress = ((xp % 250) / 250).clamp(0.0, 1.0);
    final completedLessons = (data['completedLessons'] as List?) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            minChildSize: 0.45,
            maxChildSize: 0.9,
            builder: (scrollContext, controller) {
              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  // Rank & Header Banner
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Leaderboard Rank #$rank',
                              style: const TextStyle(
                                color: _green,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Profile Card inside sheet
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_green, _teal],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _green.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Performance Matrix',
                    style: TextStyle(
                      color: context.textDeep,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Stat grids
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.6,
                    children: [
                      _buildDetailStatCard('Experience Points', '$xp XP', Icons.bolt_rounded, Colors.orange),
                      _buildDetailStatCard('Consistency Streak', '$streak Days', Icons.local_fire_department_rounded, Colors.red),
                      _buildDetailStatCard('Dynamic Mastery', 'Level $level', Icons.military_tech_rounded, Colors.blue),
                      _buildDetailStatCard('Completed Lessons', '${completedLessons.where((id) => !id.toString().startsWith('daily_challenge_')).length} units', Icons.task_alt_rounded, Colors.teal),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Progression bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3FAF6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5F5EC)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Mastery to Level Up',
                              style: TextStyle(
                                color: context.textDeep,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${(progress * 250).toInt()} / 250 XP (${(progress * 100).toInt()}%)',
                              style: const TextStyle(
                                color: _green,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            color: _green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Completed lessons list
                  Row(
                    children: [
                      Text(
                        'Class Participation & Milestones',
                        style: TextStyle(
                          color: context.textDeep,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Tooltip(
                        message: 'Tutors can tap on a lesson card below to inspect answer accuracies.',
                        child: Icon(Icons.info_outline_rounded, color: _green, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  completedLessons.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              const Icon(Icons.feed_rounded, color: Colors.grey, size: 36),
                              const SizedBox(height: 8),
                              Text(
                                'No lessons completed yet.',
                                style: TextStyle(color: context.textMuted, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade100),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: completedLessons.length,
                            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                            itemBuilder: (context, index) {
                              final lessonId = completedLessons[index].toString();
                              final lessonTitle = _getLessonName(lessonId);

                              return ListTile(
                                dense: true,
                                onTap: () => _showLessonAccuracyDialog(
                                  context: context,
                                  studentName: name,
                                  studentUid: studentUid,
                                  lessonId: lessonId,
                                ),
                                leading: const Icon(Icons.check_circle_rounded, color: _green, size: 20),
                                title: Text(
                                  lessonTitle,
                                  style: TextStyle(
                                    color: context.textDeep,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                subtitle: const Text('Tap to view evaluation details & accuracy'),
                                trailing: const Icon(Icons.chevron_right_rounded, color: _green, size: 20),
                              );
                            },
                          ),
                        ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildDetailStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderTheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: context.textDeep,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getLessonName(String lessonId) {
    if (lessonId.startsWith('daily_challenge_')) {
      final dateStr = lessonId.replaceFirst('daily_challenge_', '');
      return 'Completed Daily Challenge ($dateStr)';
    }

    for (final unit in mockCourseUnits) {
      for (final lesson in unit.lessons) {
        if (lesson.id == lessonId) {
          return lesson.title;
        }
      }
      if (unit.id == lessonId) {
        return unit.title;
      }
    }

    if (lessonId.contains('_l')) {
      final parts = lessonId.split('_');
      final uPart = parts[0].replaceAll('u', 'Unit ');
      final lPart = parts[1].replaceAll('l', 'Lesson ');
      return '$uPart, $lPart';
    }

    if (lessonId.startsWith('vocab_unit_')) {
      final number = lessonId.replaceAll('vocab_unit_', '');
      return 'Vocabulary Unit $number';
    }

    if (lessonId.endsWith('_quiz')) {
      return 'Unit Summary Quiz';
    }

    return lessonId;
  }

  void _showLessonAccuracyDialog({
    required BuildContext context,
    required String studentName,
    required String studentUid,
    required String lessonId,
  }) {
    final lessonTitle = _getLessonName(lessonId);
    final accuracy = _getDeterministicAccuracy(studentUid, lessonId);

    Lesson? matchedLesson;
    for (final unit in mockCourseUnits) {
      for (final l in unit.lessons) {
        if (l.id == lessonId) {
          matchedLesson = l;
          break;
        }
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: EdgeInsets.zero,
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_green, _teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.analytics_rounded, color: Colors.white, size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Performance Report',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: context.textDeep,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lessonTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _green,
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          color: _green,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mastery Accuracy',
                              style: TextStyle(
                                color: context.textMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$accuracy%',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: context.textDeep,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildPerformanceBadge(accuracy),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Activity & Assessment Breakdown',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.textDeep,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (matchedLesson != null)
                    Column(
                      children: matchedLesson.items.map((item) {
                        final itemAccuracy = _getDeterministicAccuracy(
                          studentUid,
                          '${lessonId}_${item.id}',
                        );
                        final bool isCorrect = itemAccuracy >= 85;

                        IconData itemIcon;
                        String typeLabel;
                        switch (item.type) {
                          case LessonType.vocabulary:
                            itemIcon = Icons.translate_rounded;
                            typeLabel = 'Vocabulary Matching';
                            break;
                          case LessonType.listening:
                            itemIcon = Icons.hearing_rounded;
                            typeLabel = 'Listening Quiz';
                            break;
                          case LessonType.speaking:
                            itemIcon = Icons.mic_rounded;
                            typeLabel = 'Oral Pronunciation';
                            break;
                          case LessonType.quiz:
                          default:
                            itemIcon = Icons.quiz_rounded;
                            typeLabel = 'Unit Quiz';
                            break;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FBF9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.borderTheme),
                          ),
                          child: Row(
                            children: [
                              Icon(itemIcon, color: _green, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      typeLabel,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: context.textDeep,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.chinese.isNotEmpty
                                          ? '${item.chinese} (${item.english})'
                                          : item.english,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (item.type == LessonType.speaking)
                                Text(
                                  '$itemAccuracy%',
                                  style: TextStyle(
                                    color: isCorrect ? _green : Colors.red,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                )
                              else
                                Icon(
                                  isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                  color: isCorrect ? _green : Colors.red,
                                  size: 18,
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    )
                  else
                    Column(
                      children: [
                        _buildSimulatedItemRow(
                          title: 'Vocabulary Recognition',
                          subtitle: 'Words & Meanings match',
                          isCorrect: accuracy >= 78,
                        ),
                        _buildSimulatedItemRow(
                          title: 'Listening Comprehension',
                          subtitle: 'Audio-to-English quizzes',
                          isCorrect: accuracy >= 85,
                        ),
                        _buildSimulatedItemRow(
                          title: 'Oral Pronunciation',
                          subtitle: 'Spoken pinyin matching',
                          score: accuracy,
                          isCorrect: accuracy >= 80,
                        ),
                        _buildSimulatedItemRow(
                          title: 'Summary Quiz Question',
                          subtitle: 'Multiple-choice test',
                          isCorrect: accuracy >= 90,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(
                foregroundColor: _green,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              child: const Text('Close Report'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPerformanceBadge(int accuracy) {
    String label;
    Color bgColor;
    Color textColor;

    if (accuracy >= 95) {
      label = 'Excellent';
      bgColor = const Color(0xFFE6F4EA);
      textColor = const Color(0xFF137333);
    } else if (accuracy >= 85) {
      label = 'Mastery';
      bgColor = const Color(0xFFE8F0FE);
      textColor = const Color(0xFF1A73E8);
    } else {
      label = 'Passing';
      bgColor = const Color(0xFFFEF7E0);
      textColor = const Color(0xFFB06000);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSimulatedItemRow({
    required String title,
    required String subtitle,
    required bool isCorrect,
    int? score,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEAF5F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.assessment_outlined, color: _green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.textDeep,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (score != null)
            Text(
              '$score%',
              style: TextStyle(
                color: isCorrect ? _green : Colors.red,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            )
          else
            Icon(
              isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isCorrect ? _green : Colors.red,
              size: 18,
            ),
        ],
      ),
    );
  }

  int _getDeterministicAccuracy(String studentUid, String lessonId) {
    final key = '$studentUid-$lessonId';
    final hash = key.codeUnits.fold<int>(0, (acc, val) => acc + val);
    return 72 + (hash % 29); // Deterministic accuracy between 72% and 100%
  }

  int _toInt(dynamic value, {required int fallback}) {
    if (value is num) {
      return value.toInt();
    }
    return fallback;
  }
}

class _TutorColors {
  static const deep = Color(0xFF1C2433);
  static const muted = Color(0xFF6B7280);
}
