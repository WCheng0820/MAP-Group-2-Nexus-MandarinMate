import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'package:mandarinmate/utils/app_theme.dart';
import 'package:mandarinmate/screens/splash_screen.dart';
import 'package:mandarinmate/screens/auth/auth_screen.dart';
import 'package:mandarinmate/screens/auth/role_selection_screen.dart';
import 'package:mandarinmate/screens/auth/profile_setup_screen.dart';
import 'package:mandarinmate/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load();
  } catch (e) {
    // .env file is optional
    debugPrint('Note: .env file not found or could not be loaded');
  }
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      rethrow;
    }
    // Silently ignore duplicate-app error
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

