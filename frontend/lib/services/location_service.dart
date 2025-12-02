import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:syntrak/models/location.dart' as app_location;

class LocationService {
  bool _isTracking = false;
  Position? _currentPosition;
  List<app_location.Location> _locations = [];

  bool get isTracking => _isTracking;
  Position? get currentPosition => _currentPosition;
  List<app_location.Location> get locations => List.unmodifiable(_locations);

  Future<bool> checkPermissions() async {
    final status = await Permission.location.status;
    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.location.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      // Open app settings
      await openAppSettings();
      return false;
    }

    return false;
  }

  Future<bool> requestPermissions() async {
    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      return false;
    }

    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are disabled
      return false;
    }

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        print('🔍 [LocationService] No permission for location');
        return null;
      }

      print('🔍 [LocationService] Getting current position...');
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10), // Add timeout
      );
      print('🔍 [LocationService] Position obtained: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
      return _currentPosition;
    } catch (e) {
      print('🔍 [LocationService] Error getting position: $e');
      return null;
    }
  }

  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5, // Update every 5 meters
      ),
    );
  }

  void startTracking() {
    _isTracking = true;
    _locations.clear();
  }

  void stopTracking() {
    _isTracking = false;
  }

  void addLocation(Position position) {
    if (!_isTracking) return;

    final location = app_location.Location(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      activityId: '', // Will be set when activity is created
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: position.altitude,
      accuracy: position.accuracy,
      speed: position.speed,
      timestamp: position.timestamp,
    );

    _locations.add(location);
  }

  void clearLocations() {
    _locations.clear();
  }

  double calculateDistance() {
    if (_locations.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 1; i < _locations.length; i++) {
      final prev = _locations[i - 1];
      final curr = _locations[i];
      totalDistance += Geolocator.distanceBetween(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );
    }

    return totalDistance;
  }

  double calculateElevationGain() {
    if (_locations.length < 2) return 0.0;

    double elevationGain = 0.0;
    for (int i = 1; i < _locations.length; i++) {
      final prev = _locations[i - 1];
      final curr = _locations[i];
      if (curr.altitude != null && prev.altitude != null) {
        final diff = curr.altitude! - prev.altitude!;
        if (diff > 0) {
          elevationGain += diff;
        }
      }
    }

    return elevationGain;
  }
}

