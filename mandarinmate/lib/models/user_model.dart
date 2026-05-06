import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { student, tutor, admin }

enum MembershipStatus { pending, approved, rejected }

class UserProfile {
  final String uid;
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final String? age;
  final String? studentId;
  final String? faculty;
  final String? bio;
  final bool isProfileComplete;
  final UserRole role;
  final MembershipStatus membershipStatus;
  final String profileImageUrl;
  final int level;
  final int xpPoints;
  final int currentStreak;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.uid,
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.age,
    this.studentId,
    this.faculty,
    this.bio,
    this.isProfileComplete = false,
    required this.role,
    this.membershipStatus = MembershipStatus.pending,
    this.profileImageUrl = '',
    this.level = 1,
    this.xpPoints = 0,
    this.currentStreak = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      if (age != null) 'age': age,
      if (studentId != null) 'studentId': studentId,
      if (faculty != null) 'faculty': faculty,
      if (bio != null) 'bio': bio,
      'isProfileComplete': isProfileComplete,
      'role': role.toString().split('.').last,
      'membershipStatus': membershipStatus.toString().split('.').last,
      'profileImageUrl': profileImageUrl,
      'level': level,
      'xpPoints': xpPoints,
      'currentStreak': currentStreak,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      age: map['age'],
      studentId: map['studentId'],
      faculty: map['faculty'],
      bio: map['bio'],
      isProfileComplete: map['isProfileComplete'] == true,
      role: _roleFromString(map['role'] ?? 'student'),
      membershipStatus: _membershipStatusFromString(map['membershipStatus']),
      profileImageUrl: map['profileImageUrl'] ?? '',
      level: map['level'] ?? 1,
      xpPoints: map['xpPoints'] ?? 0,
      currentStreak: map['currentStreak'] ?? 0,
      createdAt: _dateTimeFromValue(map['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeFromValue(map['updatedAt']) ?? DateTime.now(),
    );
  }

  static UserRole _roleFromString(String role) {
    switch (role.toLowerCase()) {
      case 'tutor':
        return UserRole.tutor;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.student;
    }
  }

  static MembershipStatus _membershipStatusFromString(dynamic status) {
    switch ((status ?? '').toString().toLowerCase().split('.').last) {
      case 'pending':
        return MembershipStatus.pending;
      case 'rejected':
        return MembershipStatus.rejected;
      case 'approved':
      default:
        return MembershipStatus.approved;
    }
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

  String get displayName => '$firstName $lastName';

  String get membershipStatusLabel {
    switch (membershipStatus) {
      case MembershipStatus.approved:
        return 'Approved';
      case MembershipStatus.rejected:
        return 'Rejected';
      case MembershipStatus.pending:
        return 'Pending';
    }
  }
}
