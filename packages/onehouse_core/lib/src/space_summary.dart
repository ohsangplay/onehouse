enum SpaceRole { owner, coOwner, member }

SpaceRole? parseRole(String? value) {
  switch (value) {
    case 'owner':
      return SpaceRole.owner;
    case 'co_owner':
      return SpaceRole.coOwner;
    case 'member':
      return SpaceRole.member;
  }
  return null;
}

String roleLabel(SpaceRole role) {
  switch (role) {
    case SpaceRole.owner:
      return '방장';
    case SpaceRole.coOwner:
      return '부방장';
    case SpaceRole.member:
      return '멤버';
  }
}

bool isManager(SpaceRole? role) => role == SpaceRole.owner || role == SpaceRole.coOwner;

/// 목록(GET /ledgers, /notebooks)의 한 항목. 종류별 값(이번 달 지출, 메모 개수 등)은 [raw]에 있다.
class SpaceSummary {
  const SpaceSummary({
    required this.id,
    required this.memberId,
    required this.name,
    required this.nickname,
    required this.isPending,
    this.role,
    this.memberCount,
    this.pendingCount,
    this.raw = const {},
  });

  factory SpaceSummary.fromJson(Map<String, dynamic> json) {
    return SpaceSummary(
      id: json['id'] as String,
      memberId: json['member_id'] as String? ?? '',
      name: json['name'] as String,
      nickname: json['nickname'] as String,
      isPending: json['status'] == 'pending',
      role: parseRole(json['role'] as String?),
      memberCount: json['member_count'] as int?,
      pendingCount: json['pending_count'] as int?,
      raw: json,
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
  final Map<String, dynamic> raw;

  Map<String, dynamic> toJson() => raw;
}
