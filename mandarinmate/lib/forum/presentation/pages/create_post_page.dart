import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/forum/domain/forum_post_model.dart';
import 'package:mandarinmate/models/user_model.dart';
import 'package:mandarinmate/services/ai_moderation_service.dart';
import 'package:mandarinmate/utils/app_theme.dart';

class CreatePostPage extends StatefulWidget {
  final Color themeColor;

  const CreatePostPage({
    super.key,
    required this.themeColor,
  });

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  
  final _aiModerationService = AiModerationService();
  String? _titleError;
  String? _contentError;
  
  String _selectedCategory = 'General';
  bool _isPublishing = false;

  final List<String> _categories = [
    'General',
    'Grammar',
    'Vocabulary',
    'Pronunciation',
    'Q&A'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _publishPost() async {
    setState(() {
      _titleError = null;
      _contentError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isPublishing = true);

    try {
      // Content Moderation check
      final titleScanError = await _aiModerationService.scanText(_titleController.text);
      if (titleScanError != null) {
        setState(() {
          _titleError = titleScanError;
          _isPublishing = false;
        });
        _formKey.currentState!.validate();
        return;
      }

      final contentScanError = await _aiModerationService.scanText(_contentController.text);
      if (contentScanError != null) {
        setState(() {
          _contentError = contentScanError;
          _isPublishing = false;
        });
        _formKey.currentState!.validate();
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Fetch user profile from Firestore to get name and role
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      String authorName = 'Anonymous';
      String authorRole = 'Student';
      String authorPhotoUrl = '';

      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        final profile = UserProfile.fromMap(data);
        authorName = profile.displayName.trim().isNotEmpty 
            ? profile.displayName 
            : (profile.username.isNotEmpty ? profile.username : 'Anonymous');
        authorRole = profile.role.toString().split('.').last;
        authorPhotoUrl = profile.profileImageUrl;
      } else {
        authorName = user.displayName ?? user.email ?? 'Anonymous';
      }

      // Create new document reference in Firestore
      final postsRef = FirebaseFirestore.instance.collection('forum_posts');
      final newPostRef = postsRef.doc();

      final newPost = ForumPost(
        id: newPostRef.id,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        category: _selectedCategory,
        authorId: user.uid,
        authorName: authorName,
        authorRole: authorRole,
        authorPhotoUrl: authorPhotoUrl,
        createdAt: DateTime.now(),
        likes: [],
        commentCount: 0,
        sharesCount: 0,
      );

      await newPostRef.set(newPost.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post published successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish post: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text(
          'Create New Post',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        backgroundColor: context.cardBg,
        foregroundColor: context.textDeep,
        elevation: 0,
        centerTitle: true,
        shape: Border(
          bottom: BorderSide(color: context.borderTheme, width: 1),
        ),
      ),
      body: _isPublishing
          ? Center(
              child: CircularProgressIndicator(color: widget.themeColor),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title input card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderTheme),
                      ),
                      child: TextFormField(
                        controller: _titleController,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.textDeep,
                        ),
                        onChanged: (value) {
                          if (_titleError != null) {
                            setState(() {
                              _titleError = null;
                            });
                            _formKey.currentState!.validate();
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter a descriptive title...',
                          hintStyle: TextStyle(color: context.textMuted, fontWeight: FontWeight.normal),
                          border: InputBorder.none,
                          labelText: 'Title',
                          labelStyle: TextStyle(
                            color: context.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          if (value.trim().length < 5) {
                            return 'Title must be at least 5 characters';
                          }
                          if (_titleError != null) {
                            return _titleError;
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Category selector card
                    Text(
                      'Select Category',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: context.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((category) {
                        final isSelected = _selectedCategory == category;
                        return ChoiceChip(
                          label: Text(
                            category,
                            style: TextStyle(
                              color: isSelected ? Colors.white : context.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: widget.themeColor,
                          backgroundColor: context.cardBg,
                          elevation: 1,
                          side: BorderSide(
                            color: isSelected ? widget.themeColor : context.borderTheme,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCategory = category;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Content input card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderTheme),
                      ),
                      child: TextFormField(
                        controller: _contentController,
                        maxLines: 12,
                        keyboardType: TextInputType.multiline,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textDeep,
                        ),
                        onChanged: (value) {
                          if (_contentError != null) {
                            setState(() {
                              _contentError = null;
                            });
                            _formKey.currentState!.validate();
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Share your question, learning tips, or topics in Mandarin...',
                          hintStyle: TextStyle(color: context.textMuted),
                          border: InputBorder.none,
                          labelText: 'Content',
                          labelStyle: TextStyle(
                            color: context.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the content';
                          }
                          if (value.trim().length < 10) {
                            return 'Content must be at least 10 characters';
                          }
                          if (_contentError != null) {
                            return _contentError;
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Publish Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _publishPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 2,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Publish Post',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
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
