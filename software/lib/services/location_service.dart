import 'dart:async';
import 'package:alzheimers_companion/models/appuser.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../app/app.locator.dart';
import '../app/app.logger.dart';
import 'firestore_service.dart';
import 'user_service.dart';
class LocationService {
  final log = getLogger('LocationService');
  final _firestoreService = locator<FirestoreService>();
  final _userService = locator<UserService>();

  late Position _currentPosition;
  late String _currentPlace;
  Timer? _locationUpdateTimer;
  Timer? _reminderTimer;
  bool _isMessageShown = false;

  // Callback to show alerts
  Function(String message)? onAlertCallback;

  Future<void> getLocation() async {
    try {
      log.i("Getting location...");
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        log.e("Location services are not enabled.");
        return;
      }

      if (!await checkAndRequestPermissions()) {
        log.e("Location permissions not granted.");
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(
          _currentPosition.latitude, _currentPosition.longitude);
      Placemark place = placemarks.isNotEmpty ? placemarks[0] : Placemark();
      _currentPlace =
      "${place.name ?? 'Unknown'}, ${place.locality ?? 'Unknown'}";

      log.i(
          "Lat: ${_currentPosition.latitude}, Long: ${_currentPosition.longitude} Place: $_currentPlace");

      await _firestoreService.updateLocation(
          _currentPosition.latitude, _currentPosition.longitude, _currentPlace);

      // Check if the patient is within the 10 km safe zone
      double distance = Geolocator.distanceBetween(
          _currentPosition.latitude,
          _currentPosition.longitude,
          _userService.user!.homeLat,
          _userService.user!.homeLong) /
          1000; // Convert to kilometers

      log.i("Distance from home: $distance kilometers");

      // Trigger state change logic
      onStateChange(distance <= 5); // Assuming 10 kilometers is the safe zone
    } catch (e) {
      log.e("Error occurred while getting location: $e");
    }
  }

  Future<bool> checkAndRequestPermissions() async {
    PermissionStatus status = await Permission.location.status;

    if (status.isDenied || status.isRestricted) {
      status = await Permission.location.request();
    }

    if (status.isPermanentlyDenied) {
      log.e("Location permission is permanently denied.");
      return false;
    }

    return status.isGranted;
  }

  // Function to handle state changes
  void onStateChange(bool isInSafeZone) {
    log.i('Safe Zone: $isInSafeZone');

    // Only trigger alerts for patients
    if (_userService.user?.userRole == "patient") {
      if (!isInSafeZone && !_isMessageShown) {
        log.i('Triggering alert callback for patient...');
        onAlertCallback?.call(
            "You are more than 5 kilometers away from your home. Please return to the safe zone!");
        _isMessageShown = true; // Prevent multiple alerts
        _reminderTimer = Timer(const Duration(minutes: 1), () {
          _isMessageShown = false; // Reset message state
        });
      } else if (isInSafeZone) {
        _reminderTimer?.cancel();
        _reminderTimer = null;
        _isMessageShown = false; // Reset message state when back in the safe zone
      }
    } else {
      log.i("Alert skipped: User role is not patient.");
    }
  }

  // Show the reminder message
  void _showMessage() {
    _isMessageShown = true;
    log.w("Message: Wear your glasses!");

    // Reset the flag after showing the message
    Timer(const Duration(seconds: 10), () {
      _isMessageShown = false;
    });
  }

  // Initialise the service
  Future<void> initialise(Function(String message) alertCallback) async {
    if (_locationUpdateTimer != null && _locationUpdateTimer!.isActive) {
      log.w(
          "Location update timer is already running. Skipping reinitialization.");
      return;
    }

    // Assign the alert callback
    onAlertCallback = alertCallback;

    log.i("Initializing LocationService...");
    await getLocation();

    _locationUpdateTimer =
        Timer.periodic(const Duration(minutes: 1), (Timer timer) async {
          await getLocation();
        });
  }

  // Dispose method to clean up resources
  void dispose() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;

    _reminderTimer?.cancel();
    _reminderTimer = null;
  }
}
// class LocationService {
//   final log = getLogger('LocationService');
//   final _firestoreService = locator<FirestoreService>();
//   final _userService = locator<UserService>();
//
//   late Position _currentPosition;
//   late String _currentPlace;
//   Timer? _locationUpdateTimer;
//   Timer? _reminderTimer;
//   bool _isMessageShown = false;
//
//   Future<void> getLocation() async {
//     try {
//       log.i("Getting location...");
//       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) {
//         log.e("Location services are not enabled.");
//         return;
//       }
//
//       if (!await checkAndRequestPermissions()) {
//         log.e("Location permissions not granted.");
//         return;
//       }
//
//       _currentPosition = await Geolocator.getCurrentPosition();
//       List<Placemark> placemarks = await placemarkFromCoordinates(
//           _currentPosition.latitude, _currentPosition.longitude);
//       Placemark place = placemarks.isNotEmpty ? placemarks[0] : Placemark();
//       _currentPlace =
//           "${place.name ?? 'Unknown'}, ${place.locality ?? 'Unknown'}";
//
//       log.i(
//           "Lat: ${_currentPosition.latitude}, Long: ${_currentPosition.longitude} Place: $_currentPlace");
//
//       await _firestoreService.updateLocation(
//           _currentPosition.latitude, _currentPosition.longitude, _currentPlace);
//
//       // Check if the patient is within a safe zone
//       double distance = Geolocator.distanceBetween(
//           _currentPosition.latitude,
//           _currentPosition.longitude,
//           _userService.user!.homeLat,
//           _userService.user!.homeLong);
//
//       log.e("Distance from home: $distance meters");
//
//       // Trigger state change logic
//       onStateChange(distance <= 30); // Assuming 30 meters is the safe zone
//     } catch (e) {
//       log.e("Error occurred while getting location: $e");
//     }
//   }
//
//   Future<bool> checkAndRequestPermissions() async {
//     PermissionStatus status = await Permission.location.status;
//
//     if (status.isDenied || status.isRestricted) {
//       status = await Permission.location.request();
//     }
//
//     if (status.isPermanentlyDenied) {
//       log.e("Location permission is permanently denied.");
//       return false;
//     }
//
//     return status.isGranted;
//   }
//
//   // Function to handle state changes
//   void onStateChange(bool isInSafeZone) {
//     if (!isInSafeZone && !_isMessageShown) {
//       // Start a timer to wait for 1 minute if the patient is out of the safe zone
//       _reminderTimer = Timer(const Duration(minutes: 1), () {
//         // If the patient is still out of the safe zone after 1 minute
//         if (!isInSafeZone) {
//           _showMessage();
//         }
//         _reminderTimer = null; // Clear the timer
//       });
//     } else if (isInSafeZone && _reminderTimer != null) {
//       // Cancel the timer if the patient returns to the safe zone
//       _reminderTimer?.cancel();
//       _reminderTimer = null;
//     }
//   }
//
//   // Show the reminder message
//   void _showMessage() {
//     _isMessageShown = true;
//     log.w("Message: Wear your glasses!");
//
//     // Reset the flag after showing the message
//     Timer(const Duration(seconds: 10), () {
//       _isMessageShown = false;
//     });
//   }
//
//   // Initialise the service
//   Future<void> initialise() async {
//     if (_locationUpdateTimer != null && _locationUpdateTimer!.isActive) {
//       log.w(
//           "Location update timer is already running. Skipping reinitialization.");
//       return;
//     }
//
//     log.i("Initializing LocationService...");
//     await getLocation();
//
//     _locationUpdateTimer =
//         Timer.periodic(const Duration(minutes: 1), (Timer timer) async {
//       await getLocation();
//     });
//   }
//
//   // Dispose method to clean up resources
//   void dispose() {
//     _locationUpdateTimer?.cancel();
//     _locationUpdateTimer = null;
//
//     _reminderTimer?.cancel();
//     _reminderTimer = null;
//   }
// }
