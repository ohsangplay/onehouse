import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

/// 빌드할 때 API 주소를 바꿀 수 있다.
/// 로컬 서버로 테스트: flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8787
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // 운영 서버 (Cloudflare Workers, 한지붕 가계부·메모 공용)
    defaultValue: 'https://api.ohsangplay.com/onehouse/memo',
  );

  /// 고치는 걸 멈추고 이만큼 지나면 자동 저장
  static const autosaveDelay = Duration(milliseconds: 2500);

  /// 메모를 연 동안 "보고 있어요" 신호·새 내용 확인 주기
  static const presenceInterval = Duration(seconds: 15);
}

/// 한지붕 메모의 공간 설정 (공통 화면 문구·API 주소)
const memoSpace = SpaceConfig(
  appName: '한지붕 메모',
  noun: '메모집',
  apiPath: '/notebooks',
  listKey: 'notebooks',
  tagline: '초대코드 하나로 가족과 함께 쓰는 메모장.',
  icon: Icons.sticky_note_2_outlined,
  nameHint: '예) 우리집 메모',
  ownerNicknameHint: '예) 아빠',
  memberNicknameHint: '예) 엄마',
  authorshipNote: '메모마다 누가 쓰고 고쳤는지 이 이름으로 표시돼요',
);
