import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mandarinmate/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:mandarinmate/features/auth/presentation/pages/login_page.dart';
import 'package:mandarinmate/features/tutor/presentation/pages/tutor_announcement_page.dart';
import 'package:mandarinmate/features/tutor/presentation/pages/tutor_lessons_page.dart';
import 'package:mandarinmate/features/tutor/presentation/pages/tutor_students_page.dart';

class TutorDashboardPage extends StatefulWidget {
  const TutorDashboardPage({super.key});

  @override
  State<TutorDashboardPage> createState() => _TutorDashboardPageState();
}

class _TutorDashboardPageState extends State<TutorDashboardPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _TutorColors.paper,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: _TutorColors.green,
        unselectedItemColor: _TutorColors.muted,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => _onNavTapped(context, index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            label: 'Lessons',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_rounded),
            label: 'Students',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_rounded),
            label: 'Announcements',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
        ],
      ),
      body: _TutorPageFrame(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: user == null
              ? null
              : FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? <String, dynamic>{};
            final name = _displayName(data);

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TutorHeader(
                    name: name,
                    onLogout: () {
                      context.read<AuthBloc>().add(AuthLogoutRequested());
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Logout successful'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (_) => false,
                      );
                    },
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
                      return _TutorHero(
                        title: 'Tutor Dashboard',
                        headline: 'Manage Mandarin Lessons',
                        subtitle: '$studentCount active students',
                        actionLabel: 'Tambah Lesson',
                        onAction: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TutorLessonsPage(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _SectionHeader(
                    title: 'Quick actions',
                    onViewAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TutorLessonsPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.18,
                    children: [
                      _TutorActionTile(
                        icon: Icons.menu_book_rounded,
                        title: 'Manage Lessons',
                        subtitle: 'Add, edit, and delete units',
                        color: _TutorColors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TutorLessonsPage(),
                            ),
                          );
                        },
                      ),
                      _TutorActionTile(
                        icon: Icons.people_alt_rounded,
                        title: 'Student List',
                        subtitle: 'View profiles and progress',
                        color: _TutorColors.teal,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TutorStudentsPage(),
                            ),
                          );
                        },
                      ),
                      _TutorActionTile(
                        icon: Icons.campaign_rounded,
                        title: 'Announcements',
                        subtitle: 'Send updates to students',
                        color: _TutorColors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TutorAnnouncementPage(),
                            ),
                          );
                        },
                      ),
                      _TutorActionTile(
                        icon: Icons.chat_bubble_rounded,
                        title: 'Chat',
                        subtitle: 'Chat module coming soon',
                        color: _TutorColors.blue,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Chat module is coming soon.'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _onNavTapped(BuildContext context, int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        return;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TutorLessonsPage()),
        );
        return;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TutorStudentsPage()),
        );
        return;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TutorAnnouncementPage()),
        );
        return;
      case 4:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat module is coming soon.')),
        );
        return;
    }
  }
}

class _TutorPageFrame extends StatelessWidget {
  const _TutorPageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_TutorColors.paper, Color(0xFFEFF8F4)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

class _TutorHeader extends StatelessWidget {
  const _TutorHeader({required this.name, required this.onLogout});

  final String name;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _TutorColors.deep,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Ready to guide your students?',
                style: TextStyle(
                  color: _TutorColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onLogout,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFDFF2E9)),
            ),
            child: const Row(
              children: [
                Icon(Icons.logout_rounded, color: _TutorColors.green, size: 18),
                SizedBox(width: 6),
                Text(
                  'Logout',
                  style: TextStyle(
                    color: _TutorColors.deep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TutorHero extends StatelessWidget {
  const _TutorHero({
    required this.title,
    required this.headline,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String headline;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_TutorColors.green, _TutorColors.teal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x300F6E56),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFDDF5EC),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const _HeroBadge(label: 'Tutor'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            headline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFFE6FBF4),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _TutorColors.green,
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TutorActionTile extends StatelessWidget {
  const _TutorActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDDF2E8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D111827),
                blurRadius: 12,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _TutorColors.deep,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _TutorColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onViewAll});

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _TutorColors.deep,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(onPressed: onViewAll, child: const Text('View all')),
      ],
    );
  }
}

class _TutorColors {
  static const green = Color(0xFF0F6E56);
  static const teal = Color(0xFF0A5745);
  static const orange = Color(0xFFF59E0B);
  static const blue = Color(0xFF2F80ED);
  static const deep = Color(0xFF1C2433);
  static const muted = Color(0xFF6B7280);
  static const paper = Color(0xFFF7FBF9);
}

String _displayName(Map<String, dynamic> data) {
  final name = (data['name'] ?? '').toString().trim();
  if (name.isNotEmpty) return name;

  final firstName = (data['firstName'] ?? '').toString().trim();
  final lastName = (data['lastName'] ?? '').toString().trim();
  final fullName = '$firstName $lastName'.trim();
  if (fullName.isNotEmpty) return fullName;

  return 'Tutor';
}
