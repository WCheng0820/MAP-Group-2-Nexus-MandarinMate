import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController =
      TextEditingController();

  final currentUser =
      FirebaseAuth.instance.currentUser!;

  Future<void> sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': currentUser.uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receiverName),
      ),

      body: Column(
        children: [

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),

              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet'),
                  );
                }

                return ListView.builder(
                  itemCount: messages.length,

                  itemBuilder: (context, index) {

                    final message =
                        messages[index].data()
                            as Map<String, dynamic>;

                    final isMe =
                        message['senderId'] ==
                        currentUser.uid;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,

                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),

                        padding: const EdgeInsets.all(12),

                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.blue
                              : Colors.grey.shade300,

                          borderRadius:
                              BorderRadius.circular(12),
                        ),

                        child: Text(
                          message['text'] ?? '',
                          style: TextStyle(
                            color: isMe
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),

              child: Row(
                children: [

                  Expanded(
                    child: TextField(
                      controller:
                          _messageController,

                      decoration:
                          const InputDecoration(
                        hintText:
                            'Type a message...',
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  IconButton(
                    icon: const Icon(Icons.send),

                    onPressed: sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}