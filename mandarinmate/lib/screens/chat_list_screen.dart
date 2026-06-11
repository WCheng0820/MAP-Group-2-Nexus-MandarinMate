import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mandarinmate/screens/chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

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
    final participants =
        List<String>.from(doc['participants']);

    if (participants.contains(tutorId)) {
      return doc.id;
    }
  }

  final newChat = await FirebaseFirestore.instance
      .collection('chats')
      .add({
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
      ),

      body: StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('chats')
      .where(
        'participants',
        arrayContains: FirebaseAuth.instance.currentUser!.uid,
      )
      .orderBy('lastMessageTime', descending: true)
      .snapshots(),
  builder: (context, snapshot) {

    if (snapshot.connectionState ==
        ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (!snapshot.hasData ||
        snapshot.data!.docs.isEmpty) {
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

final otherUid = participants.firstWhere(
  (uid) => uid != FirebaseAuth.instance.currentUser!.uid,
);
        return Container(
  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.white,
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

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chats[index].id,
            receiverName:
                '${user['firstName']} ${user['lastName']}',
          ),
        ),
      );
    },

    child: Row(
      children: [

        // 🟠 Avatar
        CircleAvatar(
          radius: 26,
          backgroundColor: Colors.orange.shade200,
          child: Text(
            'U',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(width: 12),

        // 🧠 Middle content
        Expanded(
          child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(otherUid)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Text('Loading...');
              }

              final user =
                  snapshot.data!.data() as Map<String, dynamic>;

              final name =
                  '${user['firstName']} ${user['lastName']}';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Name
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Last message
                  Text(
                    chat['lastMessage'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // ⏰ Right side
        Column(
          children: [
            Text(
              _formatTime(chat['lastMessageTime']),
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade300,
              ),
            ),

            const SizedBox(height: 6),

            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.yellow,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ],
    ),
  ),
);
      },
    );
  },
),

      floatingActionButton: FloatingActionButton(
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

                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (!snapshot.hasData ||
                      snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No tutors found'),
                    );
                  }

                  final tutors = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: tutors.length,

                    itemBuilder: (context, index) {

                      final tutor =
                          tutors[index].data()
                              as Map<String, dynamic>;

                      return ListTile(
  title: Text(
    '${tutor['firstName']} ${tutor['lastName']}',
  ),

  onTap: () async {
  final chatId = await getOrCreateChat(tutors[index].id);

  Navigator.pop(sheetContext);

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        chatId: chatId,
        receiverName:
            '${tutor['firstName']} ${tutor['lastName']}',
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
      ),
    );
  }
}