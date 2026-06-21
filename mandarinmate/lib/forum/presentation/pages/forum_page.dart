import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mandarinmate/forum/domain/forum_post_model.dart';
import 'package:mandarinmate/forum/presentation/pages/create_post_page.dart';
import 'package:mandarinmate/forum/presentation/pages/post_detail_page.dart';

class ForumPage extends StatefulWidget {
  final Color themeColor;

  const ForumPage({
    super.key,
    required this.themeColor,
  });

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'General',
    'Grammar',
    'Vocabulary',
    'Pronunciation',
    'Q&A'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    // Increment share count in Firestore
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
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Curved theme gradient top header
          Container(
            padding: EdgeInsets.fromLTRB(20, statusBarHeight + 16, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [widget.themeColor, widget.themeColor.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Community Forum',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Discuss Mandarin topics with classmates & tutors',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Animated Search Bar
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search posts by title or content...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Category pills tag list
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
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
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Posts Feed Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('forum_posts')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                // Map & Filter posts locally to prevent index setup issues
                var posts = snapshot.data!.docs
                    .map((doc) => ForumPost.fromMap(doc.data(), doc.id))
                    .toList();

                if (_selectedCategory != 'All') {
                  posts = posts.where((p) => p.category == _selectedCategory).toList();
                }

                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  posts = posts
                      .where((p) =>
                          p.title.toLowerCase().contains(query) ||
                          p.content.toLowerCase().contains(query))
                      .toList();
                }

                if (posts.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final isLiked = post.likes.contains(currentUid);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFFFE4CF)),
                        boxShadow: [
                          BoxShadow(
                            color: widget.themeColor.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostDetailPage(
                                postId: post.id,
                                themeColor: widget.themeColor,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Author info
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
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
                                              fontSize: 12,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              post.authorName,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1C2433),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: _getRoleColor(post.authorRole).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                post.authorRole.toUpperCase(),
                                                style: TextStyle(
                                                  color: _getRoleColor(post.authorRole),
                                                  fontSize: 6,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          DateFormat('MMM dd, yyyy').format(post.createdAt),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF78909C),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Category tag badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECEFF1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      post.category,
                                      style: const TextStyle(
                                        color: Color(0xFF546E7A),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // Post content
                              Text(
                                post.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1C2433),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                post.content,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF546E7A),
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Divider(height: 1, color: Color(0xFFECEFF1)),
                              const SizedBox(height: 8),

                              // Interactive metrics row
                              Row(
                                children: [
                                  // Like Button
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _toggleLike(post, currentUid),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                            color: isLiked ? Colors.red : const Color(0xFF78909C),
                                            size: 18,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${post.likes.length}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isLiked ? Colors.red : const Color(0xFF546E7A),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // Comments info (tapping goes to detail view)
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PostDetailPage(
                                            postId: post.id,
                                            themeColor: widget.themeColor,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.mode_comment_outlined,
                                            color: Color(0xFF78909C),
                                            size: 17,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${post.commentCount}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF546E7A),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Spacer(),

                                  // Share Button
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _sharePost(post),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.share_outlined,
                                            color: Color(0xFF78909C),
                                            size: 17,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${post.sharesCount}',
                                            style: const TextStyle(
                                              fontSize: 12,
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
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      
      // Floating Action Button to write post
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePostPage(
                themeColor: widget.themeColor,
              ),
            ),
          );
        },
        backgroundColor: widget.themeColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.add_comment_rounded),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: widget.themeColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.forum_outlined,
              color: widget.themeColor,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Posts Found',
            style: TextStyle(
              color: Color(0xFF1C2433),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start the conversation! Be the first to share study updates, ask questions, or exchange Mandarin tips.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF78909C),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
