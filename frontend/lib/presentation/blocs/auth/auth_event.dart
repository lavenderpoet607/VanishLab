import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class CheckAuthStatusEvent extends AuthEvent {}

class LoginSubmittedEvent extends AuthEvent {
  final String email;
  final String password;

  LoginSubmittedEvent({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class RegisterSubmittedEvent extends AuthEvent {
  final String email;
  final String password;

  RegisterSubmittedEvent({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class RefreshQuotaEvent extends AuthEvent {}

class ResetQuotaEvent extends AuthEvent {}

class LogoutEvent extends AuthEvent {}
