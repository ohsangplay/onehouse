import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

import 'ads/banner_ad.dart';
import 'config.dart';
import 'screens/notebook_list_screen.dart';
import 'services/memo_services.dart';
import 'services/memo_store.dart';
import 'theme.dart';

/// CI 스크린샷용: 웹에서 버튼·입력창을 접근성 트리로 찾을 수 있게 켠다.
const _e2e = bool.fromEnvironment('E2E');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_e2e) WidgetsBinding.instance.ensureSemantics();
  final api = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  final app = AppServices(api: api, session: DeviceSession(api), space: memoSpace);
  final services = MemoServices(app: app, store: await MemoStore.open());
  runApp(MemoApp(services: services));
}

class MemoApp extends StatefulWidget {
  const MemoApp({super.key, required this.services});

  final MemoServices services;

  @override
  State<MemoApp> createState() => _MemoAppState();
}

class _MemoAppState extends State<MemoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 첫 화면이 뜬 뒤 광고 준비 (iOS는 여기서 추적 허용을 묻는다)
    WidgetsBinding.instance.addPostFrameCallback((_) => initAds());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱으로 돌아오면 연결을 바로 확인하고, 오프라인 체크가 남아 있으면 보낸다
    if (state == AppLifecycleState.resumed) {
      widget.services.network.check().then((online) {
        if (online) widget.services.flushChecks();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return MaterialApp(
      title: '한지붕 메모',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(MemoColors.primary),
      home: BootstrapScreen(
        services: services.app,
        home: (_) {
          services.flushChecks();
          return NotebookListScreen(services: services);
        },
      ),
    );
  }
}
