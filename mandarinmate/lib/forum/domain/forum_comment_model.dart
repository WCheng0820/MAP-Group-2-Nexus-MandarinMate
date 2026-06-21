import 'package:cloud_firestore/cloud_firestore.dart';

class ForumComment {
  final String id;
  final String postId;
  final String content;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String authorPhotoUrl;
  final DateTime createdAt;

  ForumComment({
    required this.id,
    required this.postId,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.authorPhotoUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'authorPhotoUrl': authorPhotoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ForumComment.fromMap(Map<String, dynamic> map, String docId) {
    return ForumComment(
      id: docId,
      postId: map['postId'] ?? '',
      content: map['content'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? 'Anonymous',
      authorRole: map['authorRole'] ?? 'Student',
      authorPhotoUrl: map['authorPhotoUrl'] ?? '',
      createdAt: _dateTimeFromValue(map['createdAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _dateTimeFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
