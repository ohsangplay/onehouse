import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'config.dart';
import 'screens/bootstrap_screen.dart';
import 'services/app_services.dart';
import 'services/device_session.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  final services = AppServices(api: api, session: DeviceSession(api));
  runApp(OnehouseApp(services: services));
}

class OnehouseApp extends StatelessWidget {
  const OnehouseApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '한지붕',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: BootstrapScreen(services: services),
    );
  }
}
