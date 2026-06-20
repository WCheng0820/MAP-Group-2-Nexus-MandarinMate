import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mandarinmate/services/chat_attachment_service.dart';

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

  StreamSubscription<DocumentSnapshot>? _chatSubscription;

  @override
  void initState() {
    super.initState();
    // Your unread-read logic
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
          snapshot.reference.update({'isLastMessageRead': true});
        }
      }
    });
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
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
      'messageType': 'text',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2. Update the latest message snippet and read status
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUser.uid,
      'isLastMessageRead': false,
    });

    _messageController.clear();

    // 3. Notification Logic
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.receiverId).get();
      final String? targetToken = userDoc.data()?['fcmToken'];

      if (targetToken != null && targetToken.isNotEmpty) {
        final senderDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        final senderName = '${senderDoc.data()?['firstName'] ?? ''} ${senderDoc.data()?['lastName'] ?? ''}'.trim();

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
      }
    } catch (e) {
      debugPrint('Notification error: $e');
    }
  }

  Future<void> sendImage() async {
    final result = await ChatAttachmentService.uploadImage();
    if (result == null) return;
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({
      'senderId': currentUser.uid,
      'messageType': 'image',
      'fileUrl': result['fileUrl'],
      'fileName': result['fileName'],
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendAttachment() async {
    final result = await ChatAttachmentService.uploadFile();
    if (result == null) return;
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({
      'senderId': currentUser.uid,
      'messageType': 'file',
      'fileName': result['fileName'],
      'fileUrl': result['fileUrl'],
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> showAttachmentMenu() async {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.image), title: const Text('Image'), onTap: () { Navigator.pop(context); sendImage(); }),
            ListTile(leading: const Icon(Icons.insert_drive_file), title: const Text('Document'), onTap: () { Navigator.pop(context); sendAttachment(); }),
          ],
        ),
      ),
    );
  }

  Widget _buildImageMessage(Map<String, dynamic> message) {
    return GestureDetector(
      onTap: () => showDialog(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(message['fileUrl'])))),
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(message['fileUrl'], width: 200, height: 200, fit: BoxFit.cover)),
    );
  }

  Widget _buildFileMessage(Map<String, dynamic> message) {
    return InkWell(
      onTap: () async => await launchUrl(Uri.parse(message['fileUrl']), mode: LaunchMode.externalApplication),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, color: Colors.blue),
            const SizedBox(width: 10),
            Flexible(child: Text(message['fileName'] ?? 'Attachment', overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.receiverName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').orderBy('timestamp').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isMe = message['senderId'] == currentUser.uid;
                    final String msgType = message['messageType'] ?? 'text';

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: msgType == 'text'
                            ? Text(message['text'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black))
                            : msgType == 'image'
                            ? _buildImageMessage(message)
                            : _buildFileMessage(message),
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
                      decoration: const InputDecoration(hintText: 'Type a message...', border: OutlineInputBorder()),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.attach_file), onPressed: showAttachmentMenu),
                  IconButton(icon: const Icon(Icons.send), onPressed: sendMessage),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}