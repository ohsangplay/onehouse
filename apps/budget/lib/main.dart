import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:onehouse_core/onehouse_core.dart';

import 'config.dart';
import 'screens/ledger_list_screen.dart';
import 'theme.dart';
import 'widgets/ad_banner.dart';

/// CI 스크린샷용: 웹에서 버튼·입력창을 접근성 트리로 찾을 수 있게 켠다.
const _e2e = bool.fromEnvironment('E2E');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (_e2e) WidgetsBinding.instance.ensureSemantics();
  // 광고 SDK는 기다리지 않고 뒤에서 초기화 (첫 화면을 늦추지 않게)
  Ads.init();
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
      // 날짜 고르기 등 기본 위젯을 한국어로
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: BootstrapScreen(
        services: services,
        home: (_) => LedgerListScreen(services: services),
      ),
    );
  }
}
