import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/utils/app_theme.dart';
import 'package:mandarinmate/utils/app_language.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mandarinmate/auth/presentation/bloc/auth_bloc.dart';
import 'package:mandarinmate/auth/presentation/pages/login_page.dart';
import 'package:mandarinmate/screens/profile/edit_profile_page.dart'
as mandarinmate_edit_profile;
import 'package:mandarinmate/tutor/presentation/pages/tutor_announcement_page.dart';
import 'package:mandarinmate/screens/profile/app_settings_page.dart';
import 'package:mandarinmate/tutor/presentation/pages/tutor_manage_lessons_hub_page.dart';
import 'package:mandarinmate/tutor/presentation/pages/tutor_students_page.dart';
import 'package:mandarinmate/forum/presentation/pages/forum_page.dart';
import 'package:mandarinmate/screens/chat_list_screen.dart';
import 'package:mandarinmate/widgets/notification_badge_icon.dart';
import 'dart:async';
import 'package:mandarinmate/widgets/in_app_notification_overlay.dart';


class TutorDashboardPage extends StatefulWidget {
  const TutorDashboardPage({super.key});

  @override
  State<TutorDashboardPage> createState() => _TutorDashboardPageState();
}

class _TutorDashboardPageState extends State<TutorDashboardPage> {
  int _currentIndex = 0;
  StreamSubscription? _notifSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifSubscription = InAppNotificationOverlay.subscribeToNotifications(
        context,
        role: 'tutor',
        themeColor: _TutorColors.green,
      );
    });
  }

  @override
  void dispose() {
    _notifSubscription?.cancel();
    super.dispose();
  }

  void _logout(BuildContext context) {
    context.read<AuthBloc>().add(AuthLogoutRequested());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLanguage.t('logout_msg')),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    Widget body;
    switch (_currentIndex) {
      case 0:
        body = _buildHomeTab(context, user);
        break;
      case 1:
        body = const TutorManageLessonsHubPage();
        break;
      case 2:
        body = const TutorStudentsPage();
        break;
      case 3:
        body = _buildChatComingSoonTab();
        break;
      case 4:
        body = const ForumPage(themeColor: _TutorColors.green);
        break;
      case 5:
        body = _buildProfileTab(context, user);
        break;
      default:
        body = _buildHomeTab(context, user);
    }

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: _TutorColors.green,
        unselectedItemColor: context.textMuted,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => _onNavTapped(context, index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_rounded),
            label: AppLanguage.t('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.class_rounded),
            label: AppLanguage.t('lessons_nav'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people_alt_rounded),
            label: AppLanguage.t('students_nav'),
          ),
          BottomNavigationBarItem(
            icon: const _ChatBadgeIcon(iconData: Icons.chat_bubble_rounded),
            label: AppLanguage.t('chat'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.forum_rounded),
            label: AppLanguage.t('forum'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_circle_rounded),
            label: AppLanguage.t('profile'),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildHomeTab(BuildContext context, User? user) {
    return _TutorPageFrame(
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
                  onLogout: () => _logout(context),
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
                      title: AppLanguage.t('tutor_dashboard'),
                      headline: AppLanguage.t('tutor_hero_headline'),
                      subtitle: '$studentCount ${AppLanguage.t('active_students')}',
                      actionLabel: AppLanguage.t('manage_lessons'),
                      onAction: () {
                        setState(() => _currentIndex = 1);
                      },
                    );
                  },
                ),
                const SizedBox(height: 18),
                _SectionHeader(
                  title: AppLanguage.t('quick_actions'),
                  onViewAll: () {
                    setState(() => _currentIndex = 1);
                  },
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.1,
                  children: [
                    _TutorActionTile(
                      icon: Icons.class_rounded,
                      title: AppLanguage.t('manage_lessons'),
                      subtitle: AppLanguage.t('tutor_action_lessons_desc'),
                      color: _TutorColors.green,
                      onTap: () {
                        setState(() => _currentIndex = 1);
                      },
                    ),
                    _TutorActionTile(
                      icon: Icons.people_alt_rounded,
                      title: AppLanguage.t('tutor_action_students'),
                      subtitle: AppLanguage.t('tutor_action_students_desc'),
                      color: _TutorColors.teal,
                      onTap: () {
                        setState(() => _currentIndex = 2);
                      },
                    ),
                    _TutorActionTile(
                      icon: Icons.campaign_rounded,
                      title: AppLanguage.t('announcements'),
                      subtitle: AppLanguage.t('tutor_action_announcements_desc'),
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
                      title: AppLanguage.t('chat'),
                      subtitle: AppLanguage.t('tutor_action_chat_desc'),
                      color: _TutorColors.blue,
                      onTap: () {
                        setState(() => _currentIndex = 3);
                      },
                    ),
                    _TutorActionTile(
                      icon: Icons.forum_rounded,
                      title: AppLanguage.t('forum_discussion'),
                      subtitle: AppLanguage.t('tutor_action_forum_desc'),
                      color: const Color(0xFF673AB7),
                      onTap: () {
                        setState(() => _currentIndex = 4);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _TutorClassroomOverview(),
                const SizedBox(height: 20),
                const _TutorChecklistPanel(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatComingSoonTab() {
    return const ChatListScreen(role: 'tutor');
  }

  Widget _buildProfileTab(BuildContext context, User? user) {
    return _TutorPageFrame(
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
          final String profileImageUrl = data['profileImageUrl'] ?? '';
          final email = (data['email'] ?? user?.email ?? '').toString();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Curved Gradient Header Card using tutor green-to-teal theme
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_TutorColors.green, _TutorColors.teal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Header Row: Title & Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLanguage.t('profile'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.settings_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                      const AppSettingsPage(
                                        roleColor: _TutorColors.green,
                                        role: 'tutor',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.logout_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                onPressed: () => _logout(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Avatar & Edit Button
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: const Color(0xFFFFD54F), // Premium Yellow
                            backgroundImage: profileImageUrl.isNotEmpty
                                ? NetworkImage(profileImageUrl)
                                : null,
                            child: profileImageUrl.isEmpty
                                ? Text(
                                    name.isEmpty ? 'T' : name[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: _TutorColors.green,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 36,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                    const mandarinmate_edit_profile.EditProfilePage(
                                      roleColor: _TutorColors.green,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  color: _TutorColors.green,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Display Name
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Email
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Role Chips
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.verified_user_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  AppLanguage.t('lead_educator'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              AppLanguage.t('utm_mandarin_club'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Body Scrollable Cards
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 20.0,
                  ),
                  child: Column(
                    children: [
                      // Card 1: Dynamic Teaching Overview & Stats Grid
                      _buildTutorProfileCard(
                        title: AppLanguage.t('teaching_overview'),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .where('role', isEqualTo: 'student')
                              .snapshots(),
                          builder: (context, studentSnapshot) {
                            final studentsCount = studentSnapshot.data?.docs.length ?? 0;
 
                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('lessons')
                                  .snapshots(),
                              builder: (context, lessonsSnapshot) {
                                final lessonsCount = lessonsSnapshot.data?.docs.length ?? 0;
 
                                return StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('announcements')
                                      .snapshots(),
                                  builder: (context, announcementsSnapshot) {
                                    final announcementsCount = announcementsSnapshot.data?.docs.length ?? 0;
 
                                    return GridView.count(
                                      crossAxisCount: 2,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 1.25,
                                      children: [
                                        _buildTutorStatItem(
                                          icon: '👥',
                                          value: '$studentsCount',
                                          label: AppLanguage.t('students_managed'),
                                          bgColor: const Color(0xFFE8F5E9),
                                          iconColor: _TutorColors.green,
                                        ),
                                        _buildTutorStatItem(
                                          icon: '📚',
                                          value: '$lessonsCount',
                                          label: AppLanguage.t('lessons_published'),
                                          bgColor: const Color(0xFFE3F2FD),
                                          iconColor: _TutorColors.blue,
                                        ),
                                        _buildTutorStatItem(
                                          icon: '📢',
                                          value: '$announcementsCount',
                                          label: AppLanguage.t('announcements'),
                                          bgColor: const Color(0xFFFFF3E0),
                                          iconColor: _TutorColors.orange,
                                        ),
                                        _buildTutorStatItem(
                                          icon: '⭐',
                                          value: AppLanguage.t('senior'),
                                          label: AppLanguage.t('verified_tier'),
                                          bgColor: const Color(0xFFF3E5F5),
                                          iconColor: Colors.purple,
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card 2: Classroom Assignment Info
                      _buildTutorProfileCard(
                        title: AppLanguage.t('classroom_info'),
                        child: Column(
                          children: [
                            _buildClassroomRow(
                              label: AppLanguage.t('academy'),
                              value: AppLanguage.t('utm_full_name'),
                              icon: Icons.school_rounded,
                            ),
                            Divider(height: 1, color: context.borderTheme),
                            _buildClassroomRow(
                              label: AppLanguage.t('organization'),
                              value: AppLanguage.t('nexus_club_name'),
                              icon: Icons.group_work_rounded,
                            ),
                            Divider(height: 1, color: context.borderTheme),
                            _buildClassroomRow(
                              label: AppLanguage.t('course_code'),
                              value: 'NEXUS-MANDARIN-1',
                              icon: Icons.badge_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card 3: Dynamic Action Log Timeline (Recent Activity)
                      _buildTutorProfileCard(
                        title: AppLanguage.t('recent_activity_logs'),
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('announcements')
                              .orderBy('createdAt', descending: true)
                              .limit(1)
                              .snapshots(),
                          builder: (context, announcementSnapshot) {
                            final latestAnnDoc = announcementSnapshot.data?.docs.firstOrNull;
                            final latestAnnTitle = latestAnnDoc?.data()['title']?.toString() ?? AppLanguage.t('no_announcements_broadcasted');
                            final latestAnnContent = latestAnnDoc?.data()['content']?.toString() ?? '';

                            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('lessons')
                                  .orderBy('order', descending: true)
                                  .limit(1)
                                  .snapshots(),
                              builder: (context, lessonSnapshot) {
                                final latestLessonDoc = lessonSnapshot.data?.docs.firstOrNull;
                                final latestLessonTitle = latestLessonDoc?.data()['title']?.toString() ?? AppLanguage.t('no_lessons_published');

                                return Column(
                                  children: [
                                    _buildTutorActivityItem(
                                      icon: '📢',
                                      title: AppLanguage.t('latest_broadcast_sent'),
                                      detail: latestAnnTitle,
                                      time: latestAnnContent.isNotEmpty
                                          ? (latestAnnContent.length > 30 ? '${latestAnnContent.substring(0, 30)}...' : latestAnnContent)
                                          : AppLanguage.t('tap_announcements_broadcast'),
                                      bgColor: const Color(0xFFFFF3E0),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTutorActivityItem(
                                      icon: '📚',
                                      title: AppLanguage.t('latest_published_lesson'),
                                      detail: latestLessonTitle,
                                      time: AppLanguage.t('added_to_student_path'),
                                      bgColor: const Color(0xFFE3F2FD),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildTutorActivityItem(
                                      icon: '✅',
                                      title: AppLanguage.t('class_health_checklist'),
                                      detail: AppLanguage.t('all_db_online'),
                                      time: AppLanguage.t('nexus_club_active'),
                                      bgColor: const Color(0xFFE8F5E9),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Card 4: Navigation menu links
                      _buildTutorProfileCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _buildTutorNavigationRow(
                              icon: Icons.settings_rounded,
                              iconBg: const Color(0xFFE8F5E9),
                              iconColor: _TutorColors.green,
                              title: AppLanguage.t('app_settings'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                    const AppSettingsPage(
                                      roleColor: _TutorColors.green,
                                      role: 'tutor',
                                    ),
                                  ),
                                );
                              },
                            ),
                            Divider(height: 1, color: context.borderTheme),
                            _buildTutorNavigationRow(
                              icon: Icons.edit_note_rounded,
                              iconBg: const Color(0xFFE1F5FE),
                              iconColor: Colors.blue.shade700,
                              title: AppLanguage.t('edit_profile'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                    const mandarinmate_edit_profile.EditProfilePage(
                                      roleColor: _TutorColors.green,
                                    ),
                                  ),
                                );
                              },
                            ),
                            Divider(height: 1, color: context.borderTheme),
                            _buildTutorNavigationRow(
                              icon: Icons.class_rounded,
                              iconBg: const Color(0xFFE3F2FD),
                              iconColor: _TutorColors.blue,
                              title: AppLanguage.t('manage_lessons_hub'),
                              onTap: () {
                                setState(() => _currentIndex = 1);
                              },
                            ),
                            Divider(height: 1, color: context.borderTheme),
                            _buildTutorNavigationRow(
                              icon: Icons.people_alt_rounded,
                              iconBg: const Color(0xFFE0F2F1),
                              iconColor: Colors.teal,
                              title: AppLanguage.t('my_students_progress'),
                              onTap: () {
                                setState(() => _currentIndex = 2);
                              },
                            ),
                            Divider(height: 1, color: context.borderTheme),
                            _buildTutorNavigationRow(
                              icon: Icons.campaign_rounded,
                              iconBg: const Color(0xFFFFF3E0),
                              iconColor: _TutorColors.orange,
                              title: AppLanguage.t('broadcast_announcement'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TutorAnnouncementPage(),
                                  ),
                                );
                              },
                            ),
                            Divider(height: 1, color: context.borderTheme),
                            _buildTutorNavigationRow(
                              icon: Icons.forum_rounded,
                              iconBg: const Color(0xFFF3E5F5),
                              iconColor: const Color(0xFF9C27B0),
                              title: AppLanguage.t('community_forum_feed'),
                              onTap: () {
                                setState(() => _currentIndex = 4);
                              },
                            ),
                            Divider(height: 1, color: context.borderTheme),
                            _buildTutorNavigationRow(
                              icon: Icons.logout_rounded,
                              iconBg: const Color(0xFFFFF0F0),
                              iconColor: const Color(0xFFD32F2F),
                              title: AppLanguage.t('logout'),
                              onTap: () => _logout(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTutorProfileCard({
    required Widget child,
    String? title,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderTheme),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08111827),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Text(
                title,
                style: TextStyle(
                  color: context.textDeep,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildTutorStatItem({
    required String icon,
    required String value,
    required String label,
    required Color bgColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bgColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 20),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 8,
                color: iconColor.withValues(alpha: 0.6),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: context.textDeep,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassroomRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.isDarkMode ? const Color(0xFF1E332E) : const Color(0xFFF0F4F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _TutorColors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: context.textDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorActivityItem({
    required String icon,
    required String title,
    required String detail,
    required String time,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bgColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.cardBg,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              icon,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.textDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textDeep,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorNavigationRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: context.textDeep,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _onNavTapped(BuildContext context, int index) {
    setState(() => _currentIndex = index);
  }
}

class _TutorPageFrame extends StatelessWidget {
  const _TutorPageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.scaffoldBg, Color(0xFFEFF8F4)],
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
                '${AppLanguage.t('welcome')}, $name',
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
                AppLanguage.t('tutor_guide_desc'),
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
          role: 'tutor',
          themeColor: _TutorColors.green,
          iconColor: context.textDeep,
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
              backgroundColor: context.cardBg,
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
      color: context.cardBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderTheme),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textDeep,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
            style: TextStyle(
              color: context.textDeep,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(onPressed: onViewAll, child: Text(AppLanguage.t('view_all'))),
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

// -----------------------------------------------------
// TUTOR CLASSROOM STATS OVERVIEW COMPONENT
// -----------------------------------------------------

class _TutorClassroomOverview extends StatelessWidget {
  const _TutorClassroomOverview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderTheme),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08111827),
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
                  color: _TutorColors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school_rounded, color: _TutorColors.green, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                AppLanguage.t('classroom_stats_title'),
                style: TextStyle(
                  color: context.textDeep,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  context,
                  icon: Icons.cloud_done_rounded,
                  iconColor: Colors.green,
                  label: AppLanguage.t('server_status'),
                  value: AppLanguage.t('online'),
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  context,
                  icon: Icons.gpp_good_rounded,
                  iconColor: Colors.teal,
                  label: AppLanguage.t('firestore_db'),
                  value: AppLanguage.t('secure'),
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  context,
                  icon: Icons.code_rounded,
                  iconColor: Colors.blue,
                  label: AppLanguage.t('app_version'),
                  value: 'v1.2.0',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: context.textDeep, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// -----------------------------------------------------
// TUTOR CHECKLIST COMPONENT
// -----------------------------------------------------

class _TutorChecklistPanel extends StatefulWidget {
  const _TutorChecklistPanel();

  @override
  State<_TutorChecklistPanel> createState() => _TutorChecklistPanelState();
}

class _TutorChecklistPanelState extends State<_TutorChecklistPanel> {
  final List<Map<String, dynamic>> _tasks = [
    {'title': 'task_publish_vocab', 'done': false},
    {'title': 'task_broadcast_reminder', 'done': true},
    {'title': 'task_review_forum', 'done': false},
    {'title': 'task_audit_badges', 'done': false},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderTheme),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08111827),
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
                  color: _TutorColors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_turned_in_rounded, color: _TutorColors.teal, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                AppLanguage.t('weekly_teaching_tasks'),
                style: TextStyle(
                  color: context.textDeep,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tasks.length,
            itemBuilder: (context, index) {
              final task = _tasks[index];
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  AppLanguage.t(task['title']!),
                  style: TextStyle(
                    color: task['done'] ? context.textMuted : context.textDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: task['done'] ? TextDecoration.lineThrough : null,
                  ),
                ),
                value: task['done'],
                activeColor: _TutorColors.green,
                dense: true,
                onChanged: (val) {
                  setState(() {
                    _tasks[index]['done'] = val ?? false;
                  });
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------
// SMART CHAT BADGE COMPONENT
// -----------------------------------------------------
class _ChatBadgeIcon extends StatelessWidget {
  final IconData iconData;
  final Color? color;

  const _ChatBadgeIcon({required this.iconData, this.color});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return Icon(iconData, color: color);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('chats').snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;

            final participants = List<dynamic>.from(data['participants'] ?? const []);
            if (data['lastMessageSenderId'] != currentUser.uid &&
                data['isLastMessageRead'] == false &&
                participants.contains(currentUser.uid)) {
              unreadCount++;
            }
          }
        }

        return Badge(
          isLabelVisible: unreadCount > 0,
          backgroundColor: Colors.red,
          label: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
          child: Icon(iconData, color: color),
        );
      },
    );
  }
}