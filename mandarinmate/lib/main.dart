import 'dart:async'; // [NEW] Needed for the waiting logic!
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mandarinmate/services/notification_service.dart';
import 'firebase_options.dart';
import 'package:mandarinmate/app_router.dart';
import 'package:mandarinmate/auth/presentation/bloc/auth_bloc.dart';
import 'package:mandarinmate/services/auth_service.dart';
import 'package:mandarinmate/utils/app_theme.dart';
import 'package:mandarinmate/forum/presentation/pages/post_detail_page.dart';
import 'package:mandarinmate/lessons/presentation/pages/lessons_page.dart';
import 'package:mandarinmate/flashcards/presentation/pages/flashcard_levels_page.dart';
import 'package:mandarinmate/screens/student_announcement_page.dart';
import 'package:mandarinmate/tutor/presentation/pages/tutor_announcement_page.dart';
import 'package:mandarinmate/dashboard/admin_users_page.dart';
import 'package:mandarinmate/screens/main_screen.dart';
import 'package:mandarinmate/utils/app_language.dart';
import 'package:mandarinmate/models/user_model.dart';

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
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5pZ3dwaGNxcWZydmhtbnh5cHBqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg1NjczMDAsImV4cCI6MjA5NDE0MzMwMH0.iLdHrAPkCBVZ5oC_i7ZQCwsK5CG-_DNkEXnY_rtIIqA',
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

  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;
  final NotificationService _notificationService = NotificationService();
  StreamSubscription? _selectNotificationSubscription;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc(authService: AuthService())..add(AuthAppStarted());
    _router = buildAppRouter(_authBloc);

    _notificationService.initializeNotifications();

    _selectNotificationSubscription = NotificationService.selectNotificationStream.stream.listen((String? payload) {
      if (payload != null && payload.isNotEmpty) {
        try {
          final Map<String, dynamic> data = jsonDecode(payload);
          _handleNotificationDataTap(data);
        } catch (e) {
          debugPrint('Error parsing notification payload: $e');
        }
      }
    });

    _setupInteractedMessage();
    _loadSettingsPreference();
  }

  Future<void> _loadSettingsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final darkMode = prefs.getBool('dark_mode') ?? false;
    MyApp.themeNotifier.value = darkMode ? ThemeMode.dark : ThemeMode.light;
    final lang = prefs.getString('language') ?? 'English';
    AppLanguage.languageNotifier.value = lang;
  }

  Future<void> _setupInteractedMessage() async {
    RemoteMessage? initialMessage =
    await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
  }

  void _handleMessageTap(RemoteMessage message) {
    _handleNotificationDataTap(message.data);
  }

  void _handleNotificationDataTap(Map<String, dynamic> data) {
    if (_authBloc.state is AuthAuthenticated) {
      final role = (_authBloc.state as AuthAuthenticated).profile.role;
      _performRedirection(data, role);
    } else {
      late StreamSubscription sub;
      sub = _authBloc.stream.listen((state) {
        if (state is AuthAuthenticated) {
          Future.delayed(const Duration(milliseconds: 500), () {
            _performRedirection(data, state.profile.role);
          });
          sub.cancel();
        }
      });
    }
  }

  void _performRedirection(Map<String, dynamic> data, UserRole role) {
    final type = data['type'] ?? '';
    final roleStr = role == UserRole.admin ? 'admin' : (role == UserRole.tutor ? 'tutor' : 'student');

    final context = _router.routerDelegate.navigatorKey.currentContext;
    if (context == null) return;

    switch (type) {
      case 'chat':
        final chatId = data['chatId'] ?? '';
        final senderId = data['senderId'] ?? '';
        final senderName = data['senderName'] ?? 'Chat';
        if (chatId.isNotEmpty) {
          _router.push('/chat', extra: {
            'chatId': chatId,
            'receiverId': senderId,
            'receiverName': senderName,
          });
        }
        break;
      case 'forum_like':
      case 'forum_comment':
        final postId = data['postId'] ?? '';
        if (postId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailPage(
                postId: postId,
                themeColor: roleStr == 'tutor'
                    ? const Color(0xFF0F6E56)
                    : (roleStr == 'admin' ? const Color(0xFF6C3BFF) : const Color(0xFFFF8A21)),
              ),
            ),
          );
        }
        break;
      case 'vocab_unit':
      case 'lesson_material':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LessonsPage(),
          ),
        );
        break;
      case 'flashcards':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const FlashcardLevelsPage(),
          ),
        );
        break;
      case 'announcement':
        if (roleStr == 'student') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StudentAnnouncementPage(),
            ),
          );
        } else if (roleStr == 'tutor') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TutorAnnouncementPage(),
            ),
          );
        }
        break;
      case 'tutor_registration':
        if (roleStr == 'admin') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminUsersPage(),
            ),
          );
        }
        break;
      case 'streak':
      case 'streak_missed':
        if (roleStr == 'student') {
          MainScreen.openDailyChallenge(context);
        }
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _selectNotificationSubscription?.cancel();
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authBloc,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: MyApp.themeNotifier,
        builder: (_, themeMode, __) {
          return ValueListenableBuilder<String>(
            valueListenable: AppLanguage.languageNotifier,
            builder: (context, currentLanguage, _) {
              return MaterialApp.router(
                title: 'MandarinMate UTM',
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeMode,
                routerConfig: _router,
                debugShowCheckedModeBanner: false,
              );
            },
          );
        },
      ),
    );
  }
}