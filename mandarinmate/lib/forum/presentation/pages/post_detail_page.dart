import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mandarinmate/forum/domain/forum_comment_model.dart';
import 'package:mandarinmate/forum/domain/forum_post_model.dart';
import 'package:mandarinmate/models/user_model.dart';
import 'package:mandarinmate/forum/presentation/pages/edit_post_page.dart';
import 'package:mandarinmate/services/ai_moderation_service.dart';
import 'package:mandarinmate/utils/linkify_util.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;
  final Color themeColor;

  const PostDetailPage({
    super.key,
    required this.postId,
    required this.themeColor,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSubmittingComment = false;
  String? _currentUserRole;
  
  final _aiModerationService = AiModerationService();
  String? _commentError;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserRole();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentUserRole() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && doc.data() != null) {
          setState(() {
            _currentUserRole = doc.data()!['role'] ?? 'student';
          });
        }
      }
    } catch (e) {
      print('Error fetching user role: $e');
    }
  }

  Future<void> _toggleLike(ForumPost post, String currentUid) async {
    final postRef = FirebaseFirestore.instance.collection('forum_posts').doc(post.id);
    final isLiked = post.likes.contains(currentUid);

    try {
      await postRef.update({
        'likes': isLiked
            ? FieldValue.arrayRemove([currentUid])
            : FieldValue.arrayUnion([currentUid]),
      });
    } catch (e) {
      print('Error updating like: $e');
    }
  }

  void _sharePost(ForumPost post) {
    // Increment share count
    FirebaseFirestore.instance
        .collection('forum_posts')
        .doc(post.id)
        .update({'sharesCount': FieldValue.increment(1)});

    final shareText = '''
📢 *MandarinMate Forum Topic*
Category: #${post.category}
Title: ${post.title}
Author: ${post.authorName} (${post.authorRole})

${post.content}

Check it out on MandarinMate! 🍊
''';

    Clipboard.setData(ClipboardData(text: shareText)).then((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Copied post details to clipboard!'),
              ],
            ),
            backgroundColor: widget.themeColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    });
  }

  Future<void> _deletePost(ForumPost post) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('forum_posts').doc(post.id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post deleted successfully'),
              backgroundColor: Colors.grey,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context); // Go back
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete post: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _submitComment(String currentUid) async {
    setState(() {
      _commentError = null;
    });

    final content = _commentController.text.trim();
    if (content.isEmpty) {
      setState(() {
        _commentError = 'Comment cannot be empty';
      });
      return;
    }

    setState(() => _isSubmittingComment = true);

    try {
      final scanError = await _aiModerationService.scanText(content);
      if (scanError != null) {
        setState(() {
          _commentError = scanError;
          _isSubmittingComment = false;
        });
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Fetch profile for accurate displayName and role
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

      final commentRef = FirebaseFirestore.instance
          .collection('forum_posts')
          .doc(widget.postId)
          .collection('comments')
          .doc();

      final comment = ForumComment(
        id: commentRef.id,
        postId: widget.postId,
        content: content,
        authorId: user.uid,
        authorName: authorName,
        authorRole: authorRole,
        authorPhotoUrl: authorPhotoUrl,
        createdAt: DateTime.now(),
      );

      // Save comment and increment post count
      final postRef = FirebaseFirestore.instance.collection('forum_posts').doc(widget.postId);
      
      final batch = FirebaseFirestore.instance.batch();
      batch.set(commentRef, comment.toMap());
      batch.update(postRef, {'commentCount': FieldValue.increment(1)});
      
      await batch.commit();

      _commentController.clear();
      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit comment: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingComment = false);
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final commentRef = FirebaseFirestore.instance
            .collection('forum_posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(commentId);

        final postRef = FirebaseFirestore.instance.collection('forum_posts').doc(widget.postId);

        final batch = FirebaseFirestore.instance.batch();
        batch.delete(commentRef);
        batch.update(postRef, {'commentCount': FieldValue.increment(-1)});

        await batch.commit();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment deleted'),
              backgroundColor: Colors.grey,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete comment: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Color _getRoleColor(String role) {
    if (role.toLowerCase() == 'tutor') {
      return const Color(0xFF0F6E56); // Green
    }
    if (role.toLowerCase() == 'admin') {
      return const Color(0xFF7C3AED); // Purple
    }
    return const Color(0xFFF57C00); // Orange / Student
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('forum_posts')
          .doc(widget.postId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists || snapshot.data!.data() == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Post not found or deleted.')),
          );
        }

        final post = ForumPost.fromMap(snapshot.data!.data()!, snapshot.data!.id);
        final isLiked = post.likes.contains(currentUid);
        final isPostAuthor = post.authorId == currentUid;
        final isAdminOrTutor = _currentUserRole == 'admin' || _currentUserRole == 'tutor';

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            title: Text(
              post.category,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1C2433),
            elevation: 0,
            centerTitle: true,
            shape: const Border(
              bottom: BorderSide(color: Color(0xFFECEFF1), width: 1),
            ),
            actions: [
              if (isPostAuthor || _currentUserRole == 'admin') ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditPostPage(
                          post: post,
                          themeColor: widget.themeColor,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () => _deletePost(post),
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    children: [
                      // --- POST HEADER & BODY ---
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Author details row
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: _getRoleColor(post.authorRole).withOpacity(0.1),
                                  backgroundImage: post.authorPhotoUrl.isNotEmpty
                                      ? NetworkImage(post.authorPhotoUrl)
                                      : null,
                                  child: post.authorPhotoUrl.isEmpty
                                      ? Text(
                                          post.authorName.isNotEmpty
                                              ? post.authorName[0].toUpperCase()
                                              : 'A',
                                          style: TextStyle(
                                            color: _getRoleColor(post.authorRole),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            post.authorName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1C2433),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _getRoleColor(post.authorRole).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              post.authorRole.toUpperCase(),
                                              style: TextStyle(
                                                color: _getRoleColor(post.authorRole),
                                                fontSize: 8,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('MMM dd, yyyy • hh:mm a').format(post.createdAt),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF78909C),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Post Title
                            Text(
                              post.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1C2433),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Post Content
                            buildLinkifiableText(
                              post.content,
                              const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF455A64),
                                height: 1.5,
                              ),
                              TextStyle(
                                color: widget.themeColor,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Divider(color: Color(0xFFECEFF1)),
                            
                            // Post Actions Row (Like, Comment counts, Share)
                            Row(
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _toggleLike(post, currentUid),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                          color: isLiked ? Colors.red : const Color(0xFF78909C),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${post.likes.length}',
                                          style: TextStyle(
                                            color: isLiked ? Colors.red : const Color(0xFF546E7A),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.mode_comment_outlined,
                                      color: Color(0xFF78909C),
                                      size: 19,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${post.commentCount}',
                                      style: const TextStyle(
                                        color: Color(0xFF546E7A),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _sharePost(post),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.share_outlined,
                                          color: Color(0xFF78909C),
                                          size: 19,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${post.sharesCount}',
                                          style: const TextStyle(
                                            color: Color(0xFF546E7A),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // --- COMMENTS TITLE BAR ---
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text(
                          'Comments (${post.commentCount})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF546E7A),
                          ),
                        ),
                      ),

                      // --- COMMENTS STREAM ---
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('forum_posts')
                            .doc(post.id)
                            .collection('comments')
                            .orderBy('createdAt', descending: false)
                            .snapshots(),
                        builder: (context, commentSnapshot) {
                          if (commentSnapshot.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = commentSnapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return Container(
                              margin: const EdgeInsets.all(20),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFFFE4CF)),
                              ),
                              child: const Center(
                                child: Text(
                                  'No comments yet. Be the first to share your thoughts!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final commentDoc = docs[index];
                              final comment = ForumComment.fromMap(commentDoc.data(), commentDoc.id);
                              
                              final isCommentAuthor = comment.authorId == currentUid;
                              final canDelete = isCommentAuthor || isAdminOrTutor || isPostAuthor;

                              return Container(
                                color: Colors.white,
                                margin: const EdgeInsets.only(bottom: 2),
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: _getRoleColor(comment.authorRole).withOpacity(0.1),
                                          backgroundImage: comment.authorPhotoUrl.isNotEmpty
                                              ? NetworkImage(comment.authorPhotoUrl)
                                              : null,
                                          child: comment.authorPhotoUrl.isEmpty
                                              ? Text(
                                                  comment.authorName.isNotEmpty
                                                      ? comment.authorName[0].toUpperCase()
                                                      : 'A',
                                                  style: TextStyle(
                                                    color: _getRoleColor(comment.authorRole),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    comment.authorName,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF1C2433),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: _getRoleColor(comment.authorRole).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      comment.authorRole.toUpperCase(),
                                                      style: TextStyle(
                                                        color: _getRoleColor(comment.authorRole),
                                                        fontSize: 6,
                                                        fontWeight: FontWeight.w900,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 1),
                                              Text(
                                                DateFormat('MMM dd, yyyy • hh:mm a').format(comment.createdAt),
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  color: Color(0xFF78909C),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (canDelete)
                                          IconButton(
                                            icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                                            onPressed: () => _deleteComment(comment.id),
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                     Padding(
                                       padding: const EdgeInsets.only(left: 36),
                                       child: buildLinkifiableText(
                                         comment.content,
                                         const TextStyle(
                                           fontSize: 13,
                                           color: Color(0xFF37474F),
                                         ),
                                         TextStyle(
                                           color: widget.themeColor,
                                           fontWeight: FontWeight.bold,
                                           decoration: TextDecoration.underline,
                                         ),
                                       ),
                                     ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              // --- COMMENT INPUT BOX ---
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Color(0xFFECEFF1), width: 1),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F3F4),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: _commentError != null ? Colors.red : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: TextField(
                                controller: _commentController,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                textCapitalization: TextCapitalization.sentences,
                                style: const TextStyle(fontSize: 14),
                                onChanged: (value) {
                                  if (_commentError != null) {
                                    setState(() {
                                      _commentError = null;
                                    });
                                  }
                                },
                                decoration: const InputDecoration(
                                  hintText: 'Add a comment...',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _isSubmittingComment
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: widget.themeColor,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  icon: Icon(Icons.send_rounded, color: widget.themeColor),
                                  onPressed: () => _submitComment(currentUid),
                                ),
                        ],
                      ),
                      if (_commentError != null) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: Text(
                            _commentError!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
