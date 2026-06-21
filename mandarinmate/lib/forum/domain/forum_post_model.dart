import 'package:cloud_firestore/cloud_firestore.dart';

class ForumPost {
  final String id;
  final String title;
  final String content;
  final String category;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String authorPhotoUrl;
  final DateTime createdAt;
  final List<String> likes;
  final int commentCount;
  final int sharesCount;

  ForumPost({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.authorPhotoUrl,
    required this.createdAt,
    required this.likes,
    required this.commentCount,
    required this.sharesCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'authorId': authorId,
      'authorName': authorName,
      'authorRole': authorRole,
      'authorPhotoUrl': authorPhotoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'commentCount': commentCount,
      'sharesCount': sharesCount,
    };
  }

  factory ForumPost.fromMap(Map<String, dynamic> map, String docId) {
    return ForumPost(
      id: docId,
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      category: map['category'] ?? 'General',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? 'Anonymous',
      authorRole: map['authorRole'] ?? 'Student',
      authorPhotoUrl: map['authorPhotoUrl'] ?? '',
      createdAt: _dateTimeFromValue(map['createdAt']) ?? DateTime.now(),
      likes: List<String>.from(map['likes'] ?? []),
      commentCount: map['commentCount'] ?? 0,
      sharesCount: map['sharesCount'] ?? 0,
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
