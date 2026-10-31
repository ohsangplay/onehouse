import 'package:flutter_test/flutter_test.dart';
import 'package:budget/models/ledger_summary.dart';
import 'package:budget/utils/format.dart';

void main() {
  test('won()은 천 단위 쉼표와 부호를 붙인다', () {
    expect(won(0), '0원');
    expect(won(1284500), '1,284,500원');
    expect(won(-12000, signed: true), '-12,000원');
    expect(won(4200000, signed: true), '+4,200,000원');
  });

  test('currentMonth()는 한국 시간 기준', () {
    // UTC 10월 31일 16시 = KST 11월 1일 1시
    expect(currentMonth(DateTime.utc(2026, 10, 31, 16)), '2026-11');
  });

  test('승인 대기 가계부는 역할이 없다', () {
    final ledger = LedgerSummary.fromJson({
      'id': 'l1',
      'name': '시댁 경조사',
      'nickname': '며느리',
      'status': 'pending',
      'role': null,
      'member_count': null,
      'pending_count': null,
      'month_expense': null,
    });
    expect(ledger.isPending, isTrue);
    expect(ledger.role, isNull);
  });

  test('역할 파싱', () {
    expect(parseRole('co_owner'), LedgerRole.coOwner);
    expect(roleLabel(LedgerRole.coOwner), '부방장');
  });
}
