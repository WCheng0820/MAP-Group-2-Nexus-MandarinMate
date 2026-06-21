import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mandarinmate/screens/chat_screen.dart';
import 'package:mandarinmate/forum/presentation/pages/post_detail_page.dart';
import 'package:mandarinmate/lessons/presentation/pages/lessons_page.dart';
import 'package:mandarinmate/flashcards/presentation/pages/flashcard_levels_page.dart';
import 'package:mandarinmate/screens/student_announcement_page.dart';
import 'package:mandarinmate/tutor/presentation/pages/tutor_announcement_page.dart';
import 'package:mandarinmate/dashboard/admin_users_page.dart';
import 'package:mandarinmate/screens/main_screen.dart';

class NotificationListPage extends StatefulWidget {
  final String role; // 'student', 'tutor', or 'admin'
  final Color themeColor;

  const NotificationListPage({
    super.key,
    required this.role,
    required this.themeColor,
  });

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  IconData _getIconForType(String type) {
    switch (type) {
      case 'chat':
        return Icons.chat_rounded;
      case 'forum_like':
        return Icons.favorite_rounded;
      case 'forum_comment':
        return Icons.chat_bubble_rounded;
      case 'vocab_unit':
        return Icons.menu_book_rounded;
      case 'lesson_material':
        return Icons.school_rounded;
      case 'flashcards':
        return Icons.style_rounded;
      case 'announcement':
        return Icons.campaign_rounded;
      case 'tutor_registration':
        return Icons.person_add_rounded;
      case 'streak':
        return Icons.local_fire_department_rounded;
      case 'streak_missed':
        return Icons.error_outline_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getIconColorForType(String type) {
    switch (type) {
      case 'chat':
        return Colors.blueAccent;
      case 'forum_like':
        return Colors.redAccent;
      case 'forum_comment':
        return Colors.blue;
      case 'vocab_unit':
        return Colors.orange;
      case 'lesson_material':
        return Colors.green;
      case 'flashcards':
        return Colors.teal;
      case 'announcement':
        return Colors.amber;
      case 'tutor_registration':
        return Colors.purple;
      case 'streak':
        return Colors.orangeAccent;
      case 'streak_missed':
        return Colors.red;
      default:
        return widget.themeColor;
    }
  }

  void _handleNotificationRedirect(Map<String, dynamic> data) {
    final type = data['type'] ?? '';

    switch (type) {
      case 'chat':
        final chatId = data['chatId'] ?? '';
        final senderId = data['senderId'] ?? '';
        final senderName = data['senderName'] ?? 'Chat';
        if (chatId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                chatId: chatId,
                receiverId: senderId,
                receiverName: senderName,
              ),
            ),
          );
        }
        break;
      case 'forum_like':
      case 'forum_comment':
        final postId = data['postId'] ?? '';
        if (postId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailPage(
                postId: postId,
                themeColor: widget.themeColor,
              ),
            ),
          );
        }
        break;
      case 'vocab_unit':
      case 'lesson_material':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LessonsPage(),
          ),
        );
        break;
      case 'flashcards':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const FlashcardLevelsPage(),
          ),
        );
        break;
      case 'announcement':
        if (widget.role == 'student') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StudentAnnouncementPage(),
            ),
          );
        } else if (widget.role == 'tutor') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TutorAnnouncementPage(),
            ),
          );
        }
        break;
      case 'tutor_registration':
        if (widget.role == 'admin') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminUsersPage(),
            ),
          );
        }
        break;
      case 'streak':
      case 'streak_missed':
        if (widget.role == 'student') {
          MainScreen.openDailyChallenge(context);
        }
        break;
      default:
        break;
    }
  }

  Future<void> _markAsRead(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(docId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _deleteNotification(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(docId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> _markAllAsRead(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final batch = FirebaseFirestore.instance.batch();
    var hasUpdates = false;

    for (var doc in docs) {
      if (doc.data()['isRead'] == false) {
        batch.update(doc.reference, {'isRead': true});
        hasUpdates = true;
      }
    }

    if (hasUpdates) {
      try {
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All notifications marked as read.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error marking all as read: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.role == 'admin';

    // Stream queries
    Stream<QuerySnapshot<Map<String, dynamic>>> notifStream;
    if (isAdmin) {
      notifStream = FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', whereIn: [uid, 'admin'])
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      notifStream = FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C2433),
        elevation: 0,
        centerTitle: true,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFECEFF1), width: 1),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: notifStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final unreadCount = docs.where((doc) => doc.data()['isRead'] == false).length;

          return Column(
            children: [
              if (docs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        unreadCount > 0 ? '$unreadCount unread' : 'All caught up',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: unreadCount > 0 ? () => _markAllAsRead(docs) : null,
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text(
                          'Mark all read',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: widget.themeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: widget.themeColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.notifications_none_rounded,
                                size: 40,
                                color: widget.themeColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Notifications Yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1C2433),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'We\'ll notify you when something updates!',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: docs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          final title = data['title'] ?? 'Notification';
                          final body = data['body'] ?? '';
                          final type = data['type'] ?? '';
                          final isRead = data['isRead'] == true;
                          final createdAt = data['createdAt'] is Timestamp
                              ? (data['createdAt'] as Timestamp).toDate()
                              : DateTime.now();

                          return Dismissible(
                            key: Key(doc.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Delete Notification'),
                                  content: const Text('Are you sure you want to delete this notification?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogContext, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => Navigator.pop(dialogContext, true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              ) ?? false;
                            },
                            onDismissed: (_) => _deleteNotification(doc.id),
                            child: InkWell(
                              onTap: () {
                                if (!isRead) {
                                  _markAsRead(doc.id);
                                }
                                _handleNotificationRedirect(data);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isRead ? Colors.grey.shade200 : widget.themeColor.withValues(alpha: 0.3),
                                    width: isRead ? 1 : 1.5,
                                  ),
                                  boxShadow: isRead
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: widget.themeColor.withValues(alpha: 0.04),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: _getIconColorForType(type).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        _getIconForType(type),
                                        color: _getIconColorForType(type),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: isRead ? FontWeight.bold : FontWeight.w900,
                                                    color: const Color(0xFF1C2433),
                                                  ),
                                                ),
                                              ),
                                              if (!isRead)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: widget.themeColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            body,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                              height: 1.35,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            DateFormat('MMM dd, hh:mm a').format(createdAt),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade400,
                                              fontWeight: FontWeight.w500,
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
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
