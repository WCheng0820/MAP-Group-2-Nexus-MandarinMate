import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';


class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final StreamController<String?> selectNotificationStream = StreamController<String?>.broadcast();

  void initializeNotifications() async {
    // 1. Request permission right away
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permissions.');

      // Initialize local notifications for foreground pop-ups
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: DarwinInitializationSettings(),
      );

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            selectNotificationStream.add(payload);
          }
        },
      );

      // Create high importance channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
      }

      // Listen for foreground Firebase messages and present them locally
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        print('Got a foreground message: ${message.messageId}');
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null) {
          await _localNotifications.show(
            id: notification.hashCode,
            title: notification.title,
            body: notification.body,
            payload: jsonEncode(message.data),
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: android?.smallIcon ?? '@mipmap/launcher_icon',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
                enableVibration: true,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
          );
        }
      });

      // Listen for exactly when the user logs in!
      _auth.authStateChanges().listen((User? user) async {
        if (user != null) {
          print("User is logged in! Saving FCM token to database...");
          await saveDeviceToken();
        }
      });

      // Listen for token refreshes (in case the device token changes)
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

  // Send in-app notification to a specific user
  static Future<void> sendInAppNotification({
    required String recipientId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final payload = <String, dynamic>{
        'recipientId': recipientId,
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (extra != null) {
        payload.addAll(extra);
      }
      await FirebaseFirestore.instance.collection('notifications').add(payload);
    } catch (e) {
      debugPrint('Error sending in-app notification: $e');
    }
  }

  // Notify all students
  static Future<void> notifyAllStudents({
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        final notifRef = FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(notifRef, {
          'recipientId': doc.id,
          'title': title,
          'body': body,
          'type': type,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error notifying all students: $e');
    }
  }

  // Notify a specific role (or all users)
  static Future<void> notifyTargetRole({
    required String targetRole,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      Query query = FirebaseFirestore.instance.collection('users');
      if (targetRole != 'all') {
        query = query.where('role', isEqualTo: targetRole);
      }
      final snapshot = await query.get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        final notifRef = FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(notifRef, {
          'recipientId': doc.id,
          'title': title,
          'body': body,
          'type': type,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      // If targetRole is admin, also send to recipientId: 'admin' just in case
      if (targetRole == 'admin' || targetRole == 'all') {
        final adminNotifRef = FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(adminNotifRef, {
          'recipientId': 'admin',
          'title': title,
          'body': body,
          'type': type,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error notifying target role ($targetRole): $e');
    }
  }

  // Show a native system notification banner
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch % 1000000,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }
}