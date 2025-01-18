import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:stacked/stacked.dart';

import '../../../models/appuser.dart';
import '../../../models/reminder.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:stacked/stacked.dart';
import 'package:geolocator/geolocator.dart';

import '../../../models/appuser.dart';
import '../../../models/reminder.dart';
import 'map_viewmodel.dart';

class MapView extends StackedView<MapViewModel> {
  final AppUser user;

  const MapView({Key? key, required this.user}) : super(key: key);

  @override
  Widget builder(
      BuildContext context,
      MapViewModel viewModel,
      Widget? child,
      ) {
    if (viewModel.user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    _checkDistance(context, viewModel.user!);

    return Scaffold(
      appBar: AppBar(
        title: Text('${user.fullName}\'s location'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        label: const Text("Reminder"),
        icon: const Icon(Icons.add),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => ReminderInputBottomSheet(
              onReminderSubmitted: (reminder) {
                viewModel.setReminder(reminder: reminder);
              },
            ),
          );
        },
      ),
      body: Center(
        child: viewModel.isBusy
            ? const CircularProgressIndicator()
            : GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
                viewModel.user!.latitude, viewModel.user!.longitude),
            zoom: 15.0,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          markers: <Marker>{
            Marker(
              markerId: const MarkerId('currentLocation'),
              position: LatLng(
                  viewModel.user!.latitude, viewModel.user!.longitude),
              infoWindow: InfoWindow(
                title: 'Current Location: ${viewModel.user!.place}',
              ),
            ),
          },
        ),
      ),
    );
  }

  @override
  MapViewModel viewModelBuilder(
      BuildContext context,
      ) =>
      MapViewModel();

  @override
  void onViewModelReady(MapViewModel viewModel) {
    viewModel.onModelReady(user);
    super.onViewModelReady(viewModel);
  }

  Future<void> _checkDistance(BuildContext context, AppUser user) async {
    final homeLatitude = user.homeLat;
    final homeLongitude = user.homeLong;

    final currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final distanceInMeters = await Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      homeLatitude,
      homeLongitude,
    );

    if (distanceInMeters > 1000) {
      _showAlert(context);
    }
  }

  void _showAlert(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Patient is far away from the set home location!'),
         duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
        // action: SnackBarAction(
        //   label: 'OK',
        //   textColor: Colors.white,
        //   onPressed: () {
        //     // Optionally handle OK button action
        //   },
        // ),
      ),
    );
  }
}

class ReminderInputBottomSheet extends StatefulWidget {
  final Function(Reminder) onReminderSubmitted;

  const ReminderInputBottomSheet(
      {super.key, required this.onReminderSubmitted});

  @override
  _ReminderInputBottomSheetState createState() =>
      _ReminderInputBottomSheetState();
}

class _ReminderInputBottomSheetState extends State<ReminderInputBottomSheet> {
  final TextEditingController _messageController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Add Reminder',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(labelText: 'Reminder Message'),
            ),
            const SizedBox(height: 40.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Time'),
                TextButton(
                  onPressed: () => _selectDateTime(context),
                  child: const Text('Pick'),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Selected Time: ${_selectedDateTime.hour}: ${_selectedDateTime.minute}',
                  style: const TextStyle(fontSize: 12.0),
                ),
              ),
            ),
            const SizedBox(height: 80.0),
            ElevatedButton(
              onPressed: () => _submitForm(),
              child: const Text('Add Reminder'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateTime(BuildContext context) async {
    // final DateTime? picked = await showDatePicker(
    //   context: context,
    //   initialDate: _selectedDateTime,
    //   firstDate: DateTime.now(),
    //   lastDate: DateTime.now().add(const Duration(days: 365)),
    // );

    // if (picked != null) {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );

    if (time != null) {
      setState(() {
        _selectedDateTime = DateTime(
          2024,
          1,
          1,
          // picked.year,
          // picked.month,
          // picked.day,
          time.hour,
          time.minute,
        );
      });
    }
    // }
  }

  void _submitForm() {
    final String message = _messageController.text.trim();

    if (message.isNotEmpty) {
      final Reminder newReminder = Reminder(
        id: DateTime.now().toString(),
        message: message,
        dateTime: _selectedDateTime,
      );

      widget.onReminderSubmitted(newReminder);
      Navigator.of(context).pop(); // Close the bottom sheet
    } else {
      // Handle validation error, if necessary
      // For example, show a snackbar or an error message
    }
  }
}
