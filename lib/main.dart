import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app.dart';
import 'app_settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Get.putAsync(() => AppSettingsService().init());
  runApp(ChatBoxApp());
}
