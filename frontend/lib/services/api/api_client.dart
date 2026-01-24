import 'package:dio/dio.dart';

/// Shared HTTP client for main and community backends.
/// Use 127.0.0.1 instead of localhost for iOS simulator compatibility.
/// # Shared HTTP client (Dio + token for main & community)

/// - two distinct API endpoints: 
///    - `mainBaseUrl` (for main app API) at http://127.0.0.1:8080/api/v1
///    - `communityBaseUrl` (for community features) at http://127.0.0.1:5001/api
/// - It builds two Dio clients with those base URLs and timeout settings, 
///   and keeps them available as `mainDio` and `communityDio`.
/// - It supports bearer token authentication for all requests by injecting the `Authorization: Bearer <token>` header when a token is set.
/// 
/// Usage:
///   - Call `setToken(token)` to set or update the authentication token.
///   - Use `mainDio` or `communityDio` to make authenticated requests to either backend.

class ApiClient {
  String? _token; // Stores the bearer token for requests

  late final Dio _mainDio;      // Dio client for main backend
  late final Dio _communityDio; // Dio client for community backend

  static const String mainBaseUrl = 'http://127.0.0.1:8080/api/v1';
  static const String communityBaseUrl = 'http://127.0.0.1:5001/api';

  ApiClient() {
    // Initialize both HTTP clients on construction
    _mainDio = _createDio(mainBaseUrl);
    _communityDio = _createDio(communityBaseUrl);
  }

  /// Internal method to create a Dio client with common options and an interceptor
  /// to add the Authorization header if a token is set.
  Dio _createDio(String baseUrl) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // Add interceptor to inject authorization token into headers if present
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      // Pass through errors; no extra logic needed
      onError: (error, handler) => handler.next(error),
    ));
    return dio;
  }

  // Expose the configured clients for external use
  Dio get mainDio => _mainDio;
  Dio get communityDio => _communityDio;

  /// Update/set the bearer token for future requests
  /// Bearer Token == authentication token == JWT
  void setToken(String? token) {
    _token = token;
  }
}
