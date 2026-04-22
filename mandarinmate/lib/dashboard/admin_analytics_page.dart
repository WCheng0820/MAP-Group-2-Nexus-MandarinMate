import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAnalyticsPage extends StatelessWidget {
  const AdminAnalyticsPage({super.key});

  static const Color _primary = Color(0xFF6C3BFF);
  static const Color _surface = Color(0xFFF6F3FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('Admin Analytics'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, usersSnapshot) {
          if (usersSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }
          if (usersSnapshot.hasError) {
            return const Center(child: Text('Failed to load analytics.'));
          }

          final users = usersSnapshot.data?.docs ?? const [];
          final students = users
              .where(
                (u) =>
                    (u.data()['role'] ?? 'student').toString().toLowerCase() ==
                    'student',
              )
              .toList();
          final tutors = users
              .where(
                (u) =>
                    (u.data()['role'] ?? '').toString().toLowerCase() ==
                    'tutor',
              )
              .length;
          final admins = users
              .where(
                (u) =>
                    (u.data()['role'] ?? '').toString().toLowerCase() ==
                    'admin',
              )
              .length;

          int totalStudentXp = 0;
          for (final s in students) {
            totalStudentXp += _extractXp(s.data());
          }
          final avgXp = students.isEmpty
              ? 0.0
              : totalStudentXp / students.length;

          final sortedStudents = [...students]
            ..sort(
              (a, b) => _extractXp(b.data()).compareTo(_extractXp(a.data())),
            );

          final topStudent = sortedStudents.isEmpty
              ? null
              : sortedStudents.first;
          final top5 = sortedStudents.take(5).toList();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('lessons')
                .snapshots(),
            builder: (context, lessonsSnapshot) {
              final totalLessons = lessonsSnapshot.data?.docs.length ?? 0;

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('announcements')
                    .snapshots(),
                builder: (context, announcementsSnapshot) {
                  final totalAnnouncements =
                      announcementsSnapshot.data?.docs.length ?? 0;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _StatGrid(
                        items: [
                          _StatData('Total Users', users.length.toString()),
                          _StatData('Students', students.length.toString()),
                          _StatData('Tutors', tutors.toString()),
                          _StatData('Admins', admins.toString()),
                          _StatData('Avg Student XP', avgXp.toStringAsFixed(1)),
                          _StatData('Total Lessons', totalLessons.toString()),
                          _StatData(
                            'Total Announcements',
                            totalAnnouncements.toString(),
                          ),
                          _StatData(
                            'Top Student XP',
                            topStudent == null
                                ? '0'
                                : _extractXp(topStudent.data()).toString(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Top Student',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (topStudent == null)
                              const Text('No student data.')
                            else
                              _topStudentTile(topStudent.data()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Top 5 Student Leaderboard',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (top5.isEmpty)
                              const Text('No leaderboard data.')
                            else
                              ...top5.asMap().entries.map((entry) {
                                final rank = entry.key + 1;
                                final data = entry.value.data();
                                final name =
                                    (data['name'] ??
                                            data['firstName'] ??
                                            'Student')
                                        .toString();
                                final xp = _extractXp(data);
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: _primary.withValues(
                                      alpha: 0.15,
                                    ),
                                    child: Text(
                                      '$rank',
                                      style: const TextStyle(
                                        color: _primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(name),
                                  trailing: Text(
                                    '$xp XP',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _topStudentTile(Map<String, dynamic> data) {
    final name = (data['name'] ?? data['firstName'] ?? 'Student').toString();
    final email = (data['email'] ?? '').toString();
    final xp = _extractXp(data);
    final level = _toInt(data['level'], fallback: 1);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1ECFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _primary,
            child: Text(
              name.isEmpty ? 'S' : name[0].toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Text('Lv.$level  $xp XP'),
        ],
      ),
    );
  }

  int _extractXp(Map<String, dynamic> data) {
    final xp = data['xp'];
    final xpPoints = data['xpPoints'];
    if (xp is num) {
      return xp.toInt();
    }
    if (xpPoints is num) {
      return xpPoints.toInt();
    }
    return 0;
  }

  int _toInt(dynamic value, {required int fallback}) {
    if (value is num) {
      return value.toInt();
    }
    return fallback;
  }
}

class _StatData {
  const _StatData(this.title, this.value);

  final String title;
  final String value;
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items});

  final List<_StatData> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 560
            ? 3
            : 2;

        return GridView.builder(
          itemCount: items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.4,
          ),
          itemBuilder: (_, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6C3BFF),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
