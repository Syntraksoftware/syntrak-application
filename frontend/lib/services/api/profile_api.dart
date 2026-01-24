import 'dart:io';
import 'package:dio/dio.dart';
import 'package:syntrak/models/profile.dart';
import 'api_client.dart';

class ProfileApi {
  final ApiClient _client;

  ProfileApi(this._client);

  Future<Profile> getCurrentUserProfile() async {
    final response = await _client.mainDio.get('/users/me/profile');
    return Profile.fromJson(response.data);
  }

  Future<Profile> updateProfile({
    String? fullName,
    String? username,
    String? bio,
    String? avatarUrl,
    String? pushToken,
    String? skiLevel,
    String? home,
  }) async {
    final data = <String, dynamic>{};
    if (fullName != null) data['full_name'] = fullName;
    if (username != null) data['username'] = username;
    if (bio != null) data['bio'] = bio;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    if (pushToken != null) data['push_token'] = pushToken;
    if (skiLevel != null) data['ski_level'] = skiLevel;
    if (home != null) data['home'] = home;
    final response = await _client.mainDio.put('/users/me/profile', data: data);
    return Profile.fromJson(response.data);
  }

  Future<Profile> getProfileById(String userId) async {
    try {
      final response = await _client.mainDio
          .get(
            '/users/$userId/profile',
            options: Options(receiveTimeout: const Duration(seconds: 10)),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout. Please check your connection.');
            },
          );
      return Profile.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response != null && e.response!.data != null) {
        final errorData = e.response!.data;
        if (errorData is Map && errorData['detail'] != null) {
          throw Exception(errorData['detail']);
        }
      }
      if (e.response?.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (e.response?.statusCode == 404) {
        throw Exception('Profile not found');
      } else if (e.response?.statusCode == 503) {
        throw Exception('Database not configured');
      } else if (e.response?.statusCode == 500) {
        throw Exception('Server error. Please try again later.');
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(
            'Connection timeout. Please check your internet connection.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Cannot connect to server. Is the backend running?');
      }
      throw Exception('Failed to get profile: ${e.message ?? "Unknown error"}');
    }
  }

  Future<Profile> uploadAvatar(File imageFile) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.path.split('/').last,
      ),
    });
    final response = await _client.mainDio.post(
      '/users/me/profile/avatar',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return Profile.fromJson(response.data);
  }
}
