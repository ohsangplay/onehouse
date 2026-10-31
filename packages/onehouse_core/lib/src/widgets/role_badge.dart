import 'package:flutter/material.dart';

import '../space_summary.dart';
import '../theme.dart';

class RoleBadge extends StatelessWidget {
  const RoleBadge(this.role, {super.key});

  final SpaceRole role;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final (fg, bg) = switch (role) {
      SpaceRole.owner => (primary, softOf(primary)),
      SpaceRole.coOwner => (AppColors.income, AppColors.incomeBg),
      SpaceRole.member => (AppColors.commonFg, AppColors.commonBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(roleLabel(role), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

/// 작은 라벨 (승인 대기, 이전에 차단한 멤버 등)
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.fg = AppColors.expenseFg, this.bg = AppColors.expenseBg});

  final String text;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
