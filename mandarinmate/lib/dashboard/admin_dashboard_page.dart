import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/utils/app_theme.dart';
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
import 'package:mandarinmate/widgets/notification_badge_icon.dart';
import 'dart:async';
import 'package:mandarinmate/widgets/in_app_notification_overlay.dart';


class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _currentIndex = 0;
  StreamSubscription? _notifSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifSubscription = InAppNotificationOverlay.subscribeToNotifications(
        context,
        role: 'admin',
        themeColor: _AdminDashboardColors.primaryAction,
      );
    });
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: context.scaffoldBg,
        body: const Center(child: Text('Session expired. Please login again.')),
      );
    }

    Widget body;
    switch (_currentIndex) {
      case 0:
        body = _buildHomeTab(context, user);
        break;
      case 1:
        body = const AdminUsersPage();
        break;
      case 2:
        body = const AdminLessonsPage();
        break;
      case 3:
        body = const AdminAnnouncementsPage();
        break;
      case 4:
        body = const AdminAnalyticsPage();
        break;
      case 5:
        body = const AdminProfilePage();
        break;
      default:
        body = _buildHomeTab(context, user);
    }

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => _onNavTapped(context, index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: context.cardBg,
        elevation: 0,
        selectedItemColor: context.isDarkMode ? Colors.purple.shade300 : _AdminDashboardColors.headerStart,
        unselectedItemColor: context.textMuted,
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
      body: body,
    );
  }

  Widget _buildHomeTab(BuildContext context, User user) {
    return _AdminPageFrame(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final name = (data['name'] ?? data['firstName'] ?? 'Admin').toString();

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AdminHeader(
                  name: name,
                  onEditProfile: _handleEditProfile,
                  onLogout: _handleLogout,
                ),
                const SizedBox(height: 16),
                _AdminHero(
                  uid: user.uid,
                  fallbackEmail: user.email,
                ),
                const SizedBox(height: 22),
                const _SectionTitle(
                  title: 'Real-time analytics',
                  subtitle:
                      'A live view of users currently registered across the platform.',
                ),
                const SizedBox(height: 14),
                const _RealtimeAnalyticsSection(),
                const SizedBox(height: 22),
                const _AdminSystemHealthSection(),
                const SizedBox(height: 22),
                const _AdminRoleBreakdownSection(),
                const SizedBox(height: 22),
                _SectionTitle(
                  title: 'Management hub',
                  subtitle:
                      'Move quickly between moderation, lesson curation, announcements, and reporting.',
                  actionLabel: 'Open users',
                  onAction: () => setState(() => _currentIndex = 1),
                ),
                const SizedBox(height: 14),
                _ManagementGrid(
                  actions: [
                    _ManagementActionData(
                      title: 'Manage Users',
                      subtitle: 'Roles, accounts, and moderation tools',
                      icon: Icons.group_rounded,
                      color: _AdminDashboardColors.students,
                      onTap: () => setState(() => _currentIndex = 1),
                    ),
                    _ManagementActionData(
                      title: 'Manage Lessons',
                      subtitle: 'Curriculum, units, and XP rewards',
                      icon: Icons.menu_book_rounded,
                      color: _AdminDashboardColors.primaryAction,
                      onTap: () => setState(() => _currentIndex = 2),
                    ),
                    _ManagementActionData(
                      title: 'Announcements',
                      subtitle: 'Publish updates to students and tutors',
                      icon: Icons.campaign_rounded,
                      color: _AdminDashboardColors.admins,
                      onTap: () => setState(() => _currentIndex = 3),
                    ),
                    _ManagementActionData(
                      title: 'Analytics',
                      subtitle: 'Review activity and learning trends',
                      icon: Icons.insights_rounded,
                      color: _AdminDashboardColors.tutors,
                      onTap: () => setState(() => _currentIndex = 4),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SectionTitle(
                  title: 'Recent users',
                  subtitle:
                      'A quick preview of the newest accounts joining MandarinMate.',
                  actionLabel: 'View all',
                  onAction: () => setState(() => _currentIndex = 1),
                ),
                const SizedBox(height: 14),
                const _RecentUsersSection(),
              ],
            ),
          );
        },
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
  }
}

class _AdminPageFrame extends StatelessWidget {
  const _AdminPageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: context.isDarkMode
              ? [const Color(0xFF190B22), const Color(0xFF100416)]
              : [const Color(0xFFFCF9FF), const Color(0xFFF3EDFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({
    required this.name,
    required this.onEditProfile,
    required this.onLogout,
  });

  final String name;
  final VoidCallback onEditProfile;
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
                style: TextStyle(
                  color: context.textDeep,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'MandarinMate Administrator',
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        NotificationBadgeIcon(
          role: 'admin',
          themeColor: _AdminDashboardColors.headerStart,
          iconColor: context.textDeep,
        ),
      ],
    );
  }
}

class _AdminHero extends StatelessWidget {
  const _AdminHero({required this.uid, required this.fallbackEmail});

  final String uid;
  final String? fallbackEmail;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final email = (data['email'] ?? fallbackEmail ?? '').toString();
        final name = (data['name'] ?? data['firstName'] ?? 'Admin').toString();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                context.isDarkMode ? Color(0xFF3B1F4A) : _AdminDashboardColors.headerStart,
                context.isDarkMode ? Color(0xFF230C36) : _AdminDashboardColors.headerEnd,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _AdminDashboardColors.headerStart.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _GlassBadge(
                icon: Icons.shield_rounded,
                label: 'Admin Shield',
              ),
              const SizedBox(height: 18),
              Text(
                'Welcome back, $name!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                email.isEmpty ? 'admin@utm.my' : email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFF1E8FF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Track user growth, coordinate teaching operations, and keep content delivery sharp.',
                style: TextStyle(
                  color: const Color(0xFFE8D9F8).withValues(alpha: 0.95),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
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
            height: 135,
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
          height: 135,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: data.color,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textMuted,
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
        double childAspectRatio;
        if (constraints.maxWidth >= 920) {
          childAspectRatio = 1.15;
        } else if (constraints.maxWidth >= 600) {
          childAspectRatio = 1.05;
        } else if (constraints.maxWidth >= 380) {
          childAspectRatio = 0.85;
        } else {
          childAspectRatio = 0.72;
        }

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
      color: context.cardBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: action.color.withValues(alpha: 0.08),
        highlightColor: action.color.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _AdminDashboardDecorations.cardDecoration(context),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: action.color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(action.icon, color: action.color, size: 24),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: action.color.withValues(alpha: 0.78),
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    action.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textDeep,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    action.subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
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
          return _MessageCard(
            message: 'No users found.',
            color: context.textMuted,
          );
        }

        return Container(
          decoration: _AdminDashboardDecorations.cardDecoration(context),
          child: Column(
            children: [
              for (int index = 0; index < docs.length; index++) ...[
                _RecentUserTile(data: docs[index].data()),
                if (index != docs.length - 1)
                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: context.borderTheme,
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
                  style: TextStyle(
                    color: context.textDeep,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email.isEmpty ? 'No email available' : email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textMuted,
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
                style: TextStyle(
                  color: context.textDeep,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.textMuted,
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
      decoration: _AdminDashboardDecorations.cardDecoration(context),
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
      decoration: _AdminDashboardDecorations.cardDecoration(context),
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
  static BoxDecoration cardDecoration(BuildContext context) => BoxDecoration(
    color: context.cardBg,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: context.isDarkMode ? Colors.black26 : Colors.black.withValues(alpha: 0.03),
        blurRadius: 15,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

class _AdminDashboardColors {
  static const headerStart = Color(0xFF7B1FA2);
  static const headerEnd = Color(0xFF4A148C);
  static const students = Color(0xFF3182CE);
  static const tutors = Color(0xFF2F855A);
  static const admins = Color(0xFFDD6B20);
  static const primaryAction = Color(0xFF6B46C1);
}

// -----------------------------------------------------
// ADMIN SYSTEM HEALTH STATUS COMPONENT
// -----------------------------------------------------

class _AdminSystemHealthSection extends StatelessWidget {
  const _AdminSystemHealthSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderTheme),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05111827),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _AdminDashboardColors.headerStart.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  color: _AdminDashboardColors.headerStart,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'System Infrastructure & Security',
                  style: TextStyle(
                    color: context.textDeep,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildHealthRow(
            context,
            icon: Icons.cloud_done_rounded,
            iconColor: Colors.green,
            label: 'Firebase Services',
            value: 'Connected & Secure',
            badgeColor: Colors.green.shade50,
            badgeTextColor: Colors.green.shade700,
          ),
          Divider(height: 24, color: context.borderTheme),
          _buildHealthRow(
            context,
            icon: Icons.security_rounded,
            iconColor: Colors.blue,
            label: 'Firestore Database Rules',
            value: 'Enforced (v2)',
            badgeColor: Colors.blue.shade50,
            badgeTextColor: Colors.blue.shade700,
          ),
          Divider(height: 24, color: context.borderTheme),
          _buildHealthRow(
            context,
            icon: Icons.shield_rounded,
            iconColor: Colors.purple,
            label: 'User Auth Validation',
            value: 'UTM Email Domain Only',
            badgeColor: Colors.purple.shade50,
            badgeTextColor: Colors.purple.shade700,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color badgeColor,
    required Color badgeTextColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.textDeep,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: context.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: badgeTextColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Active',
                style: TextStyle(
                  color: badgeTextColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------
// ADMIN USER ROLE DISTRIBUTION DISTRIBUTION COMPONENT
// -----------------------------------------------------

class _AdminRoleBreakdownSection extends StatelessWidget {
  const _AdminRoleBreakdownSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data?.docs ?? const [];
        int students = 0;
        int tutors = 0;
        int admins = 0;

        for (final doc in docs) {
          final role = (doc.data()['role'] ?? 'student').toString().toLowerCase();
          if (role == 'student') {
            students++;
          } else if (role == 'tutor') {
            tutors++;
          } else if (role == 'admin') {
            admins++;
          }
        }

        final total = docs.length.clamp(1, 999999);
        final studentPct = students / total;
        final tutorPct = tutors / total;
        final adminPct = admins / total;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderTheme),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05111827),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _AdminDashboardColors.students.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pie_chart_rounded,
                      color: _AdminDashboardColors.students,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'User Distribution Proportion',
                    style: TextStyle(
                      color: context.textDeep,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 16,
                  child: Row(
                    children: [
                      if (students > 0)
                        Expanded(
                          flex: (studentPct * 100).round().clamp(1, 100),
                          child: Container(color: _AdminDashboardColors.students),
                        ),
                      if (tutors > 0)
                        Expanded(
                          flex: (tutorPct * 100).round().clamp(1, 100),
                          child: Container(color: _AdminDashboardColors.tutors),
                        ),
                      if (admins > 0)
                        Expanded(
                          flex: (adminPct * 100).round().clamp(1, 100),
                          child: Container(color: _AdminDashboardColors.admins),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  _buildLegendItem(
                    context,
                    color: _AdminDashboardColors.students,
                    label: 'Students',
                    percentage: '${(studentPct * 100).round()}%',
                  ),
                  _buildLegendItem(
                    context,
                    color: _AdminDashboardColors.tutors,
                    label: 'Tutors',
                    percentage: '${(tutorPct * 100).round()}%',
                  ),
                  _buildLegendItem(
                    context,
                    color: _AdminDashboardColors.admins,
                    label: 'Admins',
                    percentage: '${(adminPct * 100).round()}%',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(BuildContext context, {required Color color, required String label, required String percentage}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($percentage)',
          style: TextStyle(
            color: context.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
