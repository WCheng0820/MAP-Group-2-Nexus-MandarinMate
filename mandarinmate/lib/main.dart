import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:mandarinmate/utils/app_theme.dart';
import 'package:mandarinmate/screens/splash_screen.dart';
import 'package:mandarinmate/screens/auth/auth_screen.dart';
import 'package:mandarinmate/screens/auth/role_selection_screen.dart';
import 'package:mandarinmate/screens/auth/profile_setup_screen.dart';
import 'package:mandarinmate/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    // If Android native already initialized it, just ignore the error and move on!
    print("Firebase auto-initialized successfully.");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MandarinMate UTM',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/auth': (context) => const AuthScreen(),
        '/login': (context) => const AuthScreen(),
        '/register': (context) => const AuthScreen(),
        '/role-selection': (context) => const RoleSelectionScreen(),
        '/profile-setup': (context) => const ProfileSetupScreen(),
        '/home': (context) => const HomeScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

