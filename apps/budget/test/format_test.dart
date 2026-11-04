import 'package:flutter_test/flutter_test.dart';
import 'package:budget/models/category.dart';
import 'package:budget/models/ledger_summary.dart';
import 'package:budget/models/transaction.dart';
import 'package:budget/utils/format.dart';
import 'package:budget/widgets/filter_bar.dart';

void main() {
  test('won()은 천 단위 쉼표와 부호를 붙인다', () {
    expect(won(0), '0원');
    expect(won(1284500), '1,284,500원');
    expect(won(-12000, signed: true), '-12,000원');
    expect(won(4200000, signed: true), '+4,200,000원');
  });

  test('달력 칸 금액은 만 원 단위로 줄인다', () {
    expect(compactWon(8000), '8,000');
    expect(compactWon(18000), '1.8만');
    expect(compactWon(50000), '5만');
    expect(compactWon(4200000), '420만');
  });

  test('금액 입력 파싱', () {
    expect(parseAmount('86,400'), 86400);
    expect(parseAmount(''), 0);
  });

  test('currentMonth()는 한국 시간 기준', () {
    // UTC 10월 31일 16시 = KST 11월 1일 1시
    expect(currentMonth(DateTime.utc(2026, 10, 31, 16)), '2026-11');
    expect(addMonths('2026-12', 1), '2027-01');
    expect(addMonths('2026-01', -1), '2025-12');
    expect(dayHeading(DateTime(2026, 10, 27)), '27일 화요일');
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

  test('카테고리는 종류에 따라 지출·수입에 쓸 수 있다', () {
    const food = Category(id: 'a', type: CategoryType.common, name: '식비', sortOrder: 0);
    const sub = Category(id: 'b', type: CategoryType.expense, name: '구독료', sortOrder: 0);
    const pay = Category(id: 'c', type: CategoryType.income, name: '용돈', sortOrder: 0);
    expect(food.usableFor(false) && food.usableFor(true), isTrue);
    expect(sub.usableFor(false), isTrue);
    expect(sub.usableFor(true), isFalse);
    expect(pay.usableFor(true), isTrue);
    expect(pay.usableFor(false), isFalse);
  });

  test('월별 내역을 날짜별로 묶고 날짜별 합계를 낸다', () {
    final data = MonthData.fromJson({
      'month': '2026-10',
      'summary': {'income': 50000, 'expense': 98400},
      'transactions': [
        {'id': '1', 'type': 'expense', 'amount': 12000, 'spent_at': '2026-10-27', 'member_nickname': '아빠'},
        {'id': '2', 'type': 'expense', 'amount': 86400, 'spent_at': '2026-10-27', 'member_nickname': '엄마'},
        {'id': '3', 'type': 'income', 'amount': 50000, 'spent_at': '2026-10-25', 'member_nickname': '아빠'},
      ],
    });
    final groups = data.byDay();
    expect(groups.length, 2);
    expect(groups.first.$2.length, 2);
    expect(data.dailyTotals()[27], (0, 98400));
    expect(data.dailyTotals()[25], (50000, 0));
    expect(data.items.first.title, '미분류');
  });

  test('필터 라벨: 고른 카테고리 + 미분류, 지워진 카테고리는 빠진다', () {
    const cats = [
      Category(id: 'a', type: CategoryType.common, name: '식비', sortOrder: 0),
      Category(id: 'b', type: CategoryType.expense, name: '반려동물', sortOrder: 0),
    ];
    const sel = FilterSelection(categoryIds: {'b', 'gone'}, uncategorized: true);
    final pruned = sel.prune(cats);
    expect(pruned.count, 2);
    expect(pruned.labels(cats).map((l) => l.$2).toList(), ['반려동물', '미분류']);
    expect(pruned.without(null).uncategorized, isFalse);
    expect(pruned.without('b').categoryIds, isEmpty);
  });

  test('필터 라벨이 넘치면 +N 자리를 남기고 들어가는 만큼만 보인다', () {
    expect(visibleLabelCount([80, 80, 80], 300), 3);
    // 4개면 다 못 넣음: 80+6+80+6+80 = 252, 다음 +N 자리(54)까지 306 > 300 → 2개 + "+2"
    expect(visibleLabelCount([80, 80, 80, 80], 300), 2);
    expect(visibleLabelCount([400], 300), 0);
  });
}
