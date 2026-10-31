import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onehouse_core/onehouse_core.dart';

void main() {
  test('조사', () {
    expect(josa('메모집', '을', '를'), '메모집을');
    expect(josa('가계부', '을', '를'), '가계부를');
    expect(josa('메모집', '이에요', '예요'), '메모집이에요');
  });

  test('역할 파싱', () {
    expect(parseRole('co_owner'), SpaceRole.coOwner);
    expect(roleLabel(SpaceRole.coOwner), '부방장');
    expect(isManager(SpaceRole.member), isFalse);
  });

  test('승인 대기 항목은 역할이 없다', () {
    final s = SpaceSummary.fromJson({
      'id': 'n1',
      'member_id': 'm1',
      'name': '우리집 메모',
      'nickname': '엄마',
      'status': 'pending',
      'role': null,
      'memo_count': null,
    });
    expect(s.isPending, isTrue);
    expect(s.role, isNull);
  });

  test('오류 응답의 추가 값(current)을 함께 넘긴다', () async {
    final api = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((req) async => http.Response(
            jsonEncode({
              'error': {'code': 'edit_conflict', 'message': '다른 멤버가 먼저 고쳤어요.'},
              'current': {'version': 3},
            }),
            409,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )),
    );
    try {
      await api.patch('/x', {});
      fail('예외가 나야 함');
    } on ApiException catch (e) {
      expect(e.isConflict, isTrue);
      expect((e.body['current'] as Map)['version'], 3);
    }
  });

  test('연결 실패는 오프라인으로', () async {
    final api = ApiClient(
      baseUrl: 'https://example.test',
      httpClient: MockClient((req) async => throw http.ClientException('no network')),
    );
    await expectLater(api.get('/x'), throwsA(isA<OfflineException>()));
    expect(api.network.online, isFalse);
    api.network.dispose();
  });
}
