enum LedgerRole { owner, coOwner, member }

LedgerRole? parseRole(String? value) {
  switch (value) {
    case 'owner':
      return LedgerRole.owner;
    case 'co_owner':
      return LedgerRole.coOwner;
    case 'member':
      return LedgerRole.member;
  }
  return null;
}

String roleLabel(LedgerRole role) {
  switch (role) {
    case LedgerRole.owner:
      return '방장';
    case LedgerRole.coOwner:
      return '부방장';
    case LedgerRole.member:
      return '멤버';
  }
}

/// GET /ledgers 의 한 항목
class LedgerSummary {
  const LedgerSummary({
    required this.id,
    required this.name,
    required this.nickname,
    required this.isPending,
    this.role,
    this.memberCount,
    this.pendingCount,
    this.monthExpense,
  });

  factory LedgerSummary.fromJson(Map<String, dynamic> json) {
    return LedgerSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      nickname: json['nickname'] as String,
      isPending: json['status'] == 'pending',
      role: parseRole(json['role'] as String?),
      memberCount: json['member_count'] as int?,
      pendingCount: json['pending_count'] as int?,
      monthExpense: json['month_expense'] as int?,
    );
  }

  final String id;
  final String name;
  final String nickname;
  final bool isPending;
  final LedgerRole? role;
  final int? memberCount;
  final int? pendingCount;
  final int? monthExpense;
}
