import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  final Map<String, TextEditingController> controllers = {};
  bool isLoading = true;
  bool isSaving = false;
  String? saveMessage;
  String userName = '';
  String userEmail = '';
  String? profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadBadgeConfigsForEditing();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (mounted) {
          setState(() {
            userName = userDoc.data()?['name'] ?? 'Admin User';
            userEmail = user.email ?? 'No email';
            profilePhotoUrl = userDoc.data()?['profilePhotoUrl'];
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logout successful'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadBadgeConfigsForEditing() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('badges_config')
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final badgeId = doc.id;
        final fields = _getFieldsForBadge(badgeId);

        for (var field in fields) {
          final key = '${badgeId}_$field';
          controllers[key] = TextEditingController(
            text: data[field]?.toString() ?? '',
          );
        }
      }
      if (mounted) {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error loading configs: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  List<String> _getFieldsForBadge(String badgeId) {
    switch (badgeId) {
      case 'streak_7':
        return ['streakThreshold'];
      case 'first_lesson':
        return ['xpThreshold'];
      case 'perfect_score':
      case 'speed_learner':
      case 'speaker':
        return ['xpThreshold', 'lessonThreshold'];
      case 'bookworm':
        return ['lessonThreshold'];
      case 'top_learner':
        return ['xpThreshold'];
      case 'graduate':
        return ['lessonThreshold', 'levelThreshold'];
      default:
        return [];
    }
  }

  Future<void> _saveBadgeConfigs() async {
    try {
      setState(() => isSaving = true);

      final badgeIds = [
        'streak_7',
        'first_lesson',
        'perfect_score',
        'speed_learner',
        'speaker',
        'bookworm',
        'top_learner',
        'graduate',
      ];

      for (var badgeId in badgeIds) {
        final data = <String, dynamic>{};
        final fields = _getFieldsForBadge(badgeId);

        for (var field in fields) {
          final key = '${badgeId}_$field';
          final value = int.tryParse(controllers[key]?.text ?? '0') ?? 0;
          data[field] = value;
        }

        await FirebaseFirestore.instance
            .collection('badges_config')
            .doc(badgeId)
            .set(data, SetOptions(merge: true));
      }

      if (mounted) {
        setState(() {
          isSaving = false;
          saveMessage = '✓ Saved successfully!';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Badge configurations saved!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => saveMessage = null);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isSaving = false;
          saveMessage = '✗ Error: $e';
        });
      }
    }
  }

  String _getFieldLabel(String field) {
    switch (field) {
      case 'xpThreshold':
        return 'XP Required';
      case 'lessonThreshold':
        return 'Lessons Required';
      case 'streakThreshold':
        return 'Streak Days Required';
      case 'levelThreshold':
        return 'Level Required';
      default:
        return field;
    }
  }

  @override
  void dispose() {
    for (var controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7B1FA2)),
          ),
        ),
      );
    }

    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Purple Gradient Header
            Container(
              padding: EdgeInsets.fromLTRB(20, statusBarHeight + 16, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7B1FA2), Color(0xFF9C27B0)],
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
                  // Header: Profile Title
                  const Text(
                    'Admin Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Profile Avatar
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: const Color(0xFFE1BEE7),
                    child:
                        profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              profilePhotoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Text(
                                  userName.isEmpty
                                      ? 'A'
                                      : userName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF7B1FA2),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 36,
                                  ),
                                );
                              },
                            ),
                          )
                        : Text(
                            userName.isEmpty ? 'A' : userName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFF7B1FA2),
                              fontWeight: FontWeight.w900,
                              fontSize: 36,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  // Display Name
                  Text(
                    userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Email
                  Text(
                    userEmail,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Admin Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: const Text(
                      '👑 Administrator',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Logout'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Badge Configuration Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Badge Unlock Thresholds',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Edit the values below to adjust when badges unlock for students.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF718096),
                          ),
                        ),
                        if (saveMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            saveMessage!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: saveMessage!.startsWith('✓')
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ..._buildEditFields(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _saveBadgeConfigs,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B1FA2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save All Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEditFields() {
    final badges = [
      (
        'streak_7',
        '🔥',
        '7-Day Streak',
        'Vibrant focus! Unlocked by keeping up a daily study routine.',
      ),
      (
        'first_lesson',
        '⭐',
        'First Lesson',
        'First steps! Unlocked by starting your Mandarin adventure.',
      ),
      (
        'perfect_score',
        '🎯',
        'Perfect Score',
        'Bullseye! Unlocked by showing complete mastery in your quiz.',
      ),
      (
        'speed_learner',
        '⚡',
        'Speed Learner',
        'Lightning fast! Unlocked by practicing vocabulary with high speed.',
      ),
      (
        'speaker',
        '🗣️',
        'Speaker',
        'Vocal maestro! Unlocked by recording speech and passing pronunciation checkpoints.',
      ),
      (
        'bookworm',
        '📚',
        'Bookworm',
        'Book lover! Unlocked by expanding your knowledge base extensively.',
      ),
      (
        'top_learner',
        '🏆',
        'Top Learner',
        'Peak performance! Unlocked by climbing to the absolute top.',
      ),
      (
        'graduate',
        '🎓',
        'Graduate',
        'Milestone achieved! Unlocked by finishing the overall course material.',
      ),
    ];

    return badges.map((badge) {
      final (badgeId, icon, title, description) = badge;
      final fields = _getFieldsForBadge(badgeId);

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF718096),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...fields.map((field) {
              final key = '${badgeId}_$field';
              final label = _getFieldLabel(field);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF718096),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: controllers[key],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      );
    }).toList();
  }
}
