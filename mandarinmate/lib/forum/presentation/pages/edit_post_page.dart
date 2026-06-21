import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mandarinmate/forum/domain/forum_post_model.dart';
import 'package:mandarinmate/services/ai_moderation_service.dart';

class EditPostPage extends StatefulWidget {
  final ForumPost post;
  final Color themeColor;

  const EditPostPage({
    super.key,
    required this.post,
    required this.themeColor,
  });

  @override
  State<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  
  final _aiModerationService = AiModerationService();
  String? _titleError;
  String? _contentError;
  
  late String _selectedCategory;
  bool _isUpdating = false;

  final List<String> _categories = [
    'General',
    'Grammar',
    'Vocabulary',
    'Pronunciation',
    'Q&A'
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _contentController = TextEditingController(text: widget.post.content);
    _selectedCategory = widget.post.category;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _updatePost() async {
    setState(() {
      _titleError = null;
      _contentError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUpdating = true);

    try {
      // Content Moderation check
      final titleScanError = await _aiModerationService.scanText(_titleController.text);
      if (titleScanError != null) {
        setState(() {
          _titleError = titleScanError;
          _isUpdating = false;
        });
        _formKey.currentState!.validate();
        return;
      }

      final contentScanError = await _aiModerationService.scanText(_contentController.text);
      if (contentScanError != null) {
        setState(() {
          _contentError = contentScanError;
          _isUpdating = false;
        });
        _formKey.currentState!.validate();
        return;
      }

      final postRef = FirebaseFirestore.instance.collection('forum_posts').doc(widget.post.id);

      await postRef.update({
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'category': _selectedCategory,
        'updatedAt': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post updated successfully!'),
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
            content: Text('Failed to update post: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Edit Post',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1C2433),
        elevation: 0,
        centerTitle: true,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFECEFF1), width: 1),
        ),
      ),
      body: _isUpdating
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFE4CF)),
                      ),
                      child: TextFormField(
                        controller: _titleController,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1C2433),
                        ),
                        onChanged: (value) {
                          if (_titleError != null) {
                            setState(() {
                              _titleError = null;
                            });
                            _formKey.currentState!.validate();
                          }
                        },
                        decoration: const InputDecoration(
                          hintText: 'Enter a descriptive title...',
                          hintStyle: TextStyle(color: Colors.grey, fontWeight: FontWeight.normal),
                          border: InputBorder.none,
                          labelText: 'Title',
                          labelStyle: TextStyle(
                            color: Colors.grey,
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
                    const Text(
                      'Select Category',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF546E7A),
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
                              color: isSelected ? Colors.white : const Color(0xFF546E7A),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: widget.themeColor,
                          backgroundColor: Colors.white,
                          elevation: 1,
                          side: BorderSide(
                            color: isSelected ? widget.themeColor : const Color(0xFFFFE4CF),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFE4CF)),
                      ),
                      child: TextFormField(
                        controller: _contentController,
                        maxLines: 12,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1C2433),
                        ),
                        onChanged: (value) {
                          if (_contentError != null) {
                            setState(() {
                              _contentError = null;
                            });
                            _formKey.currentState!.validate();
                          }
                        },
                        decoration: const InputDecoration(
                          hintText: 'Share your question, learning tips, or topics in Mandarin...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          labelText: 'Content',
                          labelStyle: TextStyle(
                            color: Colors.grey,
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

                    // Save Changes Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _updatePost,
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
                            Icon(Icons.save_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Save Changes',
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
