import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mandarinmate/services/chat_attachment_service.dart';
import 'package:mandarinmate/services/ai_moderation_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // [NEW] For system tray
import 'package:mandarinmate/utils/linkify_util.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser!;

  StreamSubscription<DocumentSnapshot>? _chatSubscription;
  StreamSubscription<QuerySnapshot>? _unreadMessagesSubscription;
  Map<String, dynamic>? _receiverData;

  bool _isSearching = false;
  String _searchQuery = '';

  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  bool _firstScrollDone = false;
  final _formKey = GlobalKey<FormState>();

  final _aiModerationService = AiModerationService();
  String? _chatError;
  bool _isSendingMedia = false;

  @override
  void initState() {
    super.initState();

    // Instantly clear system tray pop-ups!
    _clearSystemNotifications();

    _loadReceiverData();

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final offset = _scrollController.offset;
      final show = offset < maxScroll - 200;
      if (show != _showScrollToBottom) {
        setState(() {
          _showScrollToBottom = show;
        });
      }
    });

    // Instantly mark messages as read if we are looking at the screen
    _chatSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null &&
            data['lastMessageSenderId'] != currentUser.uid &&
            data['isLastMessageRead'] == false) {
          snapshot.reference.update({'isLastMessageRead': true});
        }
      }
    });

    // Subscriptions to messages to mark them as read instantly
    _unreadMessagesSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .where('senderId', isEqualTo: widget.receiverId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshot.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        batch.commit();
      }
    });
  }

  Future<void> _loadReceiverData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.receiverId).get();
      if (mounted) {
        setState(() {
          _receiverData = doc.data();
        });
      }
    } catch (e) {
      debugPrint('Error loading receiver profile: $e');
    }
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _unreadMessagesSubscription?.cancel();
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
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
    setState(() {
      _chatError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final text = _messageController.text.trim();

    setState(() => _isSendingMedia = true);

    try {
      final scanError = await _aiModerationService.scanText(text);
      if (scanError != null) {
        setState(() {
          _chatError = scanError;
          _isSendingMedia = false;
        });
        _formKey.currentState!.validate();
        return;
      }
    } catch (e) {
      debugPrint('Moderation check failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isSendingMedia = false);
      }
    }

    _messageController.clear(); // Clear instantly for better UX
    _formKey.currentState!.reset(); // Reset validation state
    _messageController.clear(); // Ensure text is cleared after form reset

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
      'isRead': false,
    });

    // Call our new helper function
    await _updateSnippetAndNotify(text);
    _scrollToBottom();
  }

  Future<void> sendImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() => _isSendingMedia = true);

    try {
      final scanError = await _aiModerationService.scanImage(image.path);
      if (scanError != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(scanError),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final file = File(image.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Supabase.instance.client.storage
          .from('chat-files')
          .upload(fileName, file);

      final url = Supabase.instance.client.storage
          .from('chat-files')
          .getPublicUrl(fileName);

      // Save Image
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({
        'senderId': currentUser.uid,
        'messageType': 'image',
        'fileUrl': url,
        'fileName': fileName,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await _updateSnippetAndNotify('📷 Photo');
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending image: $e');
    } finally {
      if (mounted) {
        setState(() => _isSendingMedia = false);
      }
    }
  }

  Future<void> sendAttachment() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;

    final filePath = result.files.single.path!;
    final fileName = result.files.single.name;

    setState(() => _isSendingMedia = true);

    try {
      // Moderate file name first
      final textScanError = await _aiModerationService.scanText(fileName);
      if (textScanError != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(textScanError),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // If it's an image file, scan the image content as well
      final lowerPath = filePath.toLowerCase();
      if (lowerPath.endsWith('.jpg') || lowerPath.endsWith('.jpeg') || lowerPath.endsWith('.png') || lowerPath.endsWith('.webp') || lowerPath.endsWith('.gif')) {
        final imageScanError = await _aiModerationService.scanImage(filePath);
        if (imageScanError != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(imageScanError),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }

      final file = File(filePath);
      final finalStorageName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await Supabase.instance.client.storage
          .from('chat-files')
          .upload(finalStorageName, file);

      final url = Supabase.instance.client.storage
          .from('chat-files')
          .getPublicUrl(finalStorageName);

      // Save File
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').add({
        'senderId': currentUser.uid,
        'messageType': 'file',
        'fileName': fileName,
        'fileUrl': url,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      await _updateSnippetAndNotify('📄 $fileName');
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending attachment: $e');
    } finally {
      if (mounted) {
        setState(() => _isSendingMedia = false);
      }
    }
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

  DateTime _getDateTimeOfMessage(Map<String, dynamic> message) {
    final ts = message['timestamp'] as Timestamp?;
    return ts != null ? ts.toDate() : DateTime.now();
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    if (msgDate == today) {
      return 'Today';
    } else if (msgDate == yesterday) {
      return 'Yesterday';
    } else {
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  Widget _buildDateHeader(DateTime date) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _formatDateHeader(date),
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final hour24 = date.hour;
    final hour = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = hour24 >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToUnreadOrBottom(List<QueryDocumentSnapshot> messages) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      
      int firstUnreadIndex = -1;
      for (int i = 0; i < messages.length; i++) {
        final data = messages[i].data() as Map<String, dynamic>;
        final isMe = data['senderId'] == currentUser.uid;
        final isRead = data['isRead'] as bool? ?? true;
        if (!isMe && !isRead) {
          firstUnreadIndex = i;
          break;
        }
      }
      
      if (firstUnreadIndex != -1) {
        // Estimate scroll position: 85.0 average height per message item
        double targetOffset = firstUnreadIndex * 85.0;
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (targetOffset > maxScroll) {
          targetOffset = maxScroll;
        }
        _scrollController.jumpTo(targetOffset);
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.blue, fontSize: 16),
                cursorColor: Colors.blue,
                decoration: const InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: TextStyle(color: Colors.blueGrey),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.orange.shade200,
                    backgroundImage: (_receiverData?['profileImageUrl'] != null &&
                            (_receiverData!['profileImageUrl'] as String).isNotEmpty)
                        ? NetworkImage(_receiverData!['profileImageUrl'])
                        : null,
                    child: (_receiverData?['profileImageUrl'] == null ||
                            (_receiverData!['profileImageUrl'] as String).isEmpty)
                        ? Text(
                            widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _receiverData != null
                          ? '${_receiverData!['firstName']} ${_receiverData!['lastName']}'
                          : widget.receiverName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.blue),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search, color: Colors.blue),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').orderBy('timestamp').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    
                    var messages = snapshot.data!.docs;
                    
                    if (!_firstScrollDone && messages.isNotEmpty && _searchQuery.trim().isEmpty) {
                      _firstScrollDone = true;
                      _scrollToUnreadOrBottom(messages);
                    }

                    // Search filtering logic
                    if (_searchQuery.trim().isNotEmpty) {
                      messages = messages.where((doc) {
                        final message = doc.data() as Map<String, dynamic>;
                        final msgType = message['messageType'] ?? 'text';
                        if (msgType == 'text') {
                          final text = (message['text'] as String? ?? '').toLowerCase();
                          return text.contains(_searchQuery.toLowerCase());
                        } else {
                          final fileName = (message['fileName'] as String? ?? '').toLowerCase();
                          return fileName.contains(_searchQuery.toLowerCase());
                        }
                      }).toList();
                    }

                    final receiverImageUrl = _receiverData?['profileImageUrl'] as String? ?? '';
                    final receiverInitial = widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : 'U';

                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index].data() as Map<String, dynamic>;
                        final isMe = message['senderId'] == currentUser.uid;
                        final String msgType = message['messageType'] ?? 'text';
                        final bool isRead = message['isRead'] as bool? ?? true;

                        // Date divider logic
                        final currentMsgDate = _getDateTimeOfMessage(message);
                        bool showDateHeader = false;
                        if (index == 0) {
                          showDateHeader = true;
                        } else {
                          final prevMessage = messages[index - 1].data() as Map<String, dynamic>;
                          final prevMsgDate = _getDateTimeOfMessage(prevMessage);
                          if (currentMsgDate.year != prevMsgDate.year ||
                              currentMsgDate.month != prevMsgDate.month ||
                              currentMsgDate.day != prevMsgDate.day) {
                            showDateHeader = true;
                          }
                        }

                        final msgBubble = Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue : Colors.grey.shade300,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                              bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                            ),
                          ),
                          child: msgType == 'text'
                              ? buildLinkifiableText(
                                  message['text'] ?? '',
                                  TextStyle(color: isMe ? Colors.white : Colors.black),
                                  TextStyle(
                                    color: isMe ? Colors.white : Colors.blue.shade800,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                )
                              : msgType == 'image'
                                  ? _buildImageMessage(message)
                                  : _buildFileMessage(message),
                        );

                        final msgWidget = Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(
                              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (!isMe) ...[
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.orange.shade200,
                                    backgroundImage: receiverImageUrl.isNotEmpty
                                        ? NetworkImage(receiverImageUrl)
                                        : null,
                                    child: receiverImageUrl.isEmpty
                                        ? Text(
                                            receiverInitial,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      msgBubble,
                                      const SizedBox(height: 4),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _formatTime(message['timestamp'] as Timestamp?),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (isMe) ...[
                                              const SizedBox(width: 4),
                                              Icon(
                                                isRead ? Icons.done_all : Icons.done,
                                                size: 14,
                                                color: isRead ? Colors.blue : Colors.grey,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );

                        if (showDateHeader) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildDateHeader(currentMsgDate),
                              msgWidget,
                            ],
                          );
                        }
                        return msgWidget;
                      },
                    );
                  },
                ),
                if (_showScrollToBottom)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: () {
                          if (_scrollController.hasClients) {
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        child: const Icon(Icons.keyboard_arrow_down),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isSendingMedia)
            const LinearProgressIndicator(
              color: Colors.blue,
              backgroundColor: Colors.transparent,
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (value) {
                          if (_chatError != null) {
                            setState(() {
                              _chatError = null;
                            });
                            _formKey.currentState!.validate();
                          }
                        },
                        onFieldSubmitted: (_) => sendMessage(),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a message';
                          }
                          if (_chatError != null) {
                            return _chatError;
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
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
          ),
        ],
      ),
    );
  }
}