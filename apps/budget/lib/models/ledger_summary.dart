import 'package:onehouse_core/onehouse_core.dart';

export 'package:onehouse_core/onehouse_core.dart' show SpaceRole, parseRole, roleLabel;

/// 예전 이름 호환
typedef LedgerRole = SpaceRole;

/// GET /ledgers 의 한 항목
class LedgerSummary {
  const LedgerSummary({
    required this.id,
    required this.name,
    required this.nickname,
    required this.isPending,
    this.memberId = '',
    this.role,
    this.memberCount,
    this.pendingCount,
    this.monthExpense,
  });

  factory LedgerSummary.fromJson(Map<String, dynamic> json) {
    final s = SpaceSummary.fromJson(json);
    return LedgerSummary(
      id: s.id,
      memberId: s.memberId,
      name: s.name,
      nickname: s.nickname,
      isPending: s.isPending,
      role: s.role,
      memberCount: s.memberCount,
      pendingCount: s.pendingCount,
      monthExpense: json['month_expense'] as int?,
    );
  }

  final String id;
  final String memberId;
  final String name;
  final String nickname;
  final bool isPending;
  final SpaceRole? role;
  final int? memberCount;
  final int? pendingCount;
  final int? monthExpense;

  SpaceSummary toSpaceSummary() => SpaceSummary(
        id: id,
        memberId: memberId,
        name: name,
        nickname: nickname,
        isPending: isPending,
        role: role,
        memberCount: memberCount,
        pendingCount: pendingCount,
      );
}
