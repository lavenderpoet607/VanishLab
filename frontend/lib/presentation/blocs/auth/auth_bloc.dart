import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required this._authRepository})
      : super(const AuthState()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<LoginSubmittedEvent>(_onLoginSubmitted);
    on<RegisterSubmittedEvent>(_onRegisterSubmitted);
    on<RefreshQuotaEvent>(_onRefreshQuota);
    on<ResetQuotaEvent>(_onResetQuota);
    on<LogoutEvent>(_onLogout);
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final isAuth = await _authRepository.isAuthenticated();
      if (isAuth) {
        final user = await _authRepository.getCurrentUser();
        final quota = await _authRepository.getQuota();
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          quotaInfo: quota,
        ));
      } else {
        final quota = await _authRepository.getQuota();
        emit(state.copyWith(
          status: AuthStatus.unauthenticated,
          user: null,
          quotaInfo: quota,
        ));
      }
    } catch (_) {
      try {
        final quota = await _authRepository.getQuota();
        emit(state.copyWith(
          status: AuthStatus.unauthenticated,
          user: null,
          quotaInfo: quota,
        ));
      } catch (e) {
        emit(state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  Future<void> _onLoginSubmitted(
    LoginSubmittedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      await _authRepository.login(email: event.email, password: event.password);
      final user = await _authRepository.getCurrentUser();
      final quota = await _authRepository.getQuota();
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        quotaInfo: quota,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRegisterSubmitted(
    RegisterSubmittedEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      await _authRepository.register(email: event.email, password: event.password);
      await _authRepository.login(email: event.email, password: event.password);
      final user = await _authRepository.getCurrentUser();
      final quota = await _authRepository.getQuota();
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        quotaInfo: quota,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRefreshQuota(
    RefreshQuotaEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final quota = await _authRepository.getQuota();
      emit(state.copyWith(quotaInfo: quota));
    } catch (_) {}
  }

  Future<void> _onResetQuota(
    ResetQuotaEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final quota = await _authRepository.resetQuota();
      emit(state.copyWith(quotaInfo: quota));
    } catch (_) {}
  }

  Future<void> _onLogout(
    LogoutEvent event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    final quota = await _authRepository.getQuota();
    emit(state.copyWith(
      status: AuthStatus.unauthenticated,
      user: null,
      quotaInfo: quota,
    ));
  }
}
