import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_attachment_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final TextEditingController _messageController = TextEditingController();

  final currentUser = FirebaseAuth.instance.currentUser!;

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
  Future<void> sendImage() async {

  final result =
      await ChatAttachmentService.uploadImage();

  if (result == null) return;

  await FirebaseFirestore.instance
      .collection('chats')
      .doc(widget.chatId)
      .collection('messages')
      .add({
    'senderId': currentUser.uid,
    'messageType': 'image',
    'fileUrl': result['fileUrl'],
    'fileName': result['fileName'],
    'timestamp': FieldValue.serverTimestamp(),
  });
}


  Future<void> showAttachmentMenu() async {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Image'),
                onTap: () {
                  Navigator.pop(context);
                  sendImage();
                },
              ),

              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('Document'),
                onTap: () {
                  Navigator.pop(context);
                  sendAttachment();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getFileIcon(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.pdf')) {
      return Icons.picture_as_pdf;
    }

    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return Icons.description;
    }

    if (lower.endsWith('.ppt') || lower.endsWith('.pptx')) {
      return Icons.slideshow;
    }

    return Icons.insert_drive_file;
  }

  Future<void> sendAttachment() async {
    final result = await ChatAttachmentService.uploadFile();

    if (result == null) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
          'senderId': currentUser.uid,
          'messageType': 'file',
          'fileName': result['fileName'],
          'fileUrl': result['fileUrl'],
          'timestamp': FieldValue.serverTimestamp(),
        });
  }
  Widget _buildImageMessage(
  Map<String, dynamic> message,
) {
  return GestureDetector(
    onTap: () {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          child: InteractiveViewer(
            child: Image.network(
              message['fileUrl'],
            ),
          ),
        ),
      );
    },
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        message['fileUrl'],
        width: 200,
        height: 200,
        fit: BoxFit.cover,
      ),
    ),
  );
}

  Widget _buildFileMessage(Map<String, dynamic> message) {
    return InkWell(
      onTap: () async {
        final url = message['fileUrl'];

        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.grey.shade300,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _getFileIcon(
            message['fileName'] ?? '',
          ),
          color: Colors.blue,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            message['fileName'] ?? 'Attachment',
            overflow: TextOverflow.ellipsis,
          ),
        ),
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
                    final message =
                        messages[index].data() as Map<String, dynamic>;
                    final messageType = message['messageType'] ?? 'text';

                    final isMe = message['senderId'] == currentUser.uid;

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
                          color: isMe ? Colors.blue : Colors.grey.shade300,

                          borderRadius: BorderRadius.circular(12),
                        ),

                        child: messageType == 'text'
                        ? Text(message['text'] ?? '')
                        : messageType == 'image'
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

                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: showAttachmentMenu,
                  ),
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
