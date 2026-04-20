import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mandarinmate/models/user_model.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Listen to auth state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Register with email and password
  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _getAuthError(e);
    }
  }

  // Login with email and password
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _getAuthError(e);
    }
  }

  // Create user profile in Firestore
  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String username,
    required String firstName,
    required String lastName,
    required UserRole role,
  }) async {
    try {
      final userProfile = UserProfile(
        uid: uid,
        email: email,
        username: username,
        firstName: firstName,
        lastName: lastName,
        role: role,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(uid).set(userProfile.toMap());
    } catch (e) {
      throw 'Failed to create user profile: $e';
    }
  }

  // Get user profile from Firestore
  Future<UserProfile?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw 'Failed to fetch user profile: $e';
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> updates,
  }) async {
    try {
      updates['updatedAt'] = DateTime.now().toIso8601String();
      await _firestore.collection('users').doc(uid).update(updates);
    } catch (e) {
      throw 'Failed to update user profile: $e';
    }
  }

  // Check if username exists
  Future<bool> usernameExists(String username) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      throw 'Failed to check username: $e';
    }
  }

  // Check if email is registered (for UTM email validation)
  Future<bool> isUTMEmail(String email) {
    // Check if email ends with UTM domain
    return Future.value(email.toLowerCase().endsWith('@student.utm.my') ||
        email.toLowerCase().endsWith('@utm.my'));
  }

  // Logout
  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw 'Failed to logout: $e';
    }
  }

  // Delete user account
  Future<void> deleteAccount(String uid) async {
    try {
      // Delete user from Firestore
      await _firestore.collection('users').doc(uid).delete();
      // Delete Firebase Auth user
      await currentUser?.delete();
    } catch (e) {
      throw 'Failed to delete account: $e';
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _getAuthError(e);
    }
  }

  // Helper method to get user-friendly error messages
  String _getAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Email not found. Please register first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'Email already registered. Please login or use another email.';
      case 'invalid-email':
        return 'Invalid email format.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }
}
