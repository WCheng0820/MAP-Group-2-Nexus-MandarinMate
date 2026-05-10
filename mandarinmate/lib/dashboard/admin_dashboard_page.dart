import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mandarinmate/auth/presentation/bloc/auth_bloc.dart';
import 'package:mandarinmate/screens/profile/edit_profile_page.dart'
    as mandarinmate_edit_profile;
import 'package:mandarinmate/dashboard/admin_analytics_page.dart';
import 'package:mandarinmate/dashboard/admin_announcements_page.dart';
import 'package:mandarinmate/dashboard/admin_lessons_page.dart';
import 'package:mandarinmate/dashboard/admin_users_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: _AdminColors.paper,
        body: const Center(child: Text('Session expired. Please login again.')),
      );
    }

    return Scaffold(
      backgroundColor: _AdminColors.paper,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: _AdminColors.primary,
        unselectedItemColor: _AdminColors.muted,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => _onNavTapped(context, index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_rounded),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_rounded),
            label: 'Lessons',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_rounded),
            label: 'Announcements',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights_rounded),
            label: 'Analytics',
          ),
        ],
      ),
      body: _AdminPageFrame(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AdminHeader(
                uid: user.uid,
                onLogout: () {
                  context.read<AuthBloc>().add(AuthLogoutRequested());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logout successful'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  context.go('/login');
                },
              ),
              const SizedBox(height: 14),
              _AdminHero(
                onManageUsers: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminUsersPage()),
                  );
                },
              ),
              const SizedBox(height: 18),
              _SectionHeader(
                title: 'Quick actions',
                onViewAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminUsersPage()),
                  );
                },
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 700 ? 4 : 2;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: constraints.maxWidth > 700 ? 1.4 : 1.18,
                    children: [
                      _AdminActionTile(
                        icon: Icons.group_rounded,
                        title: 'Users',
                        subtitle: 'Manage accounts',
                        color: _AdminColors.primary,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminUsersPage(),
                            ),
                          );
                        },
                      ),
                      _AdminActionTile(
                        icon: Icons.menu_book_rounded,
                        title: 'Lessons',
                        subtitle: 'Manage content',
                        color: _AdminColors.secondary,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminLessonsPage(),
                            ),
                          );
                        },
                      ),
                      _AdminActionTile(
                        icon: Icons.campaign_rounded,
                        title: 'Announcements',
                        subtitle: 'Broadcast updates',
                        color: _AdminColors.orange,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminAnnouncementsPage(),
                            ),
                          );
                        },
                      ),
                      _AdminActionTile(
                        icon: Icons.insights_rounded,
                        title: 'Analytics',
                        subtitle: 'Platform metrics',
                        color: _AdminColors.blue,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminAnalyticsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              _SectionHeader(
                title: 'Latest users',
                onViewAll: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminUsersPage()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _LatestUsersCard(),
            ],
          ),
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
          MaterialPageRoute(builder: (_) => const AdminUsersPage()),
        );
        return;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminLessonsPage()),
        );
        return;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminAnnouncementsPage()),
        );
        return;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminAnalyticsPage()),
        );
        return;
    }
  }
}

class _AdminPageFrame extends StatelessWidget {
  const _AdminPageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_AdminColors.paper, Color(0xFFF2EDFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.uid, required this.onLogout});

  final String uid;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingCard(height: 110);
        }

        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final name = (data['name'] ?? data['firstName'] ?? 'Admin').toString();
        final email = (data['email'] ?? '').toString();

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
                      color: _AdminColors.deep,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email.isEmpty ? 'Admin console' : email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _AdminColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const mandarinmate_edit_profile.EditProfilePage(
                              roleColor: _AdminColors.primary,
                            ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFE6DEFF)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          color: _AdminColors.primary,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Edit',
                          style: TextStyle(
                            color: _AdminColors.deep,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onLogout,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F0),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFFFD6D6)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFD32F2F),
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: Color(0xFFD32F2F),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _AdminHero extends StatelessWidget {
  const _AdminHero({required this.onManageUsers});

  final VoidCallback onManageUsers;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingCard(height: 140);
        }
        if (snapshot.hasError) {
          return const _ErrorCard(message: 'Failed to load real-time stats.');
        }

        final docs = snapshot.data?.docs ?? const [];
        int students = 0;
        int tutors = 0;
        int admins = 0;

        for (final doc in docs) {
          final role = (doc.data()['role'] ?? 'student')
              .toString()
              .toLowerCase();
          if (role == 'student') students++;
          if (role == 'tutor') tutors++;
          if (role == 'admin') admins++;
        }

        final total = docs.length;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_AdminColors.primary, _AdminColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x305C3BFF),
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
                  const Expanded(
                    child: Text(
                      'Admin Dashboard',
                      style: TextStyle(
                        color: Color(0xFFEDE7FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _HeroBadge(label: '$total users'),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Platform overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Students: $students · Tutors: $tutors · Admins: $admins',
                style: const TextStyle(
                  color: Color(0xFFF0ECFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onManageUsers,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _AdminColors.primary,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                child: const Text('Manage users'),
              ),
            ],
          ),
        );
      },
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

class _RealtimeStatsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingCard(height: 120);
        }
        if (snapshot.hasError) {
          return const _ErrorCard(message: 'Failed to load real-time stats.');
        }

        final docs = snapshot.data?.docs ?? const [];
        int students = 0;
        int tutors = 0;
        int admins = 0;

        for (final doc in docs) {
          final role = (doc.data()['role'] ?? 'student')
              .toString()
              .toLowerCase();
          if (role == 'student') students++;
          if (role == 'tutor') tutors++;
          if (role == 'admin') admins++;
        }

        final total = docs.length;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8E1FF)),
          ),
          child: Row(
            children: [
              _StatItem(title: 'Total', value: total.toString()),
              _StatItem(title: 'Students', value: students.toString()),
              _StatItem(title: 'Tutors', value: tutors.toString()),
              _StatItem(title: 'Admins', value: admins.toString()),
            ],
          ),
        );
      },
    );
  }
}

class _LatestUsersCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingCard(height: 180);
        }
        if (snapshot.hasError) {
          return const _ErrorCard(message: 'Failed to load latest users.');
        }

        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const _EmptyCard(message: 'No users found.');
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8E1FF)),
          ),
          child: ListView.separated(
            itemCount: docs.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final name = (data['name'] ?? data['firstName'] ?? 'Unknown')
                  .toString();
              final email = (data['email'] ?? '').toString();
              final role = (data['role'] ?? 'student').toString();

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(
                    0xFF6C3BFF,
                  ).withValues(alpha: 0.12),
                  child: Text(
                    name.isEmpty ? 'U' : name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF6C3BFF),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: _RoleBadge(role: role),
              );
            },
          ),
        );
      },
    );
  }
}

class _AdminActionTile extends StatelessWidget {
  const _AdminActionTile({
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
            border: Border.all(color: const Color(0xFFE6DEFF)),
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
                  color: _AdminColors.deep,
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
                  color: _AdminColors.muted,
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
              color: _AdminColors.deep,
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

class _AdminColors {
  static const primary = Color(0xFF6C3BFF);
  static const secondary = Color(0xFF8B66FF);
  static const orange = Color(0xFFF59E0B);
  static const blue = Color(0xFF2F80ED);
  static const deep = Color(0xFF1C2433);
  static const muted = Color(0xFF6B7280);
  static const paper = Color(0xFFF7F5FF);
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final normalized = role.toLowerCase();
    Color color;
    switch (normalized) {
      case 'admin':
        color = const Color(0xFF8E24AA);
        break;
      case 'tutor':
        color = const Color(0xFF5E35B1);
        break;
      default:
        color = const Color(0xFF6C3BFF);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        normalized.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6C3BFF),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E1FF)),
      ),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(color: Color(0xFF6C3BFF)),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD7E1)),
      ),
      child: Text(message, style: const TextStyle(color: Colors.redAccent)),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E1FF)),
      ),
      child: Text(message, style: TextStyle(color: Colors.grey.shade700)),
    );
  }
}
