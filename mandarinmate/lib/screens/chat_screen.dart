import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mandarinmate/services/chat_attachment_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // [NEW] For system tray

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

    // Instantly clear system tray pop-ups!
    _clearSystemNotifications();

    // Instantly mark messages as read if we are looking at the screen
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

  // ------------------------------------------------------------------
  // [NEW] Helper to wipe the system notifications
  // ------------------------------------------------------------------
  Future<void> _clearSystemNotifications() async {
    try {
      // Swipes away the notifications in the phone's drop-down system tray.
      // (On Android, dismissing the tray notifications automatically clears the app icon badge too!)
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Could not clear notifications: $e');
    }
  }

  // ------------------------------------------------------------------
  // THE MASTER HELPER FUNCTION!
  // This updates the chat list, triggers the red dot, AND sends the notification.
  // ------------------------------------------------------------------
  Future<void> _updateSnippetAndNotify(String notificationBody) async {
    // 1. Update Chat List & Trigger Red Dot
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .update({
      'lastMessage': notificationBody,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUser.uid,
      'isLastMessageRead': false,
    });

    // 2. Trigger Supabase Notification
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
            'body': notificationBody,
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

  // ------------------------------------------------------------------
  // MESSAGE SENDING FUNCTIONS
  // ------------------------------------------------------------------

  Future<void> sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear(); // Clear instantly for better UX

    // Save message
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

    // Call our new helper function
    await _updateSnippetAndNotify(text);
  }

  Future<void> sendImage() async {
    final result = await ChatAttachmentService.uploadImage();
    if (result == null) return;

    // Save Image
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({
      'senderId': currentUser.uid,
      'messageType': 'image',
      'fileUrl': result['fileUrl'],
      'fileName': result['fileName'],
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Call our helper with a custom image message!
    await _updateSnippetAndNotify('📷 Photo');
  }

  Future<void> sendAttachment() async {
    final result = await ChatAttachmentService.uploadFile();
    if (result == null) return;

    // Save File
    await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({
      'senderId': currentUser.uid,
      'messageType': 'file',
      'fileName': result['fileName'],
      'fileUrl': result['fileUrl'],
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Call our helper with a custom file message!
    await _updateSnippetAndNotify('📄 ${result['fileName']}');
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

  // ------------------------------------------------------------------
  // UI BUILDERS
  // ------------------------------------------------------------------

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