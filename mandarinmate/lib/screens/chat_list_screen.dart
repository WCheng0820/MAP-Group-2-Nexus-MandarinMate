import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mandarinmate/screens/chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final String role;

  const ChatListScreen({
    super.key,
    required this.role,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  Future<String> getOrCreateChat(String tutorId) async {
    final currentUser = FirebaseAuth.instance.currentUser!;

    final query = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: currentUser.uid)
        .get();

    for (var doc in query.docs) {
      final participants = List<String>.from(doc['participants']);

      if (participants.contains(tutorId)) {
        return doc.id;
      }
    }

    final newChat = await FirebaseFirestore.instance.collection('chats').add({
      'participants': [
        currentUser.uid,
        tutorId,
      ],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    return newChat.id;
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();
    final now = DateTime.now();

    final diff = now.difference(date);

    if (diff.inDays > 0) {
      return '${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    } else {
      return 'now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid; // Grab ID once

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUserId)
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No conversations yet'),
            );
          }

          final chats = snapshot.data!.docs;

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index].data() as Map<String, dynamic>;
              final participants = List<String>.from(chat['participants']);
              final otherUid = participants.firstWhere((uid) => uid != currentUserId);

              // --- [NEW] UNREAD LOGIC ---
              // Check if the last message was sent by someone else AND is marked as unread
              final bool isUnreadForMe =
                  chat['lastMessageSenderId'] != currentUserId &&
                      chat['isLastMessageRead'] == false;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUnreadForMe ? const Color(0xFFFFFDF5) : Colors.white, // Subtle warm tint for unread
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: InkWell(
                  onTap: () async {
                    final userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(otherUid)
                        .get();

                    final user = userDoc.data() as Map<String, dynamic>;

                    if (!context.mounted) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          chatId: chats[index].id,
                          receiverName: '${user['firstName']} ${user['lastName']}',
                          receiverId: otherUid,
                        ),
                      ),
                    );
                  },
                  child: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(otherUid)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              child: CircularProgressIndicator(),
                            ),
                            SizedBox(width: 12),
                            Text('Loading chat...'),
                          ],
                        );
                      }

                      final user = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                      final String imageUrl = user['profileImageUrl'] ?? '';
                      final firstName = user['firstName'] ?? '';
                      final lastName = user['lastName'] ?? '';
                      final name = '$firstName $lastName'.trim();
                      final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

                      return Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.orange.shade200,
                            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                            child: imageUrl.isEmpty
                                ? Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),

                          // Middle content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isUnreadForMe ? FontWeight.w900 : FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Last message
                                Text(
                                  chat['lastMessage'] ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isUnreadForMe ? Colors.black87 : Colors.grey.shade600,
                                    fontWeight: isUnreadForMe ? FontWeight.w700 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Right side
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatTime(chat['lastMessageTime']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isUnreadForMe ? const Color(0xFFD40511) : Colors.grey.shade400,
                                  fontWeight: isUnreadForMe ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // The Alert Dot
                              if (isUnreadForMe)
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD40511),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFD40511).withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                const SizedBox(height: 10),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: widget.role == 'student'
          ? FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (sheetContext) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'tutor')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No tutors found'),
                    );
                  }

                  final tutors = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: tutors.length,
                    itemBuilder: (context, index) {
                      final tutor = tutors[index].data() as Map<String, dynamic>;

                      return ListTile(
                        title: Text(
                          '${tutor['firstName']} ${tutor['lastName']}',
                        ),
                        onTap: () async {
                          final chatId = await getOrCreateChat(tutors[index].id);

                          Navigator.pop(sheetContext);

                          if (!context.mounted) return;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatId: chatId,
                                receiverName: '${tutor['firstName']} ${tutor['lastName']}',
                                receiverId: tutors[index].id,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      )
          : null,
    );
  }
}