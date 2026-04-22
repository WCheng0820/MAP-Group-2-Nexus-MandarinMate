import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mandarinmate/auth/presentation/bloc/auth_bloc.dart';
import 'package:mandarinmate/models/user_model.dart';
import 'package:mandarinmate/dashboard/admin_dashboard_page.dart';
import 'package:mandarinmate/dashboard/tutor_dashboard_page.dart';
import 'package:mandarinmate/screens/auth/auth_screen.dart';
import 'package:mandarinmate/screens/auth/forgot_password_page.dart';
import 'package:mandarinmate/screens/gamified_showcase_page.dart';
import 'package:mandarinmate/screens/main_screen.dart';
import 'package:mandarinmate/screens/home_screen.dart';
import 'package:mandarinmate/screens/splash_screen.dart';

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
      final isAuthRoute =
          location == '/auth' ||
          location == '/login' ||
          location == '/forgot-password';
      final isProtectedRoute =
          location == '/main' ||
          location == '/home' ||
          location == '/tutor-dashboard' ||
          location == '/admin-dashboard';
      final isPublicRoute =
          location == '/splash' || location == '/ui-gamified' || isAuthRoute;

      if (location == '/splash') {
        return null;
      }

      if (authState is AuthUnauthenticated && !isPublicRoute) {
        return '/auth';
      }

      // --- THE FIX IS HERE ---
      if (authState is AuthAuthenticated) {
        final role = authState.profile.role;

        // 1. If they are already logged in but sitting on the Login/Register screen,
        // immediately redirect them to their specific dashboard.
        if (isAuthRoute) {
          if (role == UserRole.student) return '/main';
          if (role == UserRole.tutor) return '/tutor-dashboard';
          if (role == UserRole.admin) return '/admin-dashboard';
        }

        // 2. If they are trying to access the WRONG dashboard for their role,
        // redirect them to the correct one.
        if (isProtectedRoute) {
          if (role == UserRole.student && location != '/main') {
            return '/main';
          }
          if (role == UserRole.tutor && location != '/tutor-dashboard') {
            return '/tutor-dashboard';
          }
          if (role == UserRole.admin && location != '/admin-dashboard') {
            return '/admin-dashboard';
          }
        }
      }

      return null;
    }, // End of redirect

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
        path: '/ui-gamified',
        builder: (context, state) => const GamifiedShowcasePage(),
      ),
    ],
  );
}
