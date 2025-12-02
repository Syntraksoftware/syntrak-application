import 'package:flutter/foundation.dart';
import 'package:syntrak/models/user.dart';
import 'package:syntrak/services/api_service.dart';
import 'package:syntrak/services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService? _storageService;
  User? _user;
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _error;

  AuthProvider(this._apiService, [this._storageService]);

  // Public method to check auth (called after storage is initialized)
  Future<void> checkAuth() => _checkAuth();

  User? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> _checkAuth() async {
    print('🔍 [AuthProvider] Starting _checkAuth');
    try {
      _isLoading = true;
      notifyListeners();
      print('🔍 [AuthProvider] isLoading set to true');

      // Ensure storage is initialized
      if (_storageService != null) {
        print('🔍 [AuthProvider] Initializing storage...');
        await _storageService!.init();
        print('🔍 [AuthProvider] Storage initialized. Token: ${_storageService!.token}');
      } else {
        print('🔍 [AuthProvider] No storage service available');
      }

      // Check if token exists in storage
      if (_storageService != null && _storageService!.token != null) {
        print('🔍 [AuthProvider] Token found, validating with backend...');
        _apiService.setToken(_storageService!.token);
        try {
          // Add timeout to prevent hanging if backend is not running
          _user = await _apiService.getCurrentUser()
              .timeout(const Duration(seconds: 3));
          _isAuthenticated = true;
          print('🔍 [AuthProvider] User authenticated: ${_user?.email}');
        } catch (e) {
          print('🔍 [AuthProvider] Auth validation failed: $e');
          // Token invalid or backend not available, clear it and show login
          if (_storageService != null) {
            await _storageService!.clearToken();
          }
          _isAuthenticated = false;
        }
      } else {
        print('🔍 [AuthProvider] No token found, showing login');
        _isAuthenticated = false;
      }
    } catch (e) {
      print('🔍 [AuthProvider] Error in _checkAuth: $e');
      // Any error - just show login screen
      _isAuthenticated = false;
    } finally {
      // ALWAYS set loading to false, no matter what happens
      print('🔍 [AuthProvider] Setting isLoading to false');
      _isLoading = false;
      notifyListeners();
      print('🔍 [AuthProvider] Auth check complete. isAuthenticated: $_isAuthenticated');
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _apiService.login(email: email, password: password);
      final token = response['token'] as String;
      final userJson = response['user'] as Map<String, dynamic>;

      _apiService.setToken(token);
      _user = User.fromJson(userJson);
      _isAuthenticated = true;
      _error = null;

      // Save token to storage
      if (_storageService != null) {
        await _storageService!.saveToken(token, _user!.id);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, {String? firstName, String? lastName}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _apiService.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      final token = response['token'] as String;
      final userJson = response['user'] as Map<String, dynamic>;

      _apiService.setToken(token);
      _user = User.fromJson(userJson);
      _isAuthenticated = true;
      _error = null;

      // Save token to storage
      if (_storageService != null) {
        await _storageService!.saveToken(token, _user!.id);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Extract clean error message
      String errorMessage = 'Registration failed';
      if (e is Exception) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      } else {
        errorMessage = e.toString();
      }
      _error = errorMessage;
      _isLoading = false;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _apiService.setToken(null);
    _user = null;
    _isAuthenticated = false;

    // Clear token from storage
    if (_storageService != null) {
      await _storageService!.clearToken();
    }

    notifyListeners();
  }
}

