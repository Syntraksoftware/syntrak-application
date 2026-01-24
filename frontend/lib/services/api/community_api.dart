import 'package:dio/dio.dart';
import 'api_client.dart';

class CommunityApi {
  final ApiClient _client;

  CommunityApi(this._client);

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
