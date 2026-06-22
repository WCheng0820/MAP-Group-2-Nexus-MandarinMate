import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/screens/announcement_create_edit_page.dart';
import 'package:mandarinmate/utils/linkify_util.dart';
import 'package:mandarinmate/utils/app_theme.dart';

class TutorAnnouncementPage extends StatefulWidget {
  const TutorAnnouncementPage({super.key});

  @override
  State<TutorAnnouncementPage> createState() => _TutorAnnouncementPageState();
}

class _TutorAnnouncementPageState extends State<TutorAnnouncementPage> {
  static const Color _green = Color(0xFF0F6E56);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        backgroundColor: context.isDarkMode ? context.cardBg : _green,
        foregroundColor: context.isDarkMode ? context.textDeep : Colors.white,
        title: Text(
          'Announcements',
          style: TextStyle(
            color: context.isDarkMode ? context.textDeep : Colors.white,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AnnouncementCreateEditPage(
                role: 'tutor',
                themeColor: _green,
              ),
            ),
          );
        },
        backgroundColor: context.isDarkMode ? const Color(0xFF34D399) : _green,
        foregroundColor: context.isDarkMode ? Colors.black : Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Announcement'),
      ),
      body: user == null
          ? const Center(
              child: Text('Please log in again to manage announcements.'),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('announcements')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error loading announcements.'),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No announcements published yet.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: docs.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final announcementDoc = docs[index];
                    final data = announcementDoc.data();
                    final title = (data['title'] ?? '').toString();
                    final body = (data['body'] ?? '').toString();
                    final createdBy = (data['createdBy'] ?? '').toString();
                    final createdAt = data['createdAt'] is Timestamp
                        ? (data['createdAt'] as Timestamp).toDate()
                        : null;

                    final isAuthor = createdBy == user.uid;

                    return Card(
                      elevation: 0,
                      color: context.cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: context.borderTheme),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: context.textDeep,
                                    ),
                                  ),
                                ),
                                if (isAuthor) ...[
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    color: context.isDarkMode ? Colors.blue.shade300 : Colors.blue.shade600,
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AnnouncementCreateEditPage(
                                            role: 'tutor',
                                            themeColor: _green,
                                            docId: announcementDoc.id,
                                            initialTitle: title,
                                            initialBody: body,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: context.isDarkMode ? Colors.red.shade300 : Colors.red.shade400,
                                    onPressed: () => _confirmDeleteAnnouncement(
                                      context,
                                      announcementDoc.id,
                                      title,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            buildLinkifiableText(
                              body,
                              TextStyle(
                                color: context.textMuted,
                                fontSize: 14,
                                height: 1.4,
                              ),
                              TextStyle(
                                color: context.isDarkMode ? Colors.blue.shade300 : Colors.blue,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            if (createdAt != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.isDarkMode ? Colors.white30 : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  void _confirmDeleteAnnouncement(BuildContext context, String docId, String title) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogContext.cardBg,
        title: Text(
          'Delete Announcement',
          style: TextStyle(color: dialogContext.textDeep),
        ),
        content: Text(
          'Are you sure you want to delete "$title"?',
          style: TextStyle(color: dialogContext.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteAnnouncement(docId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAnnouncement(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(docId)
          .delete();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Announcement successfully deleted.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete announcement.')),
      );
    }
  }
}
