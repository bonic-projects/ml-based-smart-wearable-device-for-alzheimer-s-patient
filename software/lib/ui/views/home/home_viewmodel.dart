import 'dart:async';

import 'package:alzheimers_companion/services/call_service.dart';
import 'package:alzheimers_companion/services/contacts_service.dart';
import 'package:alzheimers_companion/services/speech_service.dart';
import 'package:alzheimers_companion/ui/views/widgets/voice_bottomsheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:alzheimers_companion/models/reminder.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

import '../../../app/app.bottomsheets.dart';
import '../../../app/app.locator.dart';
import '../../../app/app.logger.dart';
import '../../../app/app.router.dart';
import '../../../models/appuser.dart';
import '../../../services/firestore_service.dart';
import '../../../services/location_service.dart';
import '../../../services/tts_service.dart';
import '../../../services/user_service.dart';
import '../../common/app_strings.dart';

class HomeViewModel extends StreamViewModel<List<Reminder>> {
  final log = getLogger('HomeViewModel');
  final _dialogService = locator<DialogService>();
  final _snackBarService = locator<SnackbarService>();
  final _navigationService = locator<NavigationService>();
  final _userService = locator<UserService>();
  final _firestoreService = locator<FirestoreService>();
  final _bottomSheetService = locator<BottomSheetService>();
  final TTSService _ttsService = locator<TTSService>();
  final CallService _callService = locator<CallService>();
  final ContactsService _contactsService = locator<ContactsService>();
  final SpeechService _speechService = locator<SpeechService>();
  String? errorMessage;
  String? recognizedSpeech;
  String _statusMessage = "Tap mic to speak"; // Renamed from 'message'
  String get statusMessage => _statusMessage;

  @override
  Stream<List<Reminder>> get stream => _firestoreService.getRemindersStream();

  AppUser? get user => _userService.user;

  late Timer _reminderTimer;

  void onModelRdy() async {
    log.i("started");
    setBusy(true);
    if (user == null) {
      await _userService.fetchUser();
    }
    locator<LocationService>().initialise((String message) async {
      log.i('Alert triggered with message: $message');
      await Future.delayed(Duration(seconds: 10)); // Prevent overlaps
      _snackBarService.showSnackbar(message: message);
    });

    if (user!.userRole == "bystander") {
      await getPatients();
    } else {
      startReminderCheck();
    }
    setBusy(false);
  }

  List<AppUser> _patients = <AppUser>[];

  List<AppUser> get patients => _patients;

  // Future
  Future getPatients() async {
    _patients = await _firestoreService.getUsersWithBystander();
    log.i("Users count: ${_patients.length}");
  }

  void openInAppView() {
    _navigationService.navigateTo(Routes.inAppView);
  }

  void openHardwareView() {
    _navigationService.navigateTo(Routes.hardwareView);
  }

  void openFaceTrainView() {
    _navigationService.navigateTo(Routes.faceRecView);
  }

  void openFaceTestView() {
    // _navigationService.navigateTo(Routes.faceTest);
  }

  void setPickedLocation(LatLng latLng) {
    _firestoreService.updateHomeLocation(latLng.latitude, latLng.longitude);
    _userService.fetchUser();
    _snackBarService.showSnackbar(message: "Home location set");
  }

  void onDelete(Reminder reminder) async {
    log.i("DELETE");
    log.i(reminder.id);
    await _firestoreService.deleteReminder(user!.id, reminder.id);
    _snackBarService.showSnackbar(message: "Reminder delete");
  }

  Future<void> logout() async {
    DialogResponse? response = await _dialogService.showConfirmationDialog(
      title: 'Logout',
      description: 'Are you sure you want to logout?',
      confirmationTitle: 'Yes',
      cancelTitle: 'No',
    );

    if (response != null && response.confirmed) {
      setBusy(true);
      await _userService.logout();
      _navigationService.replaceWithLoginRegisterView();
      setBusy(false);
    }
  }

  // void logout() {
  //   _navigationService.replaceWithLoginRegisterView();
  //   _userService.logout();
  // }

  void showBottomSheetUserSearch() async {
    final result = await _bottomSheetService.showCustomSheet(
      variant: BottomSheetType.notice,
      title: ksHomeBottomSheetTitle,
      description: ksHomeBottomSheetDescription,
    );
    if (result != null) {
      if (result.confirmed) {
        log.i("Bystander added: ${result.data.fullName}");
        _snackBarService.showSnackbar(
            message: "${result.data.fullName} added as bystander");
      }
      // _bottomSheetService.
    }
  }

  void openMapView(AppUser user) {
    _navigationService.navigateToMapView(user: user);
  }

  // Method to start checking for reminders
  void startReminderCheck() {
    // Schedule a timer to check reminders every minute
    _reminderTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      checkReminders();
    });
  }

  void stopReminderCheck() {
    _reminderTimer.cancel();
  }

  void checkReminders() {
    // log.i("Reminder");
    if (data != null) {
      // Get the current time
      final DateTime currentTime = DateTime.now();

      // Iterate through reminders and check if any have reached the current time
      for (Reminder reminder in data!) {
        // if (currentTime.isAfter(reminder.dateTime)) {
        if (currentTime.hour == reminder.dateTime.hour &&
            currentTime.minute == reminder.dateTime.minute) {
          // Call a function or trigger an action when the reminder time is reached
          handleReminderReachedTime(reminder);
        }
      }
    }
  }

  // Method to handle the action when a reminder reaches the current time
  void handleReminderReachedTime(Reminder reminder) async {
    log.i('Reminder reached time: ${reminder.message}');
    await _ttsService.speak("Reminder: ${reminder.message}");
    // onDelete(reminder);
  }

  @override
  void dispose() {
    if (user?.userRole == "patient") {
      stopReminderCheck();
    }
    super.dispose();
  }

  void clearErrorMessage() {
    errorMessage = null;
    notifyListeners();
  }

  Future<bool> checkMicrophonePermission() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      print("Microphone permission granted.");
      return true;
    } else if (status.isPermanentlyDenied) {
      print("Microphone permission permanently denied.");
      openAppSettings(); // Redirect to settings
    } else {
      print("Microphone permission denied.");
    }
    return false;
  }

  /// Check and request contacts permission
  Future<bool> checkContactsPermission() async {
    var status = await Permission.contacts.status;

    if (status.isDenied) {
      status = await Permission.contacts.request();
    }

    if (status.isGranted) {
      print("Contacts permission granted.");
      return true;
    } else if (status.isPermanentlyDenied) {
      print("Contacts permission permanently denied.");
      openAppSettings(); // Redirect to settings
    } else {
      print("Contacts permission denied.");
    }
    return false;
  }

  /// Fetch contacts securely
  Future<void> fetchContacts() async {
    try {
      bool contactsGranted = await checkContactsPermission();
      if (contactsGranted) {
        var contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: false,
        );
        print(
            "Contacts fetched: ${contacts.map((c) => c.displayName).toList()}");
      } else {
        print("Contacts permission not granted. Cannot fetch contacts.");
      }
    } catch (e) {
      print("Error fetching contacts: $e");
    }
  }

  Future<void> onMicTap(BuildContext context) async {
    // Show bottom sheet first
    bool isBottomSheetOpen = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      isScrollControlled: true,
      builder: (context) => VoiceRecognitionBottomSheet(
        onClose: () {
          _speechService.stopListening();
          isBottomSheetOpen = false; // Update flag when bottom sheet is closed
          Navigator.pop(context);
        },
        statusMessage: _statusMessage,
        isBusy: isBusy,
      ),
    ).then((_) {
      isBottomSheetOpen = false; // Ensure flag is updated when bottom sheet is dismissed
    });

    setBusy(true);

    // Check microphone permission
    bool micGranted = await checkMicrophonePermission();
    if (!micGranted) {
      if (isBottomSheetOpen) Navigator.pop(context); // Close bottom sheet if open
      return;
    }

    _statusMessage = "Listening...";
    notifyListeners();

    // Initialize speech recognition
    bool isInitialized = await _speechService.initialize();
    if (!isInitialized) {
      _statusMessage = "Speech recognition not available.";
      setBusy(false);
      notifyListeners();
      if (isBottomSheetOpen) Navigator.pop(context); // Close bottom sheet if open
      return;
    }

    // Start listening
    await _speechService.startListening((String speechResult) async {
      if (speechResult.isNotEmpty) {
        print("Recognized speech: $speechResult");

        if (speechResult.toLowerCase().startsWith("call")) {
          String name = speechResult.replaceFirst("call", "").trim();
         // Close bottom sheet

          _statusMessage = "Searching for $name in contacts...";
          notifyListeners();

          String? number = await _contactsService.findContactNumber(name);
          if (number != null) {
            _statusMessage = "Calling $name...";
            if (isBottomSheetOpen) Navigator.pop(context);
            notifyListeners();

            // Initiate call
            await _callService.makeCall(number);
          } else {
            _statusMessage = "Contact not found.";
            notifyListeners();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("No contact found for $name."),
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else {
          _statusMessage = "Command not recognized.";
          notifyListeners();
        }
      }
    });

    setBusy(false);
  }

// Future<void> onMicTap(BuildContext context) async {
//     setBusy(true);
//     bool micGranted = await checkMicrophonePermission();
//     if (!micGranted) return;
//     _statusMessage = "Listening...";
//     notifyListeners();
//
//     // Initialize speech recognition
//     bool isInitialized = await _speechService.initialize();
//     if (!isInitialized) {
//       _statusMessage = "Speech recognition not available.";
//       setBusy(false);
//       notifyListeners();
//       return;
//     }
//
//     // Start listening
//     await _speechService.startListening((String speechResult) async {
//       if (speechResult.isNotEmpty) {
//         print("Recognized speech: $speechResult");
//
//         if (speechResult.toLowerCase().startsWith("call")) {
//           String name = speechResult.replaceFirst("call", "").trim();
//           _statusMessage = "Searching for $name in contacts...";
//           notifyListeners();
//
//           // Handle calling logic
//           String? number = await _contactsService.findContactNumber(name);
//           if (number != null) {
//             _statusMessage = "Calling $name...";
//             notifyListeners();
//             await _callService.makeCall(number);
//           } else {
//             _statusMessage = "Contact not found.";
//             notifyListeners();
//           }
//         } else {
//           _statusMessage = "Command not recognized.";
//           notifyListeners();
//         }
//       }
//     });
//
//     setBusy(false);
//   }

}