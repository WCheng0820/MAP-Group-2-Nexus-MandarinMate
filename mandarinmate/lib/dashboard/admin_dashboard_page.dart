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
import 'package:mandarinmate/dashboard/admin_profile_page.dart';
import 'package:mandarinmate/screens/profile/edit_profile_page.dart'
    as mandarinmate_edit_profile;

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
        backgroundColor: _AdminDashboardColors.background,
        body: const Center(child: Text('Session expired. Please login again.')),
      );
    }

    return Scaffold(
      backgroundColor: _AdminDashboardColors.background,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => _onNavTapped(context, index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: _AdminDashboardColors.headerStart,
        unselectedItemColor: _AdminDashboardColors.muted,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
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
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            elevation: 0,
            backgroundColor: _AdminDashboardColors.headerStart,
            expandedHeight: 270,
            titleSpacing: 20,
            title: const Text(
              'Admin Dashboard',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    _HeaderActionButton(
                      icon: Icons.edit_rounded,
                      tooltip: 'Edit profile',
                      onTap: _handleEditProfile,
                    ),
                    const SizedBox(width: 8),
                    _HeaderActionButton(
                      icon: Icons.logout_rounded,
                      tooltip: 'Logout',
                      onTap: _handleLogout,
                    ),
                  ],
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _AdminHeroHeader(
                uid: user.uid,
                fallbackEmail: user.email,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _SectionTitle(
                  title: 'Real-time analytics',
                  subtitle:
                      'A live view of users currently registered across the platform.',
                ),
                const SizedBox(height: 14),
                const _RealtimeAnalyticsSection(),
                const SizedBox(height: 28),
                _SectionTitle(
                  title: 'Management hub',
                  subtitle:
                      'Move quickly between moderation, lesson curation, announcements, and reporting.',
                  actionLabel: 'Open users',
                  onAction: () => _openPage(context, const AdminUsersPage()),
                ),
                const SizedBox(height: 14),
                _ManagementGrid(
                  actions: [
                    _ManagementActionData(
                      title: 'Manage Users',
                      subtitle: 'Roles, accounts, and moderation tools',
                      icon: Icons.group_rounded,
                      color: _AdminDashboardColors.students,
                      onTap: () => _openPage(context, const AdminUsersPage()),
                    ),
                    _ManagementActionData(
                      title: 'Manage Lessons',
                      subtitle: 'Curriculum, units, and XP rewards',
                      icon: Icons.menu_book_rounded,
                      color: _AdminDashboardColors.primaryAction,
                      onTap: () => _openPage(context, const AdminLessonsPage()),
                    ),
                    _ManagementActionData(
                      title: 'Announcements',
                      subtitle: 'Publish updates to students and tutors',
                      icon: Icons.campaign_rounded,
                      color: _AdminDashboardColors.admins,
                      onTap: () =>
                          _openPage(context, const AdminAnnouncementsPage()),
                    ),
                    _ManagementActionData(
                      title: 'Analytics',
                      subtitle: 'Review activity and learning trends',
                      icon: Icons.insights_rounded,
                      color: _AdminDashboardColors.tutors,
                      onTap: () =>
                          _openPage(context, const AdminAnalyticsPage()),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _SectionTitle(
                  title: 'Recent users',
                  subtitle:
                      'A quick preview of the newest accounts joining MandarinMate.',
                  actionLabel: 'View all',
                  onAction: () => _openPage(context, const AdminUsersPage()),
                ),
                const SizedBox(height: 14),
                const _RecentUsersSection(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _handleEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const mandarinmate_edit_profile.EditProfilePage(
          roleColor: _AdminDashboardColors.headerStart,
        ),
      ),
    );
  }

  void _handleLogout() {
    context.read<AuthBloc>().add(AuthLogoutRequested());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logout successful'),
        backgroundColor: Colors.green,
      ),
    );
    context.go('/login');
  }

  void _onNavTapped(BuildContext context, int index) {
    setState(() => _currentIndex = index);

    switch (index) {
      case 0:
        return;
      case 1:
        _openPage(context, const AdminUsersPage());
        return;
      case 2:
        _openPage(context, const AdminLessonsPage());
        return;
      case 3:
        _openPage(context, const AdminAnnouncementsPage());
        return;
      case 4:
        _openPage(context, const AdminAnalyticsPage());
        return;
      case 5:
        _openPage(context, const AdminProfilePage());
        return;
    }
  }

  static void _openPage(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

class _AdminHeroHeader extends StatelessWidget {
  const _AdminHeroHeader({required this.uid, required this.fallbackEmail});

  final String uid;
  final String? fallbackEmail;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _AdminDashboardColors.headerStart,
            _AdminDashboardColors.headerEnd,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final email = (data['email'] ?? fallbackEmail ?? '').toString();
          final name = (data['name'] ?? data['firstName'] ?? 'Admin')
              .toString();

          return SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 100, 24, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _GlassBadge(
                    icon: Icons.shield_rounded,
                    label: 'Admin Shield',
                  ),
                  const Spacer(),
                  Text(
                    'Welcome back, $name!',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email.isEmpty ? 'admin@mandarinmate.app' : email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF1E8FF),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Track user growth, coordinate teaching operations, and keep content delivery sharp.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFE8D9F8),
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 42,
            width: 42,
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _GlassBadge extends StatelessWidget {
  const _GlassBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RealtimeAnalyticsSection extends StatelessWidget {
  const _RealtimeAnalyticsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _StatusPanel(
            height: 126,
            child: CircularProgressIndicator(
              color: _AdminDashboardColors.headerStart,
            ),
          );
        }

        if (snapshot.hasError) {
          return const _MessageCard(
            message: 'Failed to load real-time stats.',
            color: Colors.redAccent,
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        int students = 0;
        int tutors = 0;
        int admins = 0;

        for (final doc in docs) {
          final role = (doc.data()['role'] ?? 'student')
              .toString()
              .toLowerCase();
          if (role == 'student') {
            students++;
          } else if (role == 'tutor') {
            tutors++;
          } else if (role == 'admin') {
            admins++;
          }
        }

        final cards = [
          _MetricCardData(
            label: 'Total Users',
            value: docs.length.toString(),
            color: _AdminDashboardColors.headerStart,
            icon: Icons.groups_rounded,
          ),
          _MetricCardData(
            label: 'Students',
            value: students.toString(),
            color: _AdminDashboardColors.students,
            icon: Icons.school_rounded,
          ),
          _MetricCardData(
            label: 'Tutors',
            value: tutors.toString(),
            color: _AdminDashboardColors.tutors,
            icon: Icons.cast_for_education_rounded,
          ),
          _MetricCardData(
            label: 'Admins',
            value: admins.toString(),
            color: _AdminDashboardColors.admins,
            icon: Icons.admin_panel_settings_rounded,
          ),
        ];

        return SizedBox(
          height: 126,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _MetricCard(data: cards[index]),
          ),
        );
      },
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricCardData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: data.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: data.color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: data.color, size: 22),
          ),
          const Spacer(),
          Text(
            data.value,
            style: TextStyle(
              color: data.color,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.label,
            style: const TextStyle(
              color: _AdminDashboardColors.bodyText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementGrid extends StatelessWidget {
  const _ManagementGrid({required this.actions});

  final List<_ManagementActionData> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 920 ? 4 : 2;
        final childAspectRatio = constraints.maxWidth >= 920 ? 1.12 : 0.98;

        return GridView.builder(
          itemCount: actions.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final action = actions[index];
            return _ManagementCard(action: action);
          },
        );
      },
    );
  }
}

class _ManagementActionData {
  const _ManagementActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _ManagementCard extends StatelessWidget {
  const _ManagementCard({required this.action});

  final _ManagementActionData action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: action.color.withValues(alpha: 0.08),
        highlightColor: action.color.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _AdminDashboardDecorations.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: action.color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(action.icon, color: action.color, size: 28),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: action.color.withValues(alpha: 0.78),
                    size: 20,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                action.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _AdminDashboardColors.heading,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                action.subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _AdminDashboardColors.bodyText,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentUsersSection extends StatelessWidget {
  const _RecentUsersSection();
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
          return const _StatusPanel(
            height: 224,
            child: CircularProgressIndicator(
              color: _AdminDashboardColors.headerStart,
            ),
          );
        }

        if (snapshot.hasError) {
          return const _MessageCard(
            message: 'Failed to load latest users.',
            color: Colors.redAccent,
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const _MessageCard(
            message: 'No users found.',
            color: _AdminDashboardColors.bodyText,
          );
        }

        return Container(
          decoration: _AdminDashboardDecorations.cardDecoration,
          child: Column(
            children: [
              for (int index = 0; index < docs.length; index++) ...[
                _RecentUserTile(data: docs[index].data()),
                if (index != docs.length - 1)
                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: _AdminDashboardColors.divider,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _RecentUserTile extends StatelessWidget {
  const _RecentUserTile({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? data['firstName'] ?? 'Unknown User')
        .toString();
    final email = (data['email'] ?? '').toString();
    final role = (data['role'] ?? 'student').toString();
    final roleStyle = _roleStyleFor(role);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: roleStyle.color.withValues(alpha: 0.14),
            child: Text(
              _initialsFrom(name),
              style: TextStyle(
                color: roleStyle.color,
                fontWeight: FontWeight.w800,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AdminDashboardColors.heading,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email.isEmpty ? 'No email available' : email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AdminDashboardColors.bodyText,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _RoleBadge(label: roleStyle.label, color: roleStyle.color),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _AdminDashboardColors.heading,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _AdminDashboardColors.bodyText,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 12),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: _AdminDashboardColors.headerStart,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              actionLabel!,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: _AdminDashboardDecorations.cardDecoration,
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _AdminDashboardDecorations.cardDecoration,
      child: Text(
        message,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RoleStyle {
  const _RoleStyle({required this.label, required this.color});

  final String label;
  final Color color;
}

_RoleStyle _roleStyleFor(String role) {
  switch (role.toLowerCase()) {
    case 'admin':
      return const _RoleStyle(
        label: 'ADMIN',
        color: _AdminDashboardColors.admins,
      );
    case 'tutor':
      return const _RoleStyle(
        label: 'TUTOR',
        color: _AdminDashboardColors.tutors,
      );
    default:
      return const _RoleStyle(
        label: 'STUDENT',
        color: _AdminDashboardColors.students,
      );
  }
}

String _initialsFrom(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return initials.isEmpty ? 'U' : initials;
}

class _AdminDashboardDecorations {
  static final cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 15,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

class _AdminDashboardColors {
  static const background = Color(0xFFF8F9FA);
  static const headerStart = Color(0xFF7B1FA2);
  static const headerEnd = Color(0xFF4A148C);
  static const heading = Color(0xFF2D3748);
  static const bodyText = Color(0xFF718096);
  static const muted = Color(0xFF94A3B8);
  static const divider = Color(0xFFE2E8F0);
  static const students = Color(0xFF3182CE);
  static const tutors = Color(0xFF2F855A);
  static const admins = Color(0xFFDD6B20);
  static const primaryAction = Color(0xFF6B46C1);
}
