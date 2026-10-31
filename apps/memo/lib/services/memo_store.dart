import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 쓰다가 연결이 끊겼거나 앱이 꺼졌을 때 남겨 두는 초안
class Draft {
  const Draft({
    required this.notebookId,
    required this.memoId,
    required this.title,
    required this.body,
    required this.baseVersion,
  });

  factory Draft.fromJson(Map<String, dynamic> json) => Draft(
        notebookId: json['notebook_id'] as String,
        memoId: json['memo_id'] as String?,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        baseVersion: (json['base_version'] as num?)?.toInt() ?? 0,
      );

  final String notebookId;

  /// 아직 서버에 없는 새 메모면 null
  final String? memoId;
  final String title;
  final String body;

  /// 고치기 시작한 버전 (새 메모면 0). 다시 저장할 때 서버가 이 버전과 비교해 병합한다.
  final int baseVersion;

  Map<String, dynamic> toJson() => {
        'notebook_id': notebookId,
        'memo_id': memoId,
        'title': title,
        'body': body,
        'base_version': baseVersion,
      };
}

/// 오프라인에서 누른 체크·해제. 연결되면 순서대로 보낸다.
class PendingCheck {
  const PendingCheck({required this.notebookId, required this.memoId, required this.itemId, required this.checked});

  factory PendingCheck.fromJson(Map<String, dynamic> json) => PendingCheck(
        notebookId: json['notebook_id'] as String,
        memoId: json['memo_id'] as String,
        itemId: json['item_id'] as String,
        checked: json['checked'] == true,
      );

  final String notebookId;
  final String memoId;
  final String itemId;
  final bool checked;

  Map<String, dynamic> toJson() => {
        'notebook_id': notebookId,
        'memo_id': memoId,
        'item_id': itemId,
        'checked': checked,
      };
}

/// 기기에 남겨 두는 값: 마지막으로 받은 목록·메모(오프라인 읽기용), 초안, 오프라인 체크
class MemoStore {
  MemoStore(this._prefs);

  static Future<MemoStore> open() async => MemoStore(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  static const _notebooksKey = 'cache:notebooks';
  static const _checksKey = 'pending_checks';
  static String _memosKey(String notebookId) => 'cache:memos:$notebookId';
  static String _memoKey(String memoId) => 'cache:memo:$memoId';
  static String _draftKey(String notebookId, String? memoId) => 'draft:$notebookId:${memoId ?? 'new'}';

  Object? _read(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String key, Object? value) =>
      value == null ? _prefs.remove(key) : _prefs.setString(key, jsonEncode(value));

  // ── 목록·메모 캐시
  List<Map<String, dynamic>>? notebooks() => (_read(_notebooksKey) as List<dynamic>?)?.cast<Map<String, dynamic>>();

  Future<void> saveNotebooks(List<Map<String, dynamic>> items) => _write(_notebooksKey, items);

  List<Map<String, dynamic>>? memos(String notebookId) =>
      (_read(_memosKey(notebookId)) as List<dynamic>?)?.cast<Map<String, dynamic>>();

  Future<void> saveMemos(String notebookId, List<Map<String, dynamic>> items) => _write(_memosKey(notebookId), items);

  Map<String, dynamic>? memo(String memoId) => _read(_memoKey(memoId)) as Map<String, dynamic>?;

  Future<void> saveMemo(String memoId, Map<String, dynamic>? json) => _write(_memoKey(memoId), json);

  // ── 초안
  Draft? draft(String notebookId, String? memoId) {
    final json = _read(_draftKey(notebookId, memoId));
    return json is Map<String, dynamic> ? Draft.fromJson(json) : null;
  }

  Future<void> saveDraft(Draft draft) => _write(_draftKey(draft.notebookId, draft.memoId), draft.toJson());

  Future<void> clearDraft(String notebookId, String? memoId) => _write(_draftKey(notebookId, memoId), null);

  /// 서버에 아직 못 올린 초안이 있는 메모 ID들 (목록에 "저장 안 됨" 표시용)
  Set<String> draftMemoIds(String notebookId) {
    final prefix = 'draft:$notebookId:';
    return _prefs.getKeys().where((k) => k.startsWith(prefix)).map((k) => k.substring(prefix.length)).toSet();
  }

  // ── 오프라인 체크
  List<PendingCheck> pendingChecks() => ((_read(_checksKey) as List<dynamic>?) ?? const [])
      .map((e) => PendingCheck.fromJson(e as Map<String, dynamic>))
      .toList();

  /// 같은 항목을 여러 번 눌렀으면 마지막 것만 남긴다
  Future<void> addPendingCheck(PendingCheck check) {
    final list = pendingChecks().where((c) => c.itemId != check.itemId).toList()..add(check);
    return _write(_checksKey, list.map((c) => c.toJson()).toList());
  }

  Future<void> savePendingChecks(List<PendingCheck> checks) =>
      _write(_checksKey, checks.isEmpty ? null : checks.map((c) => c.toJson()).toList());
}
