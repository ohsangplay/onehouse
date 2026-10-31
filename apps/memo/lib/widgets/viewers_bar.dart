import 'package:flutter/material.dart';

import '../models/memo.dart';
import '../theme.dart';

/// "엄마님이 고치고 있어요" / "엄마님 외 1명이 보고 있어요"
class ViewersBar extends StatelessWidget {
  const ViewersBar({super.key, required this.viewers});

  final List<Viewer> viewers;

  @override
  Widget build(BuildContext context) {
    if (viewers.isEmpty) return const SizedBox.shrink();
    final editors = viewers.where((v) => v.editing).toList();
    final first = (editors.isNotEmpty ? editors : viewers).first;
    final others = viewers.length - 1;
    final who = others > 0 ? '${first.nickname}님 외 $others명이' : '${first.nickname}님이';
    final what = editors.isNotEmpty ? '고치고 있어요' : '보고 있어요';
    return Container(
      width: double.infinity,
      color: MemoColors.soft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(editors.isNotEmpty ? Icons.edit : Icons.visibility_outlined, size: 16, color: MemoColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '지금 $who $what',
              style: const TextStyle(fontSize: 14, color: MemoColors.primary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
