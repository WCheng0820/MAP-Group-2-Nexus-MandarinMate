import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void initializeNotifications() async {
    // 1. Request permission right away
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permissions.');

      // ---------------------------------------------------------
      // [THE FIX] Listen for exactly when the user logs in!
      // ---------------------------------------------------------
      _auth.authStateChanges().listen((User? user) async {
        if (user != null) {
          print("User is logged in! Saving FCM token to database...");
          await saveDeviceToken();
        }
      });

      // 3. Listen for token refreshes (in case the device token changes)
      _fcm.onTokenRefresh.listen((newToken) async {
        await _updateTokenInFirestore(newToken);
      });
    }
  }

  Future<void> saveDeviceToken() async {
    String? token = await _fcm.getToken();
    if (token != null) {
      await _updateTokenInFirestore(token);
    }
  }

  Future<void> _updateTokenInFirestore(String token) async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      print("Saving token for user: ${currentUser.uid}");
      // Save token to the user's document so the server can find it later
      await _db.collection('users').doc(currentUser.uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    }
  }
}