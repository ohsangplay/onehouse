import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

/// 빌드할 때 API 주소를 바꿀 수 있다.
/// 로컬 서버로 테스트: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8787
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // 운영 서버 (Cloudflare Workers, 한지붕 가계부·메모 공용)
    defaultValue: 'https://onehouse-api.shark-keeper.workers.dev',
  );
}

/// 한지붕 가계부의 공간 설정 (공통 화면 문구·API 주소)
const budgetSpace = SpaceConfig(
  appName: '한지붕 가계부',
  noun: '가계부',
  apiPath: '/ledgers',
  listKey: 'ledgers',
  tagline: '초대코드 하나로 가족과 함께 쓰는 가계부.',
  icon: Icons.house_outlined,
  nameHint: '예) 우리집 생활비',
  ownerNicknameHint: '예) 아빠',
  memberNicknameHint: '예) 엄마',
  authorshipNote: '내역마다 누가 썼는지 이 이름으로 표시돼요',
);
