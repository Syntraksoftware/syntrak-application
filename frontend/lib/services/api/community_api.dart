import 'package:dio/dio.dart';
import 'api_client.dart';

class CommunityApi {
  final ApiClient _client;

  CommunityApi(this._client);

  /// POST /posts — create a post in a subthread. Requires auth.
  Future<Map<String, dynamic>> createPost({
    required String subthreadId,
    required String title,
    required String content,
  }) async {
    try {
      final response = await _client.communityDio
          .post(
            '/posts',
            data: {
              'subthread_id': subthreadId,
              'title': title,
              'content': content,
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout. Please check your connection.');
            },
          );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      }
      if (e.response?.statusCode == 404) {
        throw Exception('Subthread not found');
      }
      if (e.response?.statusCode == 500) {
        throw Exception('Server error. Please try again later.');
      }
      throw Exception('Failed to create post: ${e.message ?? "Unknown error"}');
    }
  }

  /// GET /subthreads/{id}/posts — list posts in a subthread.
  Future<List<Map<String, dynamic>>> getPostsBySubthread(
    String subthreadId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _client.communityDio
          .get(
            '/subthreads/$subthreadId/posts',
            queryParameters: {'limit': limit, 'offset': offset},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout. Please check your connection.');
            },
          );
      if (response.data is Map && response.data['posts'] != null) {
        return List<Map<String, dynamic>>.from(response.data['posts']);
      }
      return [];
    } on DioException {
      return [];
    } catch (_) {
      return [];
    }
  }

  /// GET /subthreads — list subthreads (e.g. to pick a default).
  Future<List<Map<String, dynamic>>> getSubthreads({int limit = 50}) async {
    try {
      final response = await _client.communityDio
          .get('/subthreads', queryParameters: {'limit': limit})
          .timeout(const Duration(seconds: 10));
      if (response.data is Map && response.data['subthreads'] != null) {
        return List<Map<String, dynamic>>.from(response.data['subthreads']);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPostsByUserId(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _client.communityDio
          .get(
            '/posts/user/$userId',
            queryParameters: {'limit': limit, 'offset': offset},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout. Please check your connection.');
            },
          );

      if (response.data is Map && response.data['posts'] != null) {
        return List<Map<String, dynamic>>.from(response.data['posts']);
      }
      return [];
    } on DioException {
      return [];
    } catch (_) {
      return [];
    }
  }
}
