import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(VyroApp(services: AppServices()));
}
