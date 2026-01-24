import 'package:syntrak/models/user.dart';
import 'api_client.dart';

class UserApi {
  final ApiClient _client;

  UserApi(this._client);

  Future<User> getCurrentUser() async {
    final response = await _client.mainDio.get('/users/me');
    return User.fromJson(response.data);
  }

  Future<User> updateUserProfile({
    String? firstName,
    String? lastName,
  }) async {
    /// update this function in future for more fields about the user profile 
    final data = <String, dynamic>{};
    if (firstName != null) data['first_name'] = firstName;
    if (lastName != null) data['last_name'] = lastName;
    final response = await _client.mainDio.put('/users/me', data: data);
    return User.fromJson(response.data);
  }
}





