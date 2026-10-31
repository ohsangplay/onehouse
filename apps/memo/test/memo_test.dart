import 'package:flutter_test/flutter_test.dart';
import 'package:memo/models/memo.dart';
import 'package:memo/services/memo_store.dart';
import 'package:memo/utils/line_diff.dart';
import 'package:memo/utils/time.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('메모 JSON → 모델 → JSON', () {
    final memo = Memo.fromJson({
      'id': 'm1',
      'kind': 'checklist',
      'title': '',
      'body': '',
      'version': 3,
      'pinned': true,
      'created_by': {'id': 'a', 'nickname': '아빠'},
      'updated_by': {'id': 'b', 'nickname': '엄마'},
      'created_at': '2026-10-31T01:00:00.000Z',
      'updated_at': '2026-10-31T02:00:00.000Z',
      'items': [
        {
          'id': 'i1',
          'text': '우유',
          'checked': true,
          'sort_order': 0,
          'version': 1,
          'updated_at': '2026-10-31T02:00:00.000Z',
          'updated_by': {'id': 'b', 'nickname': '엄마'},
          'checked_by': '엄마',
        },
      ],
    });
    expect(memo.isChecklist, isTrue);
    expect(memo.items.single.checkedBy, '엄마');
    final again = Memo.fromJson(memo.toJson());
    expect(again.version, 3);
    expect(again.items.single.text, '우유');
  });

  test('제목이 없으면 본문 첫 줄', () {
    final memo = Memo.fromJson({
      'id': 'm1',
      'kind': 'text',
      'title': ' ',
      'body': '\n와이파이 비밀번호\n1234',
      'created_by': {'id': 'a', 'nickname': '아빠'},
      'updated_by': {'id': 'a', 'nickname': '아빠'},
    });
    expect(memo.displayTitle, '와이파이 비밀번호');
  });

  test('충돌 화면 강조 줄', () {
    expect(changedLines('우유\n두부 2모\n대파', '우유\n두부 5모\n대파'), {1});
    expect(changedLines('a\na\nb', 'a\nb'), {1});
  });

  test('상대 시간', () {
    final now = DateTime(2026, 10, 31, 15, 0);
    expect(relativeTime(now.subtract(const Duration(seconds: 20)), now), '방금');
    expect(relativeTime(now.subtract(const Duration(minutes: 5)), now), '5분 전');
    expect(relativeTime(DateTime(2026, 10, 30, 20), now), '어제');
    expect(relativeTime(DateTime(2026, 9, 3), now), '9월 3일');
  });

  test('초안 저장·복원·삭제', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await MemoStore.open();
    await store.saveDraft(const Draft(notebookId: 'n1', memoId: 'm1', title: 't', body: 'b', baseVersion: 4));
    await store.saveDraft(const Draft(notebookId: 'n1', memoId: null, title: '', body: '새 메모', baseVersion: 0));
    expect(store.draft('n1', 'm1')?.baseVersion, 4);
    expect(store.draftMemoIds('n1'), {'m1', 'new'});
    await store.clearDraft('n1', 'm1');
    expect(store.draft('n1', 'm1'), isNull);
  });

  test('오프라인 체크는 같은 항목이면 마지막 것만', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await MemoStore.open();
    await store.addPendingCheck(const PendingCheck(notebookId: 'n', memoId: 'm', itemId: 'i1', checked: true));
    await store.addPendingCheck(const PendingCheck(notebookId: 'n', memoId: 'm', itemId: 'i2', checked: true));
    await store.addPendingCheck(const PendingCheck(notebookId: 'n', memoId: 'm', itemId: 'i1', checked: false));
    final pending = store.pendingChecks();
    expect(pending.length, 2);
    expect(pending.last.itemId, 'i1');
    expect(pending.last.checked, isFalse);
  });
}
