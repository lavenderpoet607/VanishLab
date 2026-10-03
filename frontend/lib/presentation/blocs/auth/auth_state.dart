import 'package:equatable/equatable.dart';
import '../../../data/models/auth_models.dart';
import '../../../data/models/quota_model.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState extends Equatable {
  final AuthStatus status;
  final User? user;
  final QuotaInfo? quotaInfo;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.quotaInfo,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    QuotaInfo? quotaInfo,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      quotaInfo: quotaInfo ?? this.quotaInfo,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, quotaInfo, errorMessage];
}
