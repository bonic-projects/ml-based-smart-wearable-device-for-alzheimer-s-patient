import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:perfect_volume_control/perfect_volume_control.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_firebase_auth/stacked_firebase_auth.dart';
import 'package:stacked_services/stacked_services.dart';

import '../../../app/app.locator.dart';
import '../../../app/app.logger.dart';
import '../../../services/camera_service.dart';
import '../../../services/imageprocessing_service.dart';
import '../../../services/location_service.dart';
import '../../../services/regula_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/tts_service.dart';

class InAppViewModel extends BaseViewModel {
  final log = getLogger('InAppViewModel');

  final _snackBarService = locator<SnackbarService>();

  final TTSService _ttsService = locator<TTSService>();
  final ImageProcessingService _imageProcessingService =
      locator<ImageProcessingService>();
  final _ragulaService = locator<RegulaService>();
  final _storageService = locator<StorageService>();
  final _authService = locator<FirebaseAuthenticationService>();
  final _camService = locator<CameraService>();
  final _locService = locator<LocationService>();

  CameraController get controller => _camService.controller;
  late StreamSubscription<double> _subscription;

  void onModelReady() async {
    _subscription = PerfectVolumeControl.stream.listen((value) {
      if (_image == null && !isBusy) {
        captureImageAndLabel();
      }
      if (_image != null && !isBusy) {
        log.i("Volume button got!");
        getLabel();
      }
    });
    setBusy(true);
    await _camService.initCam();
    setBusy(false);
    // setTimer();//todo
    _locService.initialise((message) => "",);
  }

  Future captureImageAndLabel() async {
    _image = await _camService.takePicture();
    getLabel();
  }

  late Timer _timer;

  void setTimer() {
    _timer = Timer.periodic(const Duration(seconds: 6), (Timer timer) async {
      log.i("Timer got!");
      if (_image == null && !isBusy) {
        captureImageAndLabel();
      }
      if (_image != null && !isBusy) {
        getLabel();
      }
    });
  }

  @override
  void dispose() {
    // call your function here
    _locService.dispose();
    _camService.dispose();
    _subscription.cancel();
    _timer.cancel();
    super.dispose();
  }

  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  File? _image;

  File? get imageSelected => _image;

  // InputImage? _inputImage;

  getImageCamera() async {
    setBusy(true);
    // picking image
    _imageFile = await _picker.pickImage(source: ImageSource.camera);

    if (_imageFile != null) {
      log.i("CCC");
      // _dlibService.addImageFace(await _imageFile!.readAsBytes());
      _image = File(_imageFile!.path);
    } else {
      _snackBarService.showSnackbar(message: "No images selected");
    }
    setBusy(false);
  }

  getImageGallery() async {
    setBusy(true);
    // picking image
    _imageFile = await _picker.pickImage(source: ImageSource.gallery);

    if (_imageFile != null) {
      _image = File(_imageFile!.path);
    } else {
      _snackBarService.showSnackbar(message: "No images selected");
    }
    setBusy(false);
  }

  List<String> _labels = <String>[];

  List<String> get labels => _labels;

  void getLabel() async {
    setBusy(true);

    _storageService.uploadFile(
        _image!, "log/users/${_authService.currentUser!.uid}/log.png");

    log.i("Getting label");

    _labels = <String>[];

    _labels = await _imageProcessingService.getTextFromImage(_image!);

    setBusy(false);

    String text = _imageProcessingService.processLabels(_labels);
    if (text == "Person detected" && _image != null) {
      await _ttsService.speak(text);
      await Future.delayed(const Duration(milliseconds: 2000));
      return processFace();
    }

    _image = null;
    await Future.delayed(const Duration(seconds: 1));
    setBusy(false);
  }

  Future processFace() async {
    _ttsService.speak("Identifying person");
    setBusy(true);
    String? person = await _ragulaService.checkMatch(_image!.path);
    setBusy(false);
    if (person != null) {
      _labels.clear();
      _labels.add(person);
      notifyListeners();
      await _ttsService.speak(person);
      await Future.delayed(const Duration(milliseconds: 1500));
    } else {
      await _ttsService.speak("Not identified!");
      await Future.delayed(const Duration(milliseconds: 1500));
    }
    log.i("Person: $person");
  }

  Future speak(String text) async {
    _ttsService.speak(text);
  }
}
