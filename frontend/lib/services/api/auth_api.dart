import 'package:dio/dio.dart';
import 'api_client.dart';

/// Auth: register, login, refresh token 

class AuthApi {
  final ApiClient _client;

  AuthApi(this._client);

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final data = <String, dynamic>{'email': email, 'password': password};
      if (firstName != null && firstName.isNotEmpty) data['first_name'] = firstName;
      if (lastName != null && lastName.isNotEmpty) data['last_name'] = lastName;

      final response = await _client.mainDio.post('/auth/register', data: data);
      return response.data;
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e.response?.data) ??
          _messageForRegistrationStatus(e.response?.statusCode) ??
          'Registration failed: ${e.message ?? "Unknown error"}';
      throw Exception(msg);
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.mainDio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      return response.data;
    } on DioException catch (e) {
      final msg = _extractErrorMessage(e.response?.data) ??
          _messageForLoginStatus(e.response?.statusCode) ??
          'Login failed: ${e.message}';
      throw Exception(msg);
    }
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await _client.mainDio.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });
      return response.data;
    } on DioException catch (e) {
      final msg = e.response?.statusCode == 401
          ? 'Refresh token expired. Please login again.'
          : 'Token refresh failed: ${e.message}';
      throw Exception(msg);
    }
  }

  /// Tries to derive a user-facing message from API error payload.
  /// Handles: error, message, detail (String or Pydantic-style List).
  static String? _extractErrorMessage(dynamic data) {
    if (data == null || data is! Map) return null;
    final d = data;

    if (d['error'] != null) return d['error'].toString();
    if (d['message'] != null) return d['message'].toString();

    final det = d['detail'];
    if (det == null) return null;
    if (det is String) return det;
    if (det is List) {
      final parts = det.map((e) {
        if (e is Map) return '${e['loc']?.join('.') ?? ''}: ${e['msg'] ?? e}';
        return e.toString();
      }).join(', ');
      return 'Validation error: $parts';
    }
    return null;
  }

  static String? _messageForRegistrationStatus(int? code) {
    switch (code) {
      case 409:
        return 'An account with this email already exists. Please login instead.';
      case 400:
        return 'Invalid registration data. Please check your input.';
      case 422:
        return 'Invalid registration data. Please check that your email is valid and password is at least 8 characters.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return null;
    }
  }

  static String? _messageForLoginStatus(int? code) {
    switch (code) {
      case 401:
        return 'Invalid email or password. Please try again.';
      case 400:
        return 'Invalid login data. Please check your input.';
      default:
        return null;
    }
  }
}
