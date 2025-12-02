# Syntrak Flutter App

Flutter frontend for the Syntrak fitness tracking application.

## Features

- User authentication (login/register)
- GPS activity tracking
- Real-time activity recording with map visualization
- Activity history and details
- Profile with statistics

## Setup

1. Install Flutter dependencies:
```bash
flutter pub get
```

2. Configure API endpoint in `lib/services/api_service.dart`:
```dart
static const String baseUrl = 'http://your-backend-url:8080/api/v1';
```

3. For Android, add permissions in `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

4. For iOS, add location permissions in `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to track your activities</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need your location to track your activities</string>
```

5. Run the app:
```bash
flutter run
```

## Project Structure

- `lib/models/` - Data models (User, Activity, Location)
- `lib/services/` - API service, location service, storage service
- `lib/providers/` - State management (Auth, Activity)
- `lib/screens/` - UI screens (Auth, Home, Record, Activities, Profile)

## Dependencies

- **provider** - State management
- **dio** - HTTP client
- **geolocator** - GPS location tracking
- **google_maps_flutter** - Map visualization
- **permission_handler** - Location permissions

