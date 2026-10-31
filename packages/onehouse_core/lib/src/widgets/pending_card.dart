import 'package:flutter/material.dart';

import '../space_summary.dart';
import '../theme.dart';
import 'role_badge.dart';

/// 목록에서 승인을 기다리는 가계부·메모집 카드
class PendingCard extends StatelessWidget {
  const PendingCard({super.key, required this.summary, required this.onRefresh, required this.onCancel});

  final SpaceSummary summary;
  final VoidCallback onRefresh;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7CCD2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  summary.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              const Tag('승인 대기'),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '방장 승인을 기다리고 있어요. 승인되면 여기서 바로 열 수 있어요.',
            style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: onRefresh,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                child: const Text('새로고침', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: AppColors.textSecondary),
                child: const Text('요청 취소', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
