enum UserRole { student, tutor, admin }

class UserProfile {
  final String uid;
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final UserRole role;
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
    required this.role,
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
      'role': role.toString().split('.').last,
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
      role: _roleFromString(map['role'] ?? 'student'),
      profileImageUrl: map['profileImageUrl'] ?? '',
      level: map['level'] ?? 1,
      xpPoints: map['xpPoints'] ?? 0,
      currentStreak: map['currentStreak'] ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
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

  String get displayName => '$firstName $lastName';
}
