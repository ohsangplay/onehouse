import '../utils/format.dart';

/// 고정 지출·수입(매월) 또는 할부 (GET /ledgers/:id/recurring)
class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.installment,
    required this.isIncome,
    required this.amount,
    required this.day,
    required this.startDate,
    required this.memberId,
    required this.memberNickname,
    required this.done,
    this.months,
    this.monthlyAmount,
    this.firstAmount,
    this.categoryId,
    this.categoryName,
    this.memo,
    this.remainingAmount,
    this.nextDate,
    this.nextSeq,
    this.finished = false,
  });

  factory RecurringRule.fromJson(Map<String, dynamic> json) => RecurringRule(
        id: json['id'] as String,
        installment: json['kind'] == 'installment',
        isIncome: json['type'] == 'income',
        amount: (json['amount'] as num).toInt(),
        months: (json['months'] as num?)?.toInt(),
        monthlyAmount: (json['monthly_amount'] as num?)?.toInt(),
        firstAmount: (json['first_amount'] as num?)?.toInt(),
        categoryId: json['category_id'] as String?,
        categoryName: json['category_name'] as String?,
        memo: json['memo'] as String?,
        day: (json['day'] as num).toInt(),
        startDate: parseDate(json['start_date'] as String),
        memberId: json['member_id'] as String? ?? '',
        memberNickname: json['member_nickname'] as String? ?? '',
        done: (json['done'] as num?)?.toInt() ?? 0,
        remainingAmount: (json['remaining_amount'] as num?)?.toInt(),
        nextDate: json['next_date'] == null ? null : parseDate(json['next_date'] as String),
        nextSeq: (json['next_seq'] as num?)?.toInt(),
        finished: json['finished'] == true,
      );

  final String id;

  /// true: 할부, false: 매월 고정
  final bool installment;
  final bool isIncome;

  /// 고정: 매월 금액 / 할부: 총 결제 금액
  final int amount;
  final int? months;
  final int? monthlyAmount;
  final int? firstAmount;
  final String? categoryId;
  final String? categoryName;
  final String? memo;
  final int day;
  final DateTime startDate;
  final String memberId;
  final String memberNickname;

  /// 지금까지 기록된 회차 수
  final int done;
  final int? remainingAmount;
  final DateTime? nextDate;
  final int? nextSeq;
  final bool finished;

  String get title {
    final m = memo?.trim() ?? '';
    if (m.isNotEmpty) return m;
    return categoryName ?? (isIncome ? '고정 수입' : '고정 지출');
  }

  /// 매월 기록되는 금액
  int get perMonth => installment ? (monthlyAmount ?? amount) : amount;
}

/// 할부 회차별 금액 (서버와 같은 규칙: 나누어떨어지지 않는 원 단위는 1회차에)
(int first, int rest) installmentSplit(int total, int months) {
  final base = total ~/ months;
  return (base + (total - base * months), base);
}
