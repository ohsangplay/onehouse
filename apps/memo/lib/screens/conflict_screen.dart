import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

import '../models/memo.dart';
import '../theme.dart';
import '../utils/line_diff.dart';
import '../utils/time.dart';

enum ConflictChoice {
  /// 내 내용으로 저장 (지금 저장된 내용을 덮어씀)
  mine,

  /// 저장된 내용 쓰기 (내 내용은 클립보드로)
  theirs,

  /// 둘 다 남기기 (내 내용을 새 메모로)
  keepBoth,
}

/// 같은 줄을 서로 다르게 고쳤을 때: 저장된 내용과 내가 쓴 내용을 탭으로 비교하고 고른다.
/// 고르기 전에는 닫을 수 없다.
class ConflictScreen extends StatelessWidget {
  const ConflictScreen({super.key, required this.mineTitle, required this.mineBody, required this.current});

  final String mineTitle;
  final String mineBody;
  final Memo current;

  @override
  Widget build(BuildContext context) {
    final theirsChanged = changedLines(current.body, mineBody);
    final mineChanged = changedLines(mineBody, current.body);
    final titleDiffers = mineTitle.trim() != current.title.trim();

    return PopScope(
      canPop: false,
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppColors.surface,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            automaticallyImplyLeading: false,
            centerTitle: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('다른 멤버가 먼저 고쳤어요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(
                  '${current.updatedBy.nickname} · ${relativeTime(current.updatedAt)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
                ),
              ],
            ),
            bottom: const TabBar(tabs: [Tab(text: '저장된 내용'), Tab(text: '내가 쓴 내용')]),
          ),
          body: TabBarView(
            children: [
              _Version(
                title: current.title,
                body: current.body,
                changed: theirsChanged,
                titleChanged: titleDiffers,
                highlight: MemoColors.theirsLine,
              ),
              _Version(
                title: mineTitle,
                body: mineBody,
                changed: mineChanged,
                titleChanged: titleDiffers,
                highlight: MemoColors.mineLine,
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '색칠된 줄이 서로 다른 부분이에요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(ConflictChoice.keepBoth),
                    child: const Text('둘 다 남기기'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(ConflictChoice.theirs),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                          child: const Text('저장된 내용 쓰기', style: TextStyle(fontSize: 15)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(ConflictChoice.mine),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                          child: const Text('내 내용으로 저장', style: TextStyle(fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '둘 다 남기기: 내 내용을 "(내 수정본)" 새 메모로 저장해요\n저장된 내용 쓰기: 내 내용은 클립보드에 복사돼요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Version extends StatelessWidget {
  const _Version({
    required this.title,
    required this.body,
    required this.changed,
    required this.titleChanged,
    required this.highlight,
  });

  final String title;
  final String body;
  final Set<int> changed;
  final bool titleChanged;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    final lines = body.split('\n');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          color: titleChanged ? highlight : null,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            title.trim().isEmpty ? '(제목 없음)' : title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < lines.length; i++)
          Container(
            color: changed.contains(i) ? highlight : null,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            child: Text(lines[i].isEmpty ? ' ' : lines[i], style: const TextStyle(fontSize: 16, height: 1.5)),
          ),
      ],
    );
  }
}
