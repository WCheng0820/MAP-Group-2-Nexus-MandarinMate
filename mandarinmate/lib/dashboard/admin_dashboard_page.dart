import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mandarinmate/auth/presentation/bloc/auth_bloc.dart';
import 'package:mandarinmate/dashboard/admin_analytics_page.dart';
import 'package:mandarinmate/dashboard/admin_announcements_page.dart';
import 'package:mandarinmate/dashboard/admin_lessons_page.dart';
import 'package:mandarinmate/dashboard/admin_users_page.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  static const Color _surface = Color(0xFFF6F3FF);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: _surface,
        body: const Center(child: Text('Session expired. Please login again.')),
      );
    }

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _AdminHeader(
                  uid: user.uid,
                  onLogout: () {
                    context.read<AuthBloc>().add(AuthLogoutRequested());
                    context.go('/login');
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _RealtimeStatsCard(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = constraints.maxWidth > 700 ? 4 : 2;
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: constraints.maxWidth > 700 ? 1.5 : 1.2,
                      children: [
                        _MenuCard(
                          icon: Icons.group_rounded,
                          title: 'Users',
                          subtitle: 'Manage accounts',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminUsersPage(),
                              ),
                            );
                          },
                        ),
                        _MenuCard(
                          icon: Icons.menu_book_rounded,
                          title: 'Lessons',
                          subtitle: 'Manage content',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminLessonsPage(),
                              ),
                            );
                          },
                        ),
                        _MenuCard(
                          icon: Icons.campaign_rounded,
                          title: 'Announcements',
                          subtitle: 'Broadcast updates',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AdminAnnouncementsPage(),
                              ),
                            );
                          },
                        ),
                        _MenuCard(
                          icon: Icons.insights_rounded,
                          title: 'Analytics',
                          subtitle: 'Platform metrics',
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
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'Latest Users',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _LatestUsersCard(),
              ),
            ),
          ],
        ),
      ),
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
          return const _LoadingCard(height: 124);
        }

        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final name = (data['name'] ?? data['firstName'] ?? 'Admin').toString();
        final email = (data['email'] ?? '').toString();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C3BFF), Color(0xFF8B66FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onLogout,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                ),
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
              ),
            ],
          ),
        );
      },
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

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C3BFF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF6C3BFF)),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
