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

  /// Recursively normalizes JSON map so all keys are String and nested maps are Map<String, dynamic>.
  static Map<String, dynamic> _deepNormalizeMap(dynamic value) {
    if (value == null) return {};
    if (value is! Map) return {};
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      final k = entry.key;
      final v = entry.value;
      final key = k is String ? k : k.toString();
      if (v is Map) {
        result[key] = _deepNormalizeMap(v);
      } else if (v is List) {
        result[key] = v
            .map((e) => e is Map ? _deepNormalizeMap(e) : e)
            .toList();
      } else {
        result[key] = v;
      }
    }
    return result;
  }

  /// GET /subthreads/{id}/posts — list posts in a subthread.
  /// Returns deeply normalized maps so reply_count, like_count, repost_count, reposted_post display correctly.
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
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timeout. The server may be slow; try again.');
            },
          );
      
      // Debug: Log response structure
      print('📡 API Response status: ${response.statusCode}');
      print('📡 Response data type: ${response.data.runtimeType}');
      
      if (response.data is Map) {
        final data = response.data as Map;
        print('📡 Response keys: ${data.keys.toList()}');
        
        if (data['posts'] != null) {
          final rawPosts = data['posts'] as List;
          print('📡 Found ${rawPosts.length} posts in response');
          return rawPosts
              .map<Map<String, dynamic>>((p) => _deepNormalizeMap(p))
              .toList();
        } else {
          print('⚠️ Response missing "posts" key');
          throw Exception('Invalid response format: missing "posts" key');
        }
      } else {
        print('⚠️ Response is not a Map: ${response.data.runtimeType}');
        throw Exception('Invalid response format: expected Map, got ${response.data.runtimeType}');
      }
    } on DioException catch (e) {
      print('❌ DioException: ${e.message}');
      print('❌ Status code: ${e.response?.statusCode}');
      print('❌ Response data: ${e.response?.data}');
      if (e.response?.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      }
      if (e.response?.statusCode == 404) {
        throw Exception('Subthread not found');
      }
      throw Exception('Failed to load posts: ${e.message ?? "Unknown error"}');
    } catch (e) {
      print('❌ Error loading posts: $e');
      rethrow;
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

  /// POST /posts/{post_id}/like — like or unlike a post. Requires auth.
  Future<Map<String, dynamic>> toggleLike(String postId) async {
    try {
      final response = await _client.communityDio
          .post('/posts/$postId/like')
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
        throw Exception('Post not found');
      }
      throw Exception('Failed to toggle like: ${e.message ?? "Unknown error"}');
    }
  }

  /// POST /posts/{post_id}/repost — create a repost. Requires auth.
  Future<Map<String, dynamic>> createRepost({
    required String postId,
    required String subthreadId,
    String? content,
  }) async {
    try {
      final response = await _client.communityDio
          .post(
            '/posts/$postId/repost',
            data: {
              'subthread_id': subthreadId,
              if (content != null && content.isNotEmpty) 'content': content,
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
        throw Exception('Post not found');
      }
      throw Exception('Failed to create repost: ${e.message ?? "Unknown error"}');
    }
  }

  /// DELETE /posts/{post_id} — delete a post (authenticated, owner only).
  Future<void> deletePost(String postId) async {
    try {
      await _client.communityDio
          .delete('/posts/$postId')
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout. Please check your connection.');
            },
          );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      }
      if (e.response?.statusCode == 404) {
        throw Exception('Post not found or you are not allowed to delete it.');
      }
      throw Exception('Failed to delete post: ${e.message ?? "Unknown error"}');
    }
  }
}
