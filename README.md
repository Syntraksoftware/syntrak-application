# Syntrak

A fitness tracking app similar to Strava, built with SwiftUI for iOS.

## Features

- **Activity Tracking**: Record runs, rides, walks, and hikes with GPS tracking
- **Real-time Stats**: View distance, duration, and pace while recording
- **Activity History**: Browse and view detailed information about past activities
- **Map Integration**: See your route on an interactive map
- **Profile Stats**: Track your total activities, distance, and time

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.0+

## Setup

1. Open `Syntrak.xcodeproj` in Xcode
2. Select your development team in the project settings
3. Build and run on a physical device (GPS tracking requires a real device)
4. Grant location permissions when prompted

## Project Structure

```
Syntrak/
├── Models/
│   ├── Activity.swift          # Activity data model
│   └── LocationPoint.swift     # GPS location point model
├── Services/
│   ├── LocationTracker.swift   # GPS tracking service
│   └── ActivityStore.swift     # Activity persistence
├── Views/
│   ├── HomeView.swift          # Main tab view
│   ├── ActivityListView.swift  # List of all activities
│   ├── ActivityDetailView.swift # Detailed activity view with map
│   ├── RecordActivityView.swift # Activity recording screen
│   └── ProfileView.swift       # User profile and stats
└── SyntrakApp.swift            # App entry point
```

## Usage

1. **Record an Activity**: 
   - Tap the "Record" tab
   - Select activity type (Run, Ride, Walk, Hike)
   - Tap "Start" to begin tracking
   - Tap "Stop" to save the activity

2. **View Activities**:
   - Tap the "Activities" tab to see all recorded activities
   - Tap any activity to view details including map route

3. **View Profile**:
   - Tap the "Profile" tab to see your statistics
   - View total activities, distance, and time

## Permissions

The app requires location permissions to track your activities. Make sure to grant "When In Use" location access when prompted.

## Notes

- Activities are stored locally using UserDefaults
- GPS tracking works best outdoors with clear sky view
- The app requires a physical device for accurate GPS tracking (simulator has limited location capabilities)

