import 'dart:io';
import 'package:syntrak/models/activity.dart';
import 'package:syntrak/models/user.dart';
import 'package:syntrak/models/profile.dart';
import 'package:syntrak/services/api/api_client.dart';
import 'package:syntrak/services/api/auth_api.dart';
import 'package:syntrak/services/api/user_api.dart';
import 'package:syntrak/services/api/activity_api.dart';
import 'package:syntrak/services/api/profile_api.dart';
import 'package:syntrak/services/api/community_api.dart';

/// Shared HTTP client (Dio + Token for main and community)
/// Dio == third-party HTTP networking package for Dart and Flutter
/// Facade over feature-specific API clients. Preserves the existing public API.
/// Use 127.0.0.1 instead of localhost for iOS simulator compatibility.

class ApiService {
  final ApiClient _client = ApiClient();
  late final AuthApi _authApi = AuthApi(_client);
  late final UserApi _userApi = UserApi(_client);
  late final ActivityApi _activityApi = ActivityApi(_client);
  late final ProfileApi _profileApi = ProfileApi(_client);
  late final CommunityApi _communityApi = CommunityApi(_client);

  static const String baseUrl = 'http://127.0.0.1:8080/api/v1';

  void setToken(String? token) {
    _client.setToken(token);
  }

  // Auth 
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) =>
      _authApi.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) =>
      _authApi.login(email: email, password: password);

  Future<Map<String, dynamic>> refreshToken(String refreshToken) =>
      _authApi.refreshToken(refreshToken);

  // User 
  Future<User> getCurrentUser() => _userApi.getCurrentUser();

  Future<User> updateUserProfile({String? firstName, String? lastName}) =>
      _userApi.updateUserProfile(firstName: firstName, lastName: lastName);

  // Activity
  Future<Activity> createActivity(Activity activity) =>
      _activityApi.createActivity(activity);

  Future<List<Activity>> getActivities({int page = 1, int limit = 20}) =>
      _activityApi.getActivities(page: page, limit: limit);

  Future<Activity> getActivity(String id) => _activityApi.getActivity(id);

  Future<Activity> updateActivity(
    String id, {
    String? name,
    String? description,
    bool? isPublic,
  }) =>
      _activityApi.updateActivity(id,
          name: name, description: description, isPublic: isPublic);

  Future<void> deleteActivity(String id) => _activityApi.deleteActivity(id);

  // Profile 
  Future<Profile> getCurrentUserProfile() => _profileApi.getCurrentUserProfile();

  Future<Profile> updateProfile({
    String? fullName,
    String? username,
    String? bio,
    String? avatarUrl,
    String? pushToken,
    String? skiLevel,
    String? home,
  }) =>
      _profileApi.updateProfile(
        fullName: fullName,
        username: username,
        bio: bio,
        avatarUrl: avatarUrl,
        pushToken: pushToken,
        skiLevel: skiLevel,
        home: home,
      );

  Future<Profile> getProfileById(String userId) =>
      _profileApi.getProfileById(userId);

  Future<Profile> uploadAvatar(File imageFile) =>
      _profileApi.uploadAvatar(imageFile);

  // Community (posts)
  Future<Map<String, dynamic>> createCommunityPost({
    required String subthreadId,
    required String title,
    required String content,
  }) =>
      _communityApi.createPost(
        subthreadId: subthreadId,
        title: title,
        content: content,
      );

  Future<List<Map<String, dynamic>>> getPostsBySubthread(
    String subthreadId, {
    int limit = 20,
    int offset = 0,
  }) =>
      _communityApi.getPostsBySubthread(subthreadId,
          limit: limit, offset: offset);

  Future<List<Map<String, dynamic>>> getSubthreads({int limit = 50}) =>
      _communityApi.getSubthreads(limit: limit);

  Future<List<Map<String, dynamic>>> getPostsByUserId(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) =>
      _communityApi.getPostsByUserId(userId, limit: limit, offset: offset);
}
