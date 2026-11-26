import '../utils/format.dart';
import 'category.dart';

/// 가계부 내역 한 건 (GET /ledgers/:id/transactions)
class Txn {
  const Txn({
    required this.id,
    required this.isIncome,
    required this.amount,
    required this.spentAt,
    required this.memberId,
    required this.memberNickname,
    this.categoryId,
    this.categoryName,
    this.categoryType,
    this.memo,
    this.ruleId,
    this.ruleSeq,
    this.ruleKind,
    this.ruleMonths,
  });

  factory Txn.fromJson(Map<String, dynamic> json) => Txn(
        id: json['id'] as String,
        isIncome: json['type'] == 'income',
        amount: (json['amount'] as num).toInt(),
        spentAt: parseDate(json['spent_at'] as String),
        memberId: json['member_id'] as String? ?? '',
        memberNickname: json['member_nickname'] as String? ?? '',
        categoryId: json['category_id'] as String?,
        categoryName: json['category_name'] as String?,
        categoryType: json['category_name'] == null ? null : parseCategoryType(json['category_type'] as String?),
        memo: json['memo'] as String?,
        ruleId: json['rule_id'] as String?,
        ruleSeq: (json['rule_seq'] as num?)?.toInt(),
        ruleKind: json['rule_kind'] as String?,
        ruleMonths: (json['rule_months'] as num?)?.toInt(),
      );

  final String id;
  final bool isIncome;
  final int amount;
  final DateTime spentAt;
  final String memberId;
  final String memberNickname;
  final String? categoryId;
  final String? categoryName;
  final CategoryType? categoryType;
  final String? memo;

  /// 고정·할부로 자동 기록된 내역이면 그 규칙과 회차
  final String? ruleId;
  final int? ruleSeq;

  /// fixed(고정) · installment(할부)
  final String? ruleKind;
  final int? ruleMonths;

  /// 목록에 붙는 작은 표시: "할부 3/12", "고정"
  String? get ruleBadge {
    if (ruleId == null) return null;
    if (ruleKind == 'installment') return '할부 $ruleSeq/${ruleMonths ?? '?'}';
    return '고정';
  }

  /// 목록에 크게 보이는 제목: 메모, 없으면 카테고리 이름
  String get title {
    final m = memo?.trim() ?? '';
    if (m.isNotEmpty) return m;
    return categoryName ?? '미분류';
  }

  /// 지출은 음수
  int get signed => isIncome ? amount : -amount;
}

/// 월별 조회 결과
class MonthData {
  const MonthData({required this.month, required this.income, required this.expense, required this.items});

  factory MonthData.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? const {};
    return MonthData(
      month: json['month'] as String,
      income: (summary['income'] as num?)?.toInt() ?? 0,
      expense: (summary['expense'] as num?)?.toInt() ?? 0,
      items: (json['transactions'] as List<dynamic>? ?? const [])
          .map((e) => Txn.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String month;
  final int income;
  final int expense;
  final List<Txn> items;

  /// 날짜별로 묶기 (최근 날짜 먼저). 서버가 이미 날짜 내림차순으로 준다.
  List<(DateTime, List<Txn>)> byDay() {
    final groups = <(DateTime, List<Txn>)>[];
    for (final t in items) {
      if (groups.isEmpty || groups.last.$1 != t.spentAt) {
        groups.add((t.spentAt, [t]));
      } else {
        groups.last.$2.add(t);
      }
    }
    return groups;
  }

  /// 날짜별 (수입, 지출) 합계
  Map<int, (int, int)> dailyTotals() {
    final totals = <int, (int, int)>{};
    for (final t in items) {
      final (inc, exp) = totals[t.spentAt.day] ?? (0, 0);
      totals[t.spentAt.day] = t.isIncome ? (inc + t.amount, exp) : (inc, exp + t.amount);
    }
    return totals;
  }
}
