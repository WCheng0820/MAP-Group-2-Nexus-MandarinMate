import 'dart:async'; // [NEW] Needed for the waiting logic!
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:mandarinmate/services/notification_service.dart';
import 'firebase_options.dart';
import 'package:mandarinmate/app_router.dart';
import 'package:mandarinmate/auth/presentation/bloc/auth_bloc.dart';
import 'package:mandarinmate/services/auth_service.dart';
import 'package:mandarinmate/utils/app_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();

  await Supabase.initialize(
    url: 'https://nigwphcqqfrvhmnxyppj.supabase.co',
    anonKey: 'sb_publishable_gD-lXnpHovmnU6VBdKwWZg_aoTBZIo9',
  );

  if (_supportsFirebaseOnCurrentPlatform) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    runApp(const MyApp());
    return;
  }

  runApp(const UnsupportedPlatformApp());
}

bool get _supportsFirebaseOnCurrentPlatform {
  if (kIsWeb) {
    return true;
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      return true;
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return false;
  }
}

class UnsupportedPlatformApp extends StatelessWidget {
  const UnsupportedPlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MandarinMate UTM',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.desktop_access_disabled_rounded, size: 56),
                  SizedBox(height: 16),
                  Text(
                    'Linux desktop is not configured for this project yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(authService: AuthService())..add(AuthAppStarted());
    _router = buildAppRouter(_authBloc);

    _notificationService.initializeNotifications();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      if (message.notification != null) {
        print('Notification Title: ${message.notification!.title}');
      }
    });

    _setupInteractedMessage();
  }

  Future<void> _setupInteractedMessage() async {
    RemoteMessage? initialMessage =
    await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
  }

  // --- THE FIX IS HERE ---
  void _handleMessageTap(RemoteMessage message) {
    if (message.data.containsKey('chatId')) {
      final String chatId = message.data['chatId'];
      final String receiverId = message.data['senderId'] ?? '';
      final String receiverName = message.data['senderName'] ?? 'User';

      // SCENARIO 1: The app was already running in the background.
      // The user is already logged in, so it's safe to push the chat immediately!
      if (_authBloc.state is AuthAuthenticated) {
        _router.push('/chat', extra: {
          'chatId': chatId,
          'receiverId': receiverId,
          'receiverName': receiverName,
        });
      }

      // SCENARIO 2: The app was totally closed (Terminated).
      // We must wait for the Auto-Login to finish its job first.
      else {
        late StreamSubscription sub;
        sub = _authBloc.stream.listen((state) {
          if (state is AuthAuthenticated) {
            // Once logged in, give GoRouter half a second to land on the Dashboard
            Future.delayed(const Duration(milliseconds: 500), () {
              _router.push('/chat', extra: {
                'chatId': chatId,
                'receiverId': receiverId,
                'receiverName': receiverName,
              });
            });
            // Stop listening once we've successfully opened the chat
            sub.cancel();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: MaterialApp.router(
        title: 'MandarinMate UTM',
        theme: AppTheme.lightTheme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}