import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mandarinmate/auth/presentation/bloc/auth_bloc.dart';
import 'package:mandarinmate/dashboard/admin_badge_config_page.dart';
import 'package:mandarinmate/screens/profile/app_settings_page.dart';
import 'package:mandarinmate/screens/profile/edit_profile_page.dart' as mandarinmate_edit_profile;
import 'package:mandarinmate/utils/app_theme.dart';
import 'package:mandarinmate/utils/app_language.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  final Color _primaryColor = const Color(0xFF7B1FA2);

  String _displayName(Map<String, dynamic> data) {
    final name = data['name'];
    final firstName = data['firstName'];
    final lastName = data['lastName'];
    if (name is String && name.isNotEmpty) return name;
    if (firstName is String || lastName is String) {
      return '${firstName ?? ''} ${lastName ?? ''}'.trim();
    }
    return 'Admin User';
  }

  void _handleLogout(BuildContext context) {
    context.read<AuthBloc>().add(AuthLogoutRequested());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLanguage.t('logout_msg')),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: uid == null
            ? null
            : FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final name = _displayName(data);
          final String profileImageUrl = data['profileImageUrl'] ?? '';
          final email = (data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '').toString();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Purple Gradient Header Card
                Container(
                  padding: EdgeInsets.fromLTRB(20, statusBarHeight + 16, 20, 28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: context.isDarkMode
                          ? [const Color(0xFF5E1480), const Color(0xFF3B0B54)]
                          : [const Color(0xFF7B1FA2), const Color(0xFF4A148C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Header title & Settings/Logout buttons
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
                                      builder: (_) => AppSettingsPage(
                                        roleColor: _primaryColor,
                                        role: 'admin',
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
                                onPressed: () => _handleLogout(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Avatar with Edit Button Overlay
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
                                    name.isEmpty ? 'A' : name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: _primaryColor,
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
                                    builder: (_) => mandarinmate_edit_profile.EditProfilePage(
                                      roleColor: _primaryColor,
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
                                child: Icon(
                                  Icons.edit_rounded,
                                  color: _primaryColor,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Admin name
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
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Admin Role Badge Chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withOpacity(0.16)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppLanguage.t('admin_role'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Profile Body Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                  child: Column(
                    children: [
                      // Overview Panel (Statistics Grid)
                      _buildProfileCard(
                        context,
                        title: AppLanguage.t('overview_panel'),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('users').snapshots(),
                          builder: (context, userSnapshot) {
                            final docs = userSnapshot.data?.docs ?? [];
                            final managedCount = docs.where((doc) {
                              final role = (doc.data() as Map<String, dynamic>?)?['role']?.toString().toLowerCase() ?? '';
                              return role == 'student' || role == 'tutor';
                            }).length;

                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('lessons').snapshots(),
                              builder: (context, lessonsSnapshot) {
                                final totalLessons = lessonsSnapshot.data?.docs.length ?? 0;

                                return StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance.collection('announcements').snapshots(),
                                  builder: (context, announcementsSnapshot) {
                                    final totalAnnouncements = announcementsSnapshot.data?.docs.length ?? 0;

                                    return GridView.count(
                                      crossAxisCount: 2,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 1.15,
                                      children: [
                                        _buildAdminStatItem(
                                          context,
                                          icon: '👥',
                                          value: '$managedCount',
                                          label: AppLanguage.t('users_managed'),
                                          bgColor: const Color(0xFFE8F5E9),
                                          iconColor: Colors.green,
                                        ),
                                        _buildAdminStatItem(
                                          context,
                                          icon: '📚',
                                          value: '$totalLessons',
                                          label: AppLanguage.t('lessons_active'),
                                          bgColor: const Color(0xFFE3F2FD),
                                          iconColor: Colors.blue,
                                        ),
                                        _buildAdminStatItem(
                                          context,
                                          icon: '📢',
                                          value: '$totalAnnouncements',
                                          label: AppLanguage.t('announcements'),
                                          bgColor: const Color(0xFFFFF3E0),
                                          iconColor: Colors.orange,
                                        ),
                                        _buildAdminStatItem(
                                          context,
                                          icon: '🛡️',
                                          value: AppLanguage.t('online'),
                                          label: AppLanguage.t('system_status'),
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

                      // System Management Shortcuts
                      _buildProfileCard(
                        context,
                        title: AppLanguage.t('system_management'),
                        child: Column(
                          children: [
                            _buildMenuTile(
                              context,
                              icon: Icons.military_tech_rounded,
                              iconColor: _primaryColor,
                              title: AppLanguage.t('badge_config'),
                              subtitle: AppLanguage.t('badge_thresholds'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminBadgeConfigPage(),
                                  ),
                                );
                              },
                            ),
                            Divider(height: 1, color: context.borderTheme),
                            _buildMenuTile(
                              context,
                              icon: Icons.settings_rounded,
                              iconColor: const Color(0xFF5F6368),
                              title: AppLanguage.t('pref_theme'),
                              subtitle: AppLanguage.t('pref_theme_sub'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AppSettingsPage(
                                      roleColor: _primaryColor,
                                      role: 'admin',
                                    ),
                                  ),
                                );
                              },
                            ),
                            Divider(height: 1, color: context.borderTheme),
                            _buildMenuTile(
                              context,
                              icon: Icons.logout_rounded,
                              iconColor: const Color(0xFFD32F2F),
                              title: AppLanguage.t('logout_title'),
                              subtitle: AppLanguage.t('logout_sub'),
                              onTap: () => _handleLogout(context),
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

  Widget _buildProfileCard(BuildContext context, {required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderTheme),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode ? Colors.black26 : Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: context.textDeep,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildAdminStatItem(
    BuildContext context, {
    required String icon,
    required String value,
    required String label,
    required Color bgColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.isDarkMode ? const Color(0xFF261835) : bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDarkMode ? context.borderTheme : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: context.textDeep,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: context.textDeep,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: context.textMuted,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.textMuted,
      ),
      onTap: onTap,
    );
  }
}
