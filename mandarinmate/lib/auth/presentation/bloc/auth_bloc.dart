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

  const AuthRegisterRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email];
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
    final user = event.user;
    if (user == null) {
      emit(AuthUnauthenticated());
      return;
    }

    emit(AuthLoading());
    try {
      final profile = await _authService.getUserProfile(user.uid);
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
            'Please use your UTM email (@student.utm.my or @utm.my)',
          ),
        );
        return;
      }
      await _authService.login(
        email: event.email.trim(),
        password: event.password,
      );
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
      await _authService.register(
        email: event.email.trim(),
        password: event.password,
      );
    } catch (e) {
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
