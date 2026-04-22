import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});

  @override
  State<AdminAnnouncementsPage> createState() => _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _targetRole = 'all';
  bool _submitting = false;

  static const Color _primary = Color(0xFF6C3BFF);
  static const Color _surface = Color(0xFFF6F3FF);

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('Admin Announcements'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      validator: _required,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _bodyCtrl,
                      validator: _required,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Body',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _targetRole,
                      decoration: InputDecoration(
                        labelText: 'Target Role',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(
                          value: 'student',
                          child: Text('Student'),
                        ),
                        DropdownMenuItem(value: 'tutor', child: Text('Tutor')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _targetRole = value);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _createAnnouncement,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Publish Announcement'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final title = (data['title'] ?? '').toString();
                    final body = (data['body'] ?? '').toString();
                    final targetRole = (data['targetRole'] ?? 'all').toString();
                    final createdByName = (data['createdByName'] ?? '')
                        .toString();
                    final createdAt = data['createdAt'] is Timestamp
                        ? (data['createdAt'] as Timestamp).toDate()
                        : null;

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(body),
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
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () => _deleteAnnouncement(doc.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createAnnouncement() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _submitting = true);

    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final adminData = adminDoc.data() ?? <String, dynamic>{};
      final createdByName =
          (adminData['name'] ?? adminData['firstName'] ?? user.email ?? 'Admin')
              .toString();

      await FirebaseFirestore.instance.collection('announcements').add({
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
        'targetRole': _targetRole,
        'createdBy': user.uid,
        'createdByName': createdByName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _titleCtrl.clear();
      _bodyCtrl.clear();
      setState(() => _targetRole = 'all');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    await FirebaseFirestore.instance
        .collection('announcements')
        .doc(id)
        .delete();
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Required';
    }
    return null;
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6C3BFF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF6C3BFF),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
