import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:alzheimers_companion/app/app.bottomsheets.dart';
import 'package:alzheimers_companion/app/app.dialogs.dart';
import 'package:alzheimers_companion/app/app.locator.dart';
import 'package:alzheimers_companion/app/app.router.dart';
import 'package:alzheimers_companion/ui/common/app_colors.dart';
import 'package:stacked_services/stacked_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  await setupLocator();
  setupDialogUi();
  setupBottomSheetUi();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: Routes.startupView,
      onGenerateRoute: StackedRouter().onGenerateRoute,
      navigatorKey: StackedService.navigatorKey,
      navigatorObservers: [
        StackedService.routeObserver,
      ],
      theme: ThemeData(
        primaryColor: kcPrimaryColor,
        fontFamily: "Poppins",
      ),
    );
  }
}
