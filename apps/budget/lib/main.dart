import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

import 'config.dart';
import 'screens/ledger_list_screen.dart';
import 'theme.dart';

/// CI 스크린샷용: 웹에서 버튼·입력창을 접근성 트리로 찾을 수 있게 켠다.
const _e2e = bool.fromEnvironment('E2E');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (_e2e) WidgetsBinding.instance.ensureSemantics();
  final api = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  final services = AppServices(api: api, session: DeviceSession(api), space: budgetSpace);
  runApp(BudgetApp(services: services));
}

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '한지붕 가계부',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(BudgetColors.primary),
      home: BootstrapScreen(
        services: services,
        home: (_) => LedgerListScreen(services: services),
      ),
    );
  }
}
