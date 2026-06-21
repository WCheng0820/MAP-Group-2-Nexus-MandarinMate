import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AnnouncementCreateEditPage extends StatefulWidget {
  final String role; // 'tutor' or 'admin'
  final Color themeColor;
  final String? docId; // Non-null if editing
  final String? initialTitle;
  final String? initialBody;
  final String? initialTargetRole; // For admin only

  const AnnouncementCreateEditPage({
    super.key,
    required this.role,
    required this.themeColor,
    this.docId,
    this.initialTitle,
    this.initialBody,
    this.initialTargetRole,
  });

  @override
  State<AnnouncementCreateEditPage> createState() => _AnnouncementCreateEditPageState();
}

class _AnnouncementCreateEditPageState extends State<AnnouncementCreateEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late String _targetRole;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _bodyController = TextEditingController(text: widget.initialBody ?? '');
    _targetRole = widget.initialTargetRole ?? 'all';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _saveAnnouncement() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.docId == null) {
        // Create new announcement
        // Fetch creator's name
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final userData = userDoc.data() ?? <String, dynamic>{};
        final createdByName = (userData['name'] ??
                userData['firstName'] ??
                user.email ??
                (widget.role == 'admin' ? 'Admin' : 'Tutor'))
            .toString();

        await FirebaseFirestore.instance.collection('announcements').add({
          'title': _titleController.text.trim(),
          'body': _bodyController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': user.uid,
          'createdByName': createdByName,
          'targetRole': widget.role == 'admin' ? _targetRole : 'student',
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcement published successfully.')),
          );
          Navigator.pop(context);
        }
      } else {
        // Edit existing announcement
        final updateData = <String, dynamic>{
          'title': _titleController.text.trim(),
          'body': _bodyController.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (widget.role == 'admin') {
          updateData['targetRole'] = _targetRole;
        }

        await FirebaseFirestore.instance
            .collection('announcements')
            .doc(widget.docId)
            .update(updateData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Announcement updated successfully.')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save announcement: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.docId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: widget.themeColor,
        foregroundColor: Colors.white,
        title: Text(isEditing ? 'Edit Announcement' : 'New Announcement'),
        elevation: 0,
        actions: [
          if (!_isSaving)
            IconButton(
              icon: const Icon(Icons.check_rounded, size: 28),
              tooltip: 'Save',
              onPressed: _saveAnnouncement,
            ),
        ],
      ),
      body: _isSaving
          ? Center(
              child: CircularProgressIndicator(color: widget.themeColor),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _titleController,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Title cannot be empty';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: 'Title',
                                labelStyle: TextStyle(color: Colors.grey.shade600),
                                border: UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: widget.themeColor),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _bodyController,
                              maxLines: 15,
                              minLines: 8,
                              style: const TextStyle(fontSize: 15),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Body cannot be empty';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: 'Announcement Message',
                                labelStyle: TextStyle(color: Colors.grey.shade600),
                                alignLabelWithHint: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: widget.themeColor),
                                ),
                              ),
                            ),
                            if (widget.role == 'admin') ...[
                              const SizedBox(height: 20),
                              DropdownButtonFormField<String>(
                                initialValue: _targetRole,
                                decoration: InputDecoration(
                                  labelText: 'Target Audience',
                                  labelStyle: TextStyle(color: Colors.grey.shade600),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: widget.themeColor),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('All Users')),
                                  DropdownMenuItem(value: 'student', child: Text('Students Only')),
                                  DropdownMenuItem(value: 'tutor', child: Text('Tutors Only')),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _targetRole = value);
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.themeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _saveAnnouncement,
                      child: Text(
                        isEditing ? 'Save Changes' : 'Publish Announcement',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
