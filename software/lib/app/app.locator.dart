// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// StackedLocatorGenerator
// **************************************************************************

// ignore_for_file: public_member_api_docs, implementation_imports, depend_on_referenced_packages

import 'package:stacked_firebase_auth/src/firebase_authentication_service.dart';
import 'package:stacked_services/src/bottom_sheet/bottom_sheet_service.dart';
import 'package:stacked_services/src/dialog/dialog_service.dart';
import 'package:stacked_services/src/navigation/navigation_service.dart';
import 'package:stacked_services/src/snackbar/snackbar_service.dart';
import 'package:stacked_shared/stacked_shared.dart';

import '../services/call_service.dart';
import '../services/camera_service.dart';
import '../services/contacts_service.dart';
import '../services/firestore_service.dart';
import '../services/imageprocessing_service.dart';
import '../services/location_service.dart';
import '../services/regula_service.dart';
import '../services/speech_service.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';
import '../services/user_service.dart';

final locator = StackedLocator.instance;

Future<void> setupLocator({
  String? environment,
  EnvironmentFilter? environmentFilter,
}) async {
// Register environments
  locator.registerEnvironment(
      environment: environment, environmentFilter: environmentFilter);

// Register dependencies
  locator.registerLazySingleton(() => SnackbarService());
  locator.registerLazySingleton(() => BottomSheetService());
  locator.registerLazySingleton(() => DialogService());
  locator.registerLazySingleton(() => NavigationService());
  locator.registerLazySingleton(() => FirebaseAuthenticationService());
  locator.registerLazySingleton(() => FirestoreService());
  locator.registerLazySingleton(() => UserService());
  locator.registerLazySingleton(() => StorageService());
  locator.registerLazySingleton(() => TTSService());
  locator.registerLazySingleton(() => ImageProcessingService());
  locator.registerLazySingleton(() => RegulaService());
  locator.registerLazySingleton(() => LocationService());
  locator.registerLazySingleton(() => CameraService());
  locator.registerLazySingleton(() => CallService());
  locator.registerLazySingleton(() => ContactsService());
  locator.registerLazySingleton(() => SpeechService());
}
