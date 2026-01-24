import 'package:syntrak/models/activity.dart';
import 'api_client.dart';

class ActivityApi {
  /// activities API endpoint: create, get, update, uploadavatar
  
  final ApiClient _client;

  ActivityApi(this._client);
  /// create a new activity 
  
  Future<Activity> createActivity(Activity activity) async {
    final response =
        await _client.mainDio.post('/activities', data: activity.toJson());
    return Activity.fromJson(response.data);
  }

  Future<List<Activity>> getActivities({int page = 1, int limit = 20}) async {
    final response = await _client.mainDio.get('/activities',
        queryParameters: {'page': page, 'limit': limit});
    return (response.data as List)
        .map((json) => Activity.fromJson(json))
        .toList();
  }

  Future<Activity> getActivity(String id) async {
    final response = await _client.mainDio.get('/activities/$id');
    return Activity.fromJson(response.data);
  }

  Future<Activity> updateActivity(
    String id, {
    String? name,
    String? description,
    bool? isPublic,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (isPublic != null) data['is_public'] = isPublic;
    final response = await _client.mainDio.put('/activities/$id', data: data);
    return Activity.fromJson(response.data);
  }

  Future<void> deleteActivity(String id) async {
    await _client.mainDio.delete('/activities/$id');
  }
}
