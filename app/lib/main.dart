import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'config.dart';
import 'screens/bootstrap_screen.dart';
import 'services/app_services.dart';
import 'services/device_session.dart';
import 'theme.dart';

/// CI 스크린샷용: 웹에서 버튼·입력창을 접근성 트리로 찾을 수 있게 켠다.
const _e2e = bool.fromEnvironment('E2E');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (_e2e) WidgetsBinding.instance.ensureSemantics();
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
