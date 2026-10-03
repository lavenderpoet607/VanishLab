class User {
  final String id;
  final String email;
  final int dailyQuota;
  final int usedQuotaToday;
  final bool isActive;
  final bool isSuperuser;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.email,
    required this.dailyQuota,
    required this.usedQuotaToday,
    required this.isActive,
    required this.isSuperuser,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      dailyQuota: json['daily_quota'] as int? ?? 50,
      usedQuotaToday: json['used_quota_today'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      isSuperuser: json['is_superuser'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'daily_quota': dailyQuota,
      'used_quota_today': usedQuotaToday,
      'is_active': isActive,
      'is_superuser': isSuperuser,
    };
  }

  int get remainingQuota => (dailyQuota - usedQuotaToday).clamp(0, dailyQuota);
}

class AuthToken {
  final String accessToken;
  final String tokenType;
  final int expiresIn;

  AuthToken({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    return AuthToken(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: json['expires_in'] as int? ?? 86400,
    );
  }
}
