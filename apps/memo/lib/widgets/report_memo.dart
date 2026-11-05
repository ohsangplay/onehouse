import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

import '../services/memo_services.dart';
import 'offline_banner.dart';

/// 다른 사람이 쓴 메모를 운영자에게 신고 (App Store 1.2). 내가 쓴 메모에는 보이지 않는다.
bool canReportMemo(SpaceSummary notebook, String authorId) => authorId != notebook.memberId;

Future<void> reportMemo(
  BuildContext context, {
  required MemoServices services,
  required SpaceSummary notebook,
  required String memoId,
  required String title,
  required String authorId,
  required String authorNickname,
}) async {
  if (!requireOnline(context, services.network)) return;
  await showReportSheet(
    context,
    services: services.app,
    spaceId: notebook.id,
    targetType: 'memo',
    targetId: memoId,
    targetMemberId: authorId,
    targetLabel: '$authorNickname님이 쓴 메모 · $title',
  );
}
