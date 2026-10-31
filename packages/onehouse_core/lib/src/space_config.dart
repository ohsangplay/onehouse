import 'package:flutter/widgets.dart';

import 'josa.dart';

/// 한지붕 시리즈 앱마다 다른 값. 공통 화면(시작·만들기·참여·복구코드·이전)이 이 값으로 문구와 API 주소를 바꾼다.
class SpaceConfig {
  const SpaceConfig({
    required this.appName,
    required this.noun,
    required this.apiPath,
    required this.listKey,
    required this.tagline,
    required this.icon,
    required this.nameHint,
    required this.ownerNicknameHint,
    required this.memberNicknameHint,
    required this.authorshipNote,
  });

  /// 한지붕 가계부 / 한지붕 메모
  final String appName;

  /// 가계부 / 메모집
  final String noun;

  /// /ledgers / /notebooks
  final String apiPath;

  /// 목록 응답의 키: ledgers / notebooks
  final String listKey;

  /// 시작 화면 소개 문구
  final String tagline;
  final IconData icon;

  /// 만들기 화면 이름 칸 예시
  final String nameHint;
  final String ownerNicknameHint;
  final String memberNicknameHint;

  /// 참여 화면 닉네임 칸 아래 안내 (예: 내역마다 누가 썼는지 이 이름으로 표시돼요)
  final String authorshipNote;

  /// "가계부를" / "메모집을"
  String get nounObj => josa(noun, '을', '를');

  /// "가계부가" / "메모집이"
  String get nounSubj => josa(noun, '이', '가');
}
