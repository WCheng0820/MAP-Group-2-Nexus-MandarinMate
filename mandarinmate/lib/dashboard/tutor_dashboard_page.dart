import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mandarinmate/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mandarinmate/features/auth/presentation/pages/login_page.dart';
import 'package:mandarinmate/features/tutor/presentation/pages/tutor_announcement_page.dart';
import 'package:mandarinmate/features/tutor/presentation/pages/tutor_lessons_page.dart';
import 'package:mandarinmate/features/tutor/presentation/pages/tutor_students_page.dart';

class TutorDashboardPage extends StatelessWidget {
  const TutorDashboardPage({super.key});

  static const Color _green = Color(0xFF0F6E56);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF8),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: user == null
              ? null
              : FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? <String, dynamic>{};
            final name = (data['name'] ?? '').toString().isEmpty
                ? 'Tutor'
                : (data['name'] ?? '').toString();

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 170,
                  pinned: true,
                  backgroundColor: _green,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: () {
                        context.read<AuthBloc>().add(AuthLogoutRequested());
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (_) => false,
                        );
                      },
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0F6E56), Color(0xFF0A5745)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 72, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Text(
                              'Tutor Dashboard',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Selamat datang, $name',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .where('role', isEqualTo: 'student')
                                  .snapshots(),
                              builder: (context, studentSnapshot) {
                                final studentCount =
                                    studentSnapshot.data?.docs.length ?? 0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.groups_rounded,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$studentCount pelajar aktif',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.08,
                      children: [
                        _DashboardCard(
                          icon: Icons.menu_book_rounded,
                          title: 'Urus Lesson',
                          subtitle: 'Tambah, edit dan padam unit',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TutorLessonsPage(),
                              ),
                            );
                          },
                        ),
                        _DashboardCard(
                          icon: Icons.people_alt_rounded,
                          title: 'Senarai Pelajar',
                          subtitle: 'Lihat profil dan kemajuan',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TutorStudentsPage(),
                              ),
                            );
                          },
                        ),
                        _DashboardCard(
                          icon: Icons.campaign_rounded,
                          title: 'Pengumuman',
                          subtitle: 'Hantar notis kepada pelajar',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TutorAnnouncementPage(),
                              ),
                            );
                          },
                        ),
                        _DashboardCard(
                          icon: Icons.chat_bubble_rounded,
                          title: 'Chat',
                          subtitle: 'Modul chat belum tersedia',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Modul chat akan datang.'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  static const Color _green = Color(0xFF0F6E56);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _green, size: 28),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade600, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
