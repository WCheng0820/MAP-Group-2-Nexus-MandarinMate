import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mandarinmate/models/user_model.dart';
import 'package:mandarinmate/services/auth_service.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthAppStarted extends AuthEvent {}

class AuthUserChanged extends AuthEvent {
  final User? user;

  const AuthUserChanged(this.user);

  @override
  List<Object?> get props => [user?.uid];
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email];
}

class AuthRegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String username;
  final String role;

  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.firstName,
    this.lastName = '',
    required this.username,
    required this.role,
  });

  @override
  List<Object?> get props => [email, username, role];
}

class AuthForgotPasswordRequested extends AuthEvent {
  final String email;

  const AuthForgotPasswordRequested(this.email);

  @override
  List<Object?> get props => [email];
}

class AuthGoogleSignInRequested extends AuthEvent {}

class AuthLogoutRequested extends AuthEvent {}

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  final UserProfile profile;

  const AuthAuthenticated({required this.user, required this.profile});

  @override
  List<Object?> get props => [user.uid, profile.uid, profile.updatedAt];
}

class AuthProfileIncomplete extends AuthState {
  final User user;

  const AuthProfileIncomplete(this.user);

  @override
  List<Object?> get props => [user.uid];
}

class AuthUnauthenticated extends AuthState {}

class AuthPasswordResetSent extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  StreamSubscription<User?>? _authSubscription;

  bool _isRegistering = false;

  AuthBloc({required AuthService authService})
    : _authService = authService,
      super(AuthInitial()) {
    on<AuthAppStarted>(_onAppStarted);
    on<AuthUserChanged>(_onUserChanged);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthForgotPasswordRequested>(_onForgotPasswordRequested);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onAppStarted(
    AuthAppStarted event,
    Emitter<AuthState> emit,
  ) async {
    _authSubscription ??= _authService.authStateChanges.listen(
      (user) => add(AuthUserChanged(user)),
    );
    add(AuthUserChanged(_authService.currentUser));
  }

  Future<void> _onUserChanged(
    AuthUserChanged event,
    Emitter<AuthState> emit,
  ) async {
    // If we are in the middle of a registration process, don't react to auth changes
    if (_isRegistering) {
      return;
    }

    final user = event.user;
    if (user == null) {
      emit(AuthUnauthenticated());
      return;
    }

    // Prevent proceeding if email requires verification but is not verified
    final requiresVerification = _authService.requiresEmailVerification(
      user.email ?? '',
    );
    if (requiresVerification && !user.emailVerified) {
      // We let the _onLoginRequested or _onRegisterRequested emit the respective state.
      return;
    }

    emit(AuthLoading());
    try {
      print("⏱️ Step 3: Fetching Firestore Profile..."); // <--- ADDED PRINT
      final profile = await _authService.getUserProfile(user.uid);
      print(
        "⏱️ Step 4: Firestore Profile Fetched! Routing...",
      ); // <--- ADDED PRINT

      if (profile == null) {
        emit(AuthProfileIncomplete(user));
        return;
      }
      emit(AuthAuthenticated(user: user, profile: profile));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final isUTMEmail = await _authService.isUTMEmail(event.email);
      if (!isUTMEmail) {
        emit(
          const AuthError(
            'Please use student(@graduate.utm.my), staff(@utm.my), or public(@gmail.com) email',
          ),
        );
        return;
      }

      print("⏱️ Step 1: Starting Firebase Auth Login..."); // <--- ADDED PRINT
      await _authService.login(
        email: event.email.trim(),
        password: event.password,
      );
      print("⏱️ Step 2: Firebase Auth Finished!"); // <--- ADDED PRINT

      final requiresVerification = _authService.requiresEmailVerification(
        event.email,
      );
      if (requiresVerification) {
        final isVerified = await _authService.isEmailVerified();
        if (!isVerified) {
          await _authService.logout(); // Logout unverified user immediately
          emit(const AuthError('EMAIL_UNVERIFIED'));
          return;
        }
      }

      // Allow it to naturally flow to AuthUserChanged or emit success if needed.
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final isUTMEmail = await _authService.isUTMEmail(event.email);
      if (!isUTMEmail) {
        emit(
          const AuthError(
            'Please use student(@graduate.utm.my), staff(@utm.my), or public(@gmail.com) email',
          ),
        );
        return;
      }

      _isRegistering = true; // Prevent automatic login routing

      final userCredential = await _authService.register(
        email: event.email.trim(),
        password: event.password,
      );

      final uid = userCredential.user?.uid;
      if (uid != null) {
        final parsedRole = event.role == 'Tutor'
            ? UserRole.tutor
            : UserRole.student;
        await _authService.createUserProfile(
          uid: uid,
          email: event.email.trim(),
          username: event.username.trim(),
          firstName: event.firstName.trim(),
          lastName: event.lastName.trim(),
          role: parsedRole,
        );
      }

      final requiresVerification = _authService.requiresEmailVerification(
        event.email,
      );
      if (requiresVerification) {
        await _authService.sendEmailVerification();
      }

      // Immediately log out after registration to force them to log in themselves
      await _authService.logout();

      _isRegistering =
          false; // Disable flag BEFORE emitting success so it doesn't get squashed
      add(
        const AuthUserChanged(null),
      ); // Ensures future states are recognized properly

      emit(const AuthError('REGISTRATION_SUCCESS'));
    } catch (e) {
      _isRegistering = false;
      add(const AuthUserChanged(null));
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onForgotPasswordRequested(
    AuthForgotPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.sendPasswordResetEmail(event.email.trim());
      emit(AuthPasswordResetSent());
      final user = _authService.currentUser;
      if (user == null) {
        emit(AuthUnauthenticated());
      } else {
        final profile = await _authService.getUserProfile(user.uid);
        if (profile == null) {
          emit(AuthProfileIncomplete(user));
        } else {
          emit(AuthAuthenticated(user: user, profile: profile));
        }
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.logout();
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    return super.close();
  }
}
