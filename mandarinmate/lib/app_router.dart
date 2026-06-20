import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mandarinmate/auth/presentation/bloc/auth_bloc.dart';
import 'package:mandarinmate/models/user_model.dart';
import 'package:mandarinmate/screens/profile/edit_profile_page.dart'
as mandarinmate_edit_profile;
import 'package:mandarinmate/dashboard/admin_dashboard_page.dart';
import 'package:mandarinmate/dashboard/tutor_dashboard_page.dart';
import 'package:mandarinmate/screens/auth/auth_screen.dart';
import 'package:mandarinmate/screens/auth/forgot_password_page.dart';
import 'package:mandarinmate/screens/gamified_showcase_page.dart';
import 'package:mandarinmate/screens/main_screen.dart';
import 'package:mandarinmate/screens/home_screen.dart';
import 'package:mandarinmate/screens/splash_screen.dart';
import 'package:mandarinmate/screens/chat_screen.dart';

class GoRouterRefreshBloc extends ChangeNotifier {
  GoRouterRefreshBloc(AuthBloc bloc) {
    _subscription = bloc.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

GoRouter buildAppRouter(AuthBloc authBloc) {
  final refreshListenable = GoRouterRefreshBloc(authBloc);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = authBloc.state;
      final location = state.matchedLocation;

      final isAuthRoute = location == '/auth' || location == '/login' || location == '/forgot-password' || location == '/';

      // --- THE ULTIMATE ROUTING LOGIC ---

      // 1. If we are still checking Firebase (Loading), stay exactly where we are
      // (This prevents the app from breaking the Chat deep link!)
      if (authState is AuthInitial || authState is AuthLoading) {
        return null;
      }

      // 2. If the user is completely logged out
      if (authState is AuthUnauthenticated) {
        // Allow them to sit on the login screens or gamified UI
        if (isAuthRoute || location == '/ui-gamified') {
          return null;
        }
        // If they are anywhere else (like Splash or Dashboard), kick them to Login
        return '/auth';
      }

      // 3. If the user IS logged in successfully
      if (authState is AuthAuthenticated) {
        final profile = authState.profile;
        final role = profile.role;

        // Force profile setup if missing
        if (!profile.isProfileComplete && location != '/edit-profile-onboarding') {
          return '/edit-profile-onboarding';
        }

        // If they are on the Splash Screen OR a Login Screen, push them straight to their Dashboard!
        if (location == '/splash' || isAuthRoute || (profile.isProfileComplete && location == '/edit-profile-onboarding')) {
          if (role == UserRole.student) return '/main';
          if (role == UserRole.tutor) return '/tutor-dashboard';
          if (role == UserRole.admin) return '/admin-dashboard';
        }

        // Protect dashboards from the wrong roles
        if (location == '/main' && role != UserRole.student) return '/tutor-dashboard';
        if (location == '/tutor-dashboard' && role != UserRole.tutor) return '/main';
      }

      return null; // Allows deep links (like /chat) to pass through safely!
    },

    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(path: '/main', builder: (context, state) => const MainScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/tutor-dashboard',
        builder: (context, state) => const TutorDashboardPage(),
      ),
      GoRoute(
        path: '/admin-dashboard',
        builder: (context, state) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: '/edit-profile-onboarding',
        builder: (context, state) =>
        const mandarinmate_edit_profile.EditProfilePage(
          roleColor: Color(0xFFD32F2F),
          isFirstTime: true,
        ),
      ),
      GoRoute(
        path: '/ui-gamified',
        builder: (context, state) => const GamifiedShowcasePage(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return ChatScreen(
            chatId: extra['chatId'] ?? '',
            receiverName: extra['receiverName'] ?? 'User',
            receiverId: extra['receiverId'] ?? '',
          );
        },
      ),
    ],
  );
}