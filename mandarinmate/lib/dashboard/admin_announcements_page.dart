import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/screens/announcement_create_edit_page.dart';
import 'package:mandarinmate/utils/linkify_util.dart';
import 'package:mandarinmate/utils/app_theme.dart';

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});

  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  static const Color _primary = Color(0xFF6C3BFF);
  static const Color _surface = Color(0xFFF6F3FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Admin Announcements',
          style: TextStyle(
            color: context.isDarkMode ? context.textDeep : Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: context.isDarkMode ? context.cardBg : _primary,
        foregroundColor: context.isDarkMode ? context.textDeep : Colors.white,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AnnouncementCreateEditPage(
                role: 'admin',
                themeColor: _primary,
              ),
            ),
          );
        },
        backgroundColor: context.isDarkMode ? const Color(0xFF8B5CF6) : _primary,
        foregroundColor: context.isDarkMode ? Colors.black : Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Announcement'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Failed to load announcements.'),
            );
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('No announcements yet.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final title = (data['title'] ?? '').toString();
              final body = (data['body'] ?? '').toString();
              final targetRole = (data['targetRole'] ?? 'all').toString();
              final createdByName = (data['createdByName'] ?? '').toString();
              final createdAt = data['createdAt'] is Timestamp
                  ? (data['createdAt'] as Timestamp).toDate()
                  : null;

              return Container(
                decoration: BoxDecoration(
                  color: context.cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderTheme),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.textDeep,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      buildLinkifiableText(
                        body,
                        TextStyle(
                          color: context.textMuted,
                          fontSize: 14,
                        ),
                        TextStyle(
                          color: context.isDarkMode ? Colors.blue.shade300 : _primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _Badge(text: targetRole.toUpperCase()),
                          if (createdByName.isNotEmpty)
                            _Badge(text: createdByName),
                          if (createdAt != null)
                            _Badge(text: _formatDate(createdAt)),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        color: context.isDarkMode ? Colors.blue.shade300 : Colors.blue.shade600,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AnnouncementCreateEditPage(
                                role: 'admin',
                                themeColor: _primary,
                                docId: doc.id,
                                initialTitle: title,
                                initialBody: body,
                                initialTargetRole: targetRole,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: context.isDarkMode ? Colors.red.shade300 : Colors.red.shade400,
                        onPressed: () => _confirmDeleteAnnouncement(context, doc.id, title),
                      ),
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

  Future<void> _deleteAnnouncement(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(id)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement deleted successfully.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete announcement.')),
        );
      }
    }
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final badgeColor = context.isDarkMode ? const Color(0xFF9D7CFF) : const Color(0xFF6C3BFF);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: badgeColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
