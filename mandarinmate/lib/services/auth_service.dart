import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mandarinmate/models/user_model.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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
      // Menambahkan .trim() untuk menghindari spasi tak sengaja
      UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(
            email: email.trim(),
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
      UserCredential userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(email: email.trim(), password: password);
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _getAuthError(e);
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw 'Google sign-in cancelled.';
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _getAuthError(e);
    } catch (e) {
      throw e.toString();
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
        email: email.trim(),
        username: username,
        firstName: firstName,
        lastName: lastName,
        role: role,
        membershipStatus: role == UserRole.admin
            ? MembershipStatus.approved
            : MembershipStatus.pending,
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
          .where('username', isEqualTo: username.toLowerCase().trim())
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      throw 'Failed to check username: $e';
    }
  }

  // ============================================================
  // Validasi Email yang Diizinkan dan Email Verification
  // ============================================================
  Future<bool> isUTMEmail(String email) {
    final lowerEmail = email.toLowerCase().trim();
    return Future.value(
      lowerEmail.endsWith('@graduate.utm.my') ||
          lowerEmail.endsWith('@utm.my') ||
          lowerEmail.endsWith('@gmail.com'),
    );
  }

  bool requiresEmailVerification(String email) {
    final lowerEmail = email.toLowerCase().trim();
    if (lowerEmail == 'student@utm.my' ||
        lowerEmail == 'tutor@utm.my' ||
        lowerEmail == 'admin@utm.my') {
      return false; // Dummy accounts do not need verification
    }
    return true;
  }

  Future<bool> isEmailVerified() async {
    final user = currentUser;
    if (user != null) {
      await user.reload(); // Reload to get the latest verification status
      return user.emailVerified;
    }
    return false;
  }

  Future<void> sendEmailVerification() async {
    final user = currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
    } catch (e) {
      throw 'Failed to logout: $e';
    }
  }

  // Delete user account
  Future<void> deleteAccount(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
      await currentUser?.delete();
    } catch (e) {
      throw 'Failed to delete account: $e';
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _getAuthError(e);
    }
  }

  // Helper method
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
