import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mandarinmate/services/notification_service.dart';
import 'package:mandarinmate/utils/app_theme.dart';

class InAppNotificationOverlay extends StatefulWidget {
  final String title;
  final String body;
  final String type;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const InAppNotificationOverlay({
    super.key,
    required this.title,
    required this.body,
    required this.type,
    required this.onTap,
    required this.onDismiss,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String body,
    required String type,
    required VoidCallback onTap,
  }) {
    if (!context.mounted) return;

    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => InAppNotificationOverlay(
        title: title,
        body: body,
        type: type,
        onTap: () {
          overlayEntry.remove();
          onTap();
        },
        onDismiss: () {
          overlayEntry.remove();
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }

  static StreamSubscription? subscribeToNotifications(
    BuildContext context, {
    required String role,
    required Color themeColor,
  }) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final isAdmin = role == 'admin';
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('notifications');

    if (isAdmin) {
      query = query.where('recipientId', whereIn: [uid, 'admin']);
    } else {
      query = query.where('recipientId', isEqualTo: uid);
    }

    final List<Map<String, dynamic>> queue = [];
    bool isProcessing = false;
    final Set<String> processedDocIds = {};
    bool prefsLoaded = false;
    final List<DocumentSnapshot<Map<String, dynamic>>> pendingDocs = [];

    void processDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
      final data = doc.data();
      if (data == null) return;

      if (processedDocIds.contains(doc.id)) return;

      // Exclude self-notifications
      final senderId = data['senderId'];
      if (senderId != null && senderId == uid) {
        return;
      }

      final isRead = data['isRead'] as bool? ?? false;
      if (isRead) return;

      processedDocIds.add(doc.id);
      
      // Save to SharedPreferences asynchronously
      SharedPreferences.getInstance().then((prefs) {
        final currentPopped = prefs.getStringList('popped_notifications') ?? [];
        if (!currentPopped.contains(doc.id)) {
          currentPopped.add(doc.id);
          prefs.setStringList('popped_notifications', currentPopped);
        }
      });

      final title = data['title'] ?? 'Notification';
      final body = data['body'] ?? '';
      final type = data['type'] ?? '';

      queue.add({
        'docId': doc.id,
        'title': title,
        'body': body,
        'type': type,
        ...data,
      });
    }

    void runQueue() async {
      if (isProcessing) return;
      isProcessing = true;

      while (queue.isNotEmpty) {
        final data = queue.removeAt(0);
        final title = data['title'] ?? 'Notification';
        final body = data['body'] ?? '';

        NotificationService.showLocalNotification(
          title: title,
          body: body,
          payload: jsonEncode(data),
        );

        await Future.delayed(const Duration(milliseconds: 800));
      }

      isProcessing = false;
    }

    // Load SharedPreferences first
    SharedPreferences.getInstance().then((prefs) {
      final poppedList = prefs.getStringList('popped_notifications') ?? [];
      processedDocIds.addAll(poppedList);
      prefsLoaded = true;

      if (pendingDocs.isNotEmpty) {
        for (var doc in pendingDocs) {
          processDoc(doc);
        }
        pendingDocs.clear();
        if (queue.isNotEmpty) {
          runQueue();
        }
      }
    });

    return query.snapshots().listen((snapshot) {
      final addedChanges = snapshot.docChanges
          .where((change) => change.type == DocumentChangeType.added)
          .toList();

      if (addedChanges.isEmpty) return;

      // Sort changes in chronological order (oldest first)
      addedChanges.sort((a, b) {
        final aTime = a.doc.data()?['createdAt'];
        final bTime = b.doc.data()?['createdAt'];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        DateTime aDate = (aTime is Timestamp) ? aTime.toDate() : DateTime.now();
        DateTime bDate = (bTime is Timestamp) ? bTime.toDate() : DateTime.now();
        return aDate.compareTo(bDate);
      });

      bool hasNew = false;
      for (var change in addedChanges) {
        final doc = change.doc;
        if (!prefsLoaded) {
          pendingDocs.add(doc);
        } else {
          processDoc(doc);
          hasNew = true;
        }
      }

      if (hasNew && queue.isNotEmpty) {
        runQueue();
      }
    }, onError: (e) {
      debugPrint('Error in notification subscription listener: $e');
    });
  }

  @override
  State<InAppNotificationOverlay> createState() => _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState extends State<InAppNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();

    _dismissTimer = Timer(const Duration(seconds: 4), () {
      _dismiss();
    });
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

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
        return Colors.blue;
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final iconColor = _getIconColorForType(widget.type);
    final iconData = _getIconForType(widget.type);

    return Positioned(
      top: mediaQuery.padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: SafeArea(
          top: false,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: context.cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: context.isDarkMode ? 0.3 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: iconColor.withValues(alpha: context.isDarkMode ? 0.3 : 0.15),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: widget.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            iconData,
                            color: iconColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: context.textDeep,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textMuted,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: context.isDarkMode ? Colors.white54 : Colors.grey.shade400,
                            size: 20,
                          ),
                          onPressed: _dismiss,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
