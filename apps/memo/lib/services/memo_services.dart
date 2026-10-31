import 'package:flutter/foundation.dart';
import 'package:onehouse_core/onehouse_core.dart';

import 'memo_store.dart';

/// 메모 앱 화면들이 함께 쓰는 것: 공통 서비스 + 기기 저장소 + 오프라인 체크 보내기
class MemoServices {
  MemoServices({required this.app, required this.store}) {
    api.network.addListener(_onNetwork);
  }

  final AppServices app;
  final MemoStore store;

  ApiClient get api => app.api;
  NetworkStatus get network => app.api.network;

  /// 오프라인에서 모아 둔 체크를 보낸 뒤 1씩 오른다. 열려 있는 화면은 이걸 보고 다시 불러온다.
  final ValueNotifier<int> syncTick = ValueNotifier(0);

  bool _flushing = false;

  void _onNetwork() {
    if (network.online) flushChecks();
  }

  /// 오프라인 체크를 순서대로 보낸다. 그사이 지워진 항목(404)이나 접근할 수 없는 곳(403)은 버린다.
  Future<void> flushChecks() async {
    if (_flushing) return;
    _flushing = true;
    var sent = 0;
    try {
      for (;;) {
        final pending = store.pendingChecks();
        if (pending.isEmpty) break;
        final c = pending.first;
        try {
          await api.post('/notebooks/${c.notebookId}/memos/${c.memoId}/items/${c.itemId}/check', {'checked': c.checked});
        } on OfflineException {
          break;
        } on ApiException {
          // 지워진 항목·메모, 차단 등: 보낼 곳이 없으니 버린다
        }
        // 보내는 사이 같은 항목을 다시 눌렀으면 그건 남겨 둔다
        final rest = store.pendingChecks()..removeWhere((x) => x.itemId == c.itemId && x.checked == c.checked);
        await store.savePendingChecks(rest);
        sent++;
      }
    } finally {
      _flushing = false;
      if (sent > 0) syncTick.value++;
    }
  }
}
