import 'dart:async'; // [NEW] Added for StreamSubscription
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String receiverName;
  final String receiverId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.receiverName,
    required this.receiverId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser!;

  StreamSubscription<DocumentSnapshot>? _chatSubscription; // [NEW]

  @override
  void initState() {
    super.initState();
    // [NEW] Listen to the chat document. If a new message arrives while
    // we are staring at this screen, instantly mark it as read!
    _chatSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data != null &&
            data['lastMessageSenderId'] != currentUser.uid &&
            data['isLastMessageRead'] == false) {

          // Flip it to true because we are currently looking at it!
          snapshot.reference.update({'isLastMessageRead': true});
        }
      }
    });
  }

  @override
  void dispose() {
    _chatSubscription?.cancel(); // [NEW] Clean up the listener
    _messageController.dispose();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    // 1. Save message to Firestore
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': currentUser.uid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Update the latest message snippet on the chat list
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      // --- [NEW] Flag this chat as unread for the receiver! ---
      'lastMessageSenderId': currentUser.uid,
      'isLastMessageRead': false,
    });

    _messageController.clear();

    // ------------------------------------------------------------------
    // 3. NOTIFICATION LOGIC (Trigger Supabase)
    // ------------------------------------------------------------------
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.receiverId)
          .get();

      final String? targetToken = userDoc.data()?['fcmToken'];

      if (targetToken != null && targetToken.isNotEmpty) {
        final senderDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        final senderData = senderDoc.data();

        final String firstName = senderData?['firstName'] ?? 'Someone';
        final String lastName = senderData?['lastName'] ?? '';
        final String senderName = '$firstName $lastName'.trim();

        await Supabase.instance.client.functions.invoke(
          'send-chat-notification',
          body: {
            'fcmToken': targetToken,
            'title': 'New message from $senderName',
            'body': text,
            'chatId': widget.chatId,
            'senderId': currentUser.uid,
            'senderName': senderName,
          },
        );
        print('Successfully told Supabase to send the push notification with hidden data!');
      } else {
        print('User does not have an FCM token saved yet.');
      }
    } catch (e) {
      print('Failed to trigger Supabase notification: $e');
    }
    // ------------------------------------------------------------------
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
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isMe = message['senderId'] == currentUser.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          message['text'] ?? '',
                          style: TextStyle(color: isMe ? Colors.white : Colors.black),
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
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
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