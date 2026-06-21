import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mandarinmate/auth/presentation/bloc/auth_bloc.dart';
import 'package:mandarinmate/auth/presentation/pages/login_page.dart';
import 'package:mandarinmate/main.dart';
import 'package:mandarinmate/utils/app_theme.dart';
import 'package:mandarinmate/utils/app_language.dart';
import 'edit_profile_page.dart';

class AppSettingsPage extends StatefulWidget {
  final Color roleColor;
  final String role; // 'student' or 'tutor'

  const AppSettingsPage({
    super.key,
    required this.roleColor,
    required this.role,
  });

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  // Settings values
  bool _pushNotifications = true;
  bool _dailyReminder = true;
  bool _streakAlert = true;
  bool _leaderboardUpdates = false;

  bool _soundEffects = true;
  bool _showChineseCharacters = true;
  bool _showPinyin = true;
  int _dailyGoalXp = 50;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 19, minute: 0);

  // Tutor specific settings
  bool _autoSaveDrafts = true;
  bool _pinyinInCreator = true;
  bool _weeklyClassReport = true;

  bool _darkMode = false;
  String _language = 'English';

  bool _isLoadingSettings = true;

  // User profile variables
  String _name = '';
  String _email = '';
  String _profileImageUrl = '';
  int _userXp = 0;
  int _userLevel = 1;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadUserProfile();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _pushNotifications = prefs.getBool('push_notifications') ?? true;
        _dailyReminder = prefs.getBool('daily_reminder') ?? true;
        _streakAlert = prefs.getBool('streak_alert') ?? true;
        _leaderboardUpdates = prefs.getBool('leaderboard_updates') ?? false;

        _soundEffects = prefs.getBool('sound_effects') ?? true;
        _showChineseCharacters = prefs.getBool('show_chinese_characters') ?? true;
        _showPinyin = prefs.getBool('show_pinyin') ?? true;
        _dailyGoalXp = prefs.getInt('daily_goal_xp') ?? 50;

        final reminderHour = prefs.getInt('reminder_time_hour') ?? 19;
        final reminderMin = prefs.getInt('reminder_time_minute') ?? 0;
        _reminderTime = TimeOfDay(hour: reminderHour, minute: reminderMin);

        _autoSaveDrafts = prefs.getBool('auto_save_drafts') ?? true;
        _pinyinInCreator = prefs.getBool('pinyin_in_creator') ?? true;
        _weeklyClassReport = prefs.getBool('weekly_class_report') ?? true;

        _darkMode = prefs.getBool('dark_mode') ?? false;
        _language = prefs.getString('language') ?? 'English';

        _isLoadingSettings = false;
      });
    }
  }

  Future<void> _saveSettingBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveSettingInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<void> _saveSettingString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        setState(() {
          _name = (data['name'] ?? data['firstName'] ?? 'User').toString();
          _email = (data['email'] ?? user.email ?? '').toString();
          _profileImageUrl = (data['profileImageUrl'] ?? '').toString();

          final xpVal = data['xp'] ?? data['xpPoints'] ?? 0;
          _userXp = xpVal is num ? xpVal.toInt() : 0;
          _userLevel = (_userXp ~/ 250) + 1;
        });
      }
    }
  }

  void _logout() {
    context.read<AuthBloc>().add(AuthLogoutRequested());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logout successful'),
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

  void _showDailyGoalDialog() {
    final goals = [10, 30, 50, 100];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.cardBg,
          title: Text(AppLanguage.t('daily_goal'), style: TextStyle(color: context.textDeep)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: goals.map((goal) {
              return ListTile(
                title: Text('$goal XP', style: TextStyle(color: context.textDeep)),
                leading: Radio<int>(
                  value: goal,
                  groupValue: _dailyGoalXp,
                  activeColor: widget.roleColor,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _dailyGoalXp = val);
                      _saveSettingInt('daily_goal_xp', val);
                      Navigator.pop(context);
                    }
                  },
                ),
                onTap: () {
                  setState(() => _dailyGoalXp = goal);
                  _saveSettingInt('daily_goal_xp', goal);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _selectReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: widget.roleColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _reminderTime) {
      setState(() => _reminderTime = picked);
      await _saveSettingInt('reminder_time_hour', picked.hour);
      await _saveSettingInt('reminder_time_minute', picked.minute);
    }
  }

  void _showLanguageDialog() {
    final languages = ['English', 'Bahasa Melayu', '中文'];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.cardBg,
          title: Text(AppLanguage.t('language'), style: TextStyle(color: context.textDeep)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: languages.map((lang) {
              return ListTile(
                title: Text(lang, style: TextStyle(color: context.textDeep)),
                leading: Radio<String>(
                  value: lang,
                  groupValue: _language,
                  activeColor: widget.roleColor,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _language = val);
                      _saveSettingString('language', val);
                      AppLanguage.languageNotifier.value = val;
                      Navigator.pop(context);
                    }
                  },
                ),
                onTap: () {
                  setState(() => _language = lang);
                  _saveSettingString('language', lang);
                  AppLanguage.languageNotifier.value = lang;
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showPrivacyPolicy() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: context.cardBg,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLanguage.t('privacy_settings'),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textDeep),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your privacy is our priority. In MandarinMate, we only collect essential usage statistics to optimize your learning path. We never share your credentials or speech samples with third-party service providers without your explicit consent.',
                    style: TextStyle(fontSize: 14, height: 1.5, color: context.textMuted),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Active Data Storage:',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: context.textDeep),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• Firestore Database (XP progression, streaks, completed lessons)\n• Supabase Storage (Profile photos, vocabulary materials)\n• Local cache (Shared preferences toggles)',
                    style: TextStyle(fontSize: 14, height: 1.5, color: context.textMuted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showHelpSupport() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: context.cardBg,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLanguage.t('help_support'),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: context.textDeep),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'MandarinMate Support Center',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textDeep),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'For technical assistance, feedback, or content issues, feel free to contact us:',
                    style: TextStyle(fontSize: 14, height: 1.4, color: context.textMuted),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '📧 Email: support@mandarinmate.utm.my\n📍 Office: Nexus Mandarin Club, UTM Johor Bahru',
                    style: TextStyle(fontSize: 14, height: 1.5, color: context.textMuted),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Frequently Asked Questions (FAQ)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textDeep),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Q: How does the Daily Challenge work?\n'
                    'A: Complete a short randomized quiz daily to earn extra XP and secure your learning streak!\n\n'
                    'Q: How can I change my email address?\n'
                    'A: Email adjustments require administrator approval. Contact support for official updates.',
                    style: TextStyle(fontSize: 13, height: 1.4, color: context.textMuted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    final minuteStr = tod.minute.toString().padLeft(2, '0');
    return '$hour:$minuteStr $period';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSettings) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLanguage.t('app_settings')),
          backgroundColor: widget.roleColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Column(
        children: [
          // Elegant Header
          Container(
            padding: EdgeInsets.fromLTRB(8, statusBarHeight + 8, 16, 12),
            color: context.cardBg,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.textDeep, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Text(
                  AppLanguage.t('app_settings'),
                  style: TextStyle(
                    color: context.textDeep,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // Profile Card Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFFFFD54F),
                        backgroundImage: _profileImageUrl.isNotEmpty
                            ? NetworkImage(_profileImageUrl)
                            : null,
                        child: _profileImageUrl.isEmpty
                            ? Text(
                                _name.isEmpty ? 'U' : _name[0].toUpperCase(),
                                style: TextStyle(
                                  color: widget.roleColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 24,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: context.textDeep,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _email,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.role == 'student'
                                  ? '🎓 Student · Level $_userLevel'
                                  : '🏫 Educator · Nexus Mandarin Club',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.roleColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditProfilePage(
                                roleColor: widget.roleColor,
                              ),
                            ),
                          ).then((_) => _loadUserProfile());
                        },
                        child: Text(
                          AppLanguage.t('edit'),
                          style: TextStyle(
                            color: widget.roleColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // NOTIFICATIONS Section
                _buildSectionHeader(AppLanguage.t('sec_notifications')),
                _buildCardGroup([
                  _buildSwitchTile(
                    icon: Icons.notifications_rounded,
                    iconColor: Colors.pink,
                    bgColor: Colors.pink.shade50,
                    title: AppLanguage.t('push_notifications'),
                    subtitle: AppLanguage.t('send_push_updates'),
                    value: _pushNotifications,
                    onChanged: (val) {
                      setState(() => _pushNotifications = val);
                      _saveSettingBool('push_notifications', val);
                    },
                  ),
                  _buildSwitchTile(
                    icon: Icons.alarm_rounded,
                    iconColor: Colors.orange.shade700,
                    bgColor: Colors.orange.shade50,
                    title: AppLanguage.t('daily_reminder'),
                    subtitle: AppLanguage.t('remind_study_daily'),
                    value: _dailyReminder,
                    onChanged: (val) {
                      setState(() => _dailyReminder = val);
                      _saveSettingBool('daily_reminder', val);
                    },
                  ),
                  _buildSwitchTile(
                    icon: Icons.flash_on_rounded,
                    iconColor: Colors.red.shade700,
                    bgColor: Colors.red.shade50,
                    title: AppLanguage.t('streak_alert'),
                    subtitle: AppLanguage.t('alert_streak_broken'),
                    value: _streakAlert,
                    onChanged: (val) {
                      setState(() => _streakAlert = val);
                      _saveSettingBool('streak_alert', val);
                    },
                  ),
                  _buildSwitchTile(
                    icon: Icons.emoji_events_rounded,
                    iconColor: Colors.purple.shade700,
                    bgColor: Colors.purple.shade50,
                    title: AppLanguage.t('leaderboard_updates'),
                    subtitle: AppLanguage.t('notify_rank_updates'),
                    value: _leaderboardUpdates,
                    onChanged: (val) {
                      setState(() => _leaderboardUpdates = val);
                      _saveSettingBool('leaderboard_updates', val);
                    },
                  ),
                ]),
                const SizedBox(height: 20),

                // LEARNING / TEACHING Section
                _buildSectionHeader(widget.role == 'student' ? AppLanguage.t('sec_learning') : AppLanguage.t('sec_teaching')),
                _buildCardGroup(widget.role == 'student'
                    ? [
                        _buildSwitchTile(
                          icon: Icons.volume_up_rounded,
                          iconColor: Colors.blue.shade700,
                          bgColor: Colors.blue.shade50,
                          title: AppLanguage.t('sound_effects'),
                          subtitle: AppLanguage.t('audio_cues_exercises'),
                          value: _soundEffects,
                          onChanged: (val) {
                            setState(() => _soundEffects = val);
                            _saveSettingBool('sound_effects', val);
                          },
                        ),
                        _buildSwitchTile(
                          icon: Icons.language_rounded,
                          iconColor: Colors.green.shade700,
                          bgColor: Colors.green.shade50,
                          title: AppLanguage.t('show_chinese_chars'),
                          subtitle: AppLanguage.t('show_chars_in_cards'),
                          value: _showChineseCharacters,
                          onChanged: (val) {
                            setState(() => _showChineseCharacters = val);
                            _saveSettingBool('show_chinese_characters', val);
                          },
                        ),
                        _buildSwitchTile(
                          icon: Icons.abc_rounded,
                          iconColor: Colors.deepPurple.shade700,
                          bgColor: Colors.deepPurple.shade50,
                          title: AppLanguage.t('show_pinyin'),
                          subtitle: AppLanguage.t('show_pronunciation_guides'),
                          value: _showPinyin,
                          onChanged: (val) {
                            setState(() => _showPinyin = val);
                            _saveSettingBool('show_pinyin', val);
                          },
                        ),
                        _buildNavigationTile(
                          icon: Icons.phone_android_rounded,
                          iconColor: Colors.orange.shade700,
                          bgColor: Colors.orange.shade50,
                          title: AppLanguage.t('daily_goal'),
                          subtitle: AppLanguage.t('daily_goal_sub'),
                          valueText: '$_dailyGoalXp XP',
                          onTap: _showDailyGoalDialog,
                        ),
                        _buildNavigationTile(
                          icon: Icons.alarm_on_rounded,
                          iconColor: Colors.pink.shade700,
                          bgColor: Colors.pink.shade50,
                          title: AppLanguage.t('reminder_time'),
                          subtitle: AppLanguage.t('reminder_time_sub'),
                          valueText: _formatTimeOfDay(_reminderTime),
                          onTap: _selectReminderTime,
                        ),
                      ]
                    : [
                        _buildSwitchTile(
                          icon: Icons.volume_up_rounded,
                          iconColor: Colors.blue.shade700,
                          bgColor: Colors.blue.shade50,
                          title: AppLanguage.t('sound_effects'),
                          subtitle: AppLanguage.t('audio_cues_exercises'),
                          value: _soundEffects,
                          onChanged: (val) {
                            setState(() => _soundEffects = val);
                            _saveSettingBool('sound_effects', val);
                          },
                        ),
                        _buildSwitchTile(
                          icon: Icons.save_rounded,
                          iconColor: Colors.teal.shade700,
                          bgColor: Colors.teal.shade50,
                          title: AppLanguage.t('tutor_auto_save'),
                          subtitle: AppLanguage.t('tutor_auto_save_sub'),
                          value: _autoSaveDrafts,
                          onChanged: (val) {
                            setState(() => _autoSaveDrafts = val);
                            _saveSettingBool('auto_save_drafts', val);
                          },
                        ),
                        _buildSwitchTile(
                          icon: Icons.spellcheck_rounded,
                          iconColor: Colors.purple.shade700,
                          bgColor: Colors.purple.shade50,
                          title: AppLanguage.t('tutor_pinyin_creator'),
                          subtitle: AppLanguage.t('tutor_pinyin_creator_sub'),
                          value: _pinyinInCreator,
                          onChanged: (val) {
                            setState(() => _pinyinInCreator = val);
                            _saveSettingBool('pinyin_in_creator', val);
                          },
                        ),
                        _buildSwitchTile(
                          icon: Icons.bar_chart_rounded,
                          iconColor: Colors.indigo.shade700,
                          bgColor: Colors.indigo.shade50,
                          title: AppLanguage.t('tutor_weekly_report'),
                          subtitle: AppLanguage.t('tutor_weekly_report_sub'),
                          value: _weeklyClassReport,
                          onChanged: (val) {
                            setState(() => _weeklyClassReport = val);
                            _saveSettingBool('weekly_class_report', val);
                          },
                        ),
                      ]),
                const SizedBox(height: 20),

                // APPEARANCE Section
                _buildSectionHeader(AppLanguage.t('sec_appearance')),
                _buildCardGroup([
                  _buildSwitchTile(
                    icon: Icons.dark_mode_rounded,
                    iconColor: Colors.blueGrey.shade800,
                    bgColor: Colors.blueGrey.shade50,
                    title: AppLanguage.t('dark_mode'),
                    subtitle: AppLanguage.t('theme_sub'),
                    value: _darkMode,
                    onChanged: (val) {
                      setState(() => _darkMode = val);
                      _saveSettingBool('dark_mode', val);
                      MyApp.themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val ? 'Dark mode enabled.' : 'Light mode enabled.'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  _buildNavigationTile(
                    icon: Icons.g_translate_rounded,
                    iconColor: Colors.blue.shade700,
                    bgColor: Colors.blue.shade50,
                    title: AppLanguage.t('language'),
                    valueText: _language,
                    onTap: _showLanguageDialog,
                  ),
                ]),
                const SizedBox(height: 20),

                // ACCOUNT Section
                _buildSectionHeader(AppLanguage.t('sec_account')),
                _buildCardGroup([
                  _buildNavigationTile(
                    icon: Icons.person_rounded,
                    iconColor: Colors.red.shade700,
                    bgColor: Colors.red.shade50,
                    title: AppLanguage.t('edit_profile'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfilePage(
                            roleColor: widget.roleColor,
                          ),
                        ),
                      ).then((_) => _loadUserProfile());
                    },
                  ),
                  _buildNavigationTile(
                    icon: Icons.security_rounded,
                    iconColor: Colors.grey.shade700,
                    bgColor: Colors.grey.shade100,
                    title: AppLanguage.t('privacy_settings'),
                    onTap: _showPrivacyPolicy,
                  ),
                  _buildNavigationTile(
                    icon: Icons.help_outline_rounded,
                    iconColor: Colors.blue.shade700,
                    bgColor: Colors.blue.shade50,
                    title: AppLanguage.t('help_support'),
                    onTap: _showHelpSupport,
                  ),
                ]),
                const SizedBox(height: 32),

                // Log Out Button
                ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFD32F2F)),
                  label: Text(
                    AppLanguage.t('logout'),
                    style: TextStyle(
                      color: Color(0xFFD32F2F),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF0F0),
                    foregroundColor: const Color(0xFFD32F2F),
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFFFFCDD2)),
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Footer version & organization details
                const Text(
                  'MandarinMate UTM v2.0.1\nUniversiti Teknologi Malaysia © 2026',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.grey,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildCardGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: List.generate(children.length * 2 - 1, (index) {
            if (index.isOdd) {
              return Divider(height: 1, color: context.borderTheme);
            }
            return children[index ~/ 2];
          }),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: context.textDeep,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: widget.roleColor,
            activeTrackColor: widget.roleColor.withValues(alpha: 0.5),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    String? subtitle,
    String? valueText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.textDeep,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            if (valueText != null) ...[
              Text(
                valueText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14),
          ],
        ),
      ),
    );
  }
}
