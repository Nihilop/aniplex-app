import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/api/api_client.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force landscape on TV
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Full screen immersive on boot
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Init API client (loads saved base URL from SharedPreferences)
  await ApiClient.init();

  runApp(const AniplexApp());
}
