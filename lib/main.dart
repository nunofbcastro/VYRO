import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'core/platform/orientation_lock.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The app is portrait-only; the live camera screen opts into landscape.
  // Best effort: a refused orientation request must not stop the app starting.
  await OrientationLock.lockPortrait().catchError((Object _) {});
  runApp(VyroApp(services: AppServices()));
}
