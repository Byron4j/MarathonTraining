import 'model_utils.dart';

class User {
  final String id;
  final String email;
  final String? nickname;
  final int? createdAt;

  const User({
    required this.id,
    required this.email,
    this.nickname,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: asString(json['id']) ?? '',
      email: asString(json['email']) ?? '',
      nickname: asString(json['nickname']),
      createdAt: asEpochMs(json['createdAt']),
    );
  }
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final int? expiresIn;

  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    this.expiresIn,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: asString(json['accessToken']) ?? '',
      refreshToken: asString(json['refreshToken']) ?? '',
      expiresIn: asInt(json['expiresIn']),
    );
  }
}

class AuthResult {
  final User user;
  final AuthTokens tokens;

  const AuthResult({required this.user, required this.tokens});

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      user: User.fromJson(asMap(json['user'])),
      tokens: AuthTokens.fromJson(asMap(json['tokens'])),
    );
  }
}
