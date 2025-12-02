import 'package:flutter/foundation.dart';
import 'package:syntrak/models/activity.dart';
import 'package:syntrak/services/api_service.dart';

class ActivityProvider extends ChangeNotifier {
  final ApiService _apiService;
  List<Activity> _activities = [];
  bool _isLoading = false;
  String? _error;

  ActivityProvider(this._apiService);

  List<Activity> get activities => _activities;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadActivities() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _activities = await _apiService.getActivities();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Activity?> createActivity(Activity activity) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final created = await _apiService.createActivity(activity);
      _activities.insert(0, created);
      _isLoading = false;
      notifyListeners();
      return created;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> deleteActivity(String id) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _apiService.deleteActivity(id);
      _activities.removeWhere((a) => a.id == id);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Activity?> getActivity(String id) async {
    try {
      return await _apiService.getActivity(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}

