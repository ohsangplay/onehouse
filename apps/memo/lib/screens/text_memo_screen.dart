import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onehouse_core/onehouse_core.dart';

import '../config.dart';
import '../models/memo.dart';
import '../services/memo_services.dart';
import '../services/memo_store.dart';
import '../utils/time.dart';
import '../widgets/memo_links.dart';
import '../widgets/offline_banner.dart';
import '../widgets/report_memo.dart';
import '../widgets/viewers_bar.dart';
import 'conflict_screen.dart';

/// 글 메모 보기·쓰기.
///
/// - 고치다 멈추면 2.5초 뒤, 화면을 나갈 때 자동 저장
/// - 저장할 때 "몇 번 버전을 보고 고쳤는지"를 함께 보내고, 그사이 누가 고쳤으면 서버가 줄 단위로 합친다
/// - 같은 줄을 서로 다르게 고쳤으면 충돌 화면
/// - 연결이 끊기면 초안으로 남기고 저장 버튼을 끈다. 다시 연결되면 이어서 저장
/// - 오프라인에서 연 메모는 읽기만 할 수 있다
class TextMemoScreen extends StatefulWidget {
  const TextMemoScreen({super.key, required this.services, required this.notebook, this.memoId});

  final MemoServices services;
  final SpaceSummary notebook;

  /// null이면 새 메모 (처음 저장할 때 서버에 만들어진다)
  final String? memoId;

  @override
  State<TextMemoScreen> createState() => _TextMemoScreenState();
}

class _TextMemoScreenState extends State<TextMemoScreen> with WidgetsBindingObserver {
  final _title = TextEditingController();
  final _body = LinkTextEditingController();
  final _bodyFocus = FocusNode();

  String? _memoId;
  Memo? _memo;

  /// 내가 보고 고치기 시작한 서버 버전 (새 메모면 0)
  int _baseVersion = 0;

  /// 서버의 _baseVersion 내용과 같다고 확인된 글. null이면 모름(초안에서 이어 쓰는 중) → 저장 필요
  String? _syncedTitle;
  String? _syncedBody;

  late bool _loading = widget.memoId != null;
  bool _autofocus = false;
  bool _saving = false;
  bool _saveAgain = false;
  bool _resolving = false;
  bool _editedHere = false;
  bool _leaving = false;
  String? _loadError;
  List<Viewer> _viewers = const [];
  Timer? _debounce;
  Timer? _presence;

  MemoServices get _s => widget.services;
  NetworkStatus get _network => _s.network;
  String get _nb => widget.notebook.id;
  String get _base => '/notebooks/$_nb/memos';

  /// 내가 이 화면(또는 초안)에서 고친 게 서버에 아직 없음
  bool get _dirty => _editedHere && (_title.text != _syncedTitle || _body.text != _syncedBody);

  bool get _isEmptyNew => _memoId == null && _title.text.trim().isEmpty && _body.text.trim().isEmpty;

  /// 오프라인에서 연 메모는 읽기 전용. 고치던 중에 끊긴 경우는 계속 쓸 수 있다(초안으로 남음).
  bool get _editable => _network.online || _editedHere;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _memoId = widget.memoId;
    _network.addListener(_onNetwork);
    _restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _network.removeListener(_onNetwork);
    _debounce?.cancel();
    _presence?.cancel();
    final id = _memoId;
    if (id != null) {
      // 화면을 나가면 "보고 있어요"에서 바로 빠진다 (실패해도 30초 뒤 사라짐)
      _s.api.delete('$_base/$id/presence').catchError((_) => <String, dynamic>{});
    }
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 뒤로 가면 초안을 남기고 바로 저장해 둔다
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_dirty && !_isEmptyNew) {
        _writeDraft();
        _save();
      }
    } else if (state == AppLifecycleState.resumed) {
      _network.check();
    }
  }

  // ── 불러오기

  Future<void> _restore() async {
    final draft = _s.store.draft(_nb, _memoId);
    final id = _memoId;

    if (id != null) {
      final cached = _s.store.memo(id);
      if (cached != null) _showServer(Memo.fromJson(cached), keepText: draft != null);
    }
    if (draft != null) {
      _title.text = draft.title;
      _body.text = draft.body;
      _baseVersion = draft.baseVersion;
      _syncedTitle = null; // 초안은 아직 서버에 없다
      _syncedBody = null;
      _editedHere = true;
    }
    if (id == null) {
      _autofocus = draft == null;
      return;
    }

    try {
      final res = await _s.api.get('$_base/$id');
      final memo = Memo.fromJson(res);
      await _s.store.saveMemo(id, memo.toJson());
      if (!mounted) return;
      _showServer(memo, keepText: draft != null);
      setState(() {
        _viewers = memo.viewers;
        _loading = false;
        _loadError = null;
      });
      _startPresence();
      if (draft != null) _save();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'memo_deleted' || e.code == 'memo_not_found') {
        if (draft != null) {
          await _handleDeleted();
        } else {
          showMessage(context, e.message);
          Navigator.of(context).pop();
        }
        return;
      }
      if (e.isForbidden) {
        showMessage(context, '이 메모집에 더 이상 들어갈 수 없어요.');
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _loading = false;
        _loadError = _memo == null ? e.message : null;
      });
    } catch (e) {
      // 오프라인: 기기에 남은 내용으로 보여준다
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _memo == null && draft == null ? '오프라인이라 이 메모를 불러오지 못했어요.' : null;
      });
    }
  }

  /// 서버 내용을 화면에 반영. keepText면 화면 글은 그대로 두고 정보(마지막 수정 등)만 바꾼다.
  void _showServer(Memo memo, {bool keepText = false}) {
    _memo = memo;
    if (keepText) return;
    _setText(memo.title, memo.body);
    _baseVersion = memo.version;
    _syncedTitle = memo.title;
    _syncedBody = memo.body;
  }

  /// 커서 위치를 최대한 유지하면서 글을 바꾼다
  void _setText(String title, String body) {
    if (_title.text != title) {
      _title.value = TextEditingValue(
        text: title,
        selection: TextSelection.collapsed(offset: _clamp(_title.selection.baseOffset, title.length)),
      );
    }
    if (_body.text != body) {
      _body.value = TextEditingValue(
        text: body,
        selection: TextSelection.collapsed(offset: _clamp(_body.selection.baseOffset, body.length)),
      );
    }
  }

  int _clamp(int offset, int length) => offset < 0 ? length : (offset > length ? length : offset);

  // ── 고치기·저장

  void _onChanged() {
    if (!_editedHere) setState(() => _editedHere = true);
    _writeDraft();
    _debounce?.cancel();
    _debounce = Timer(AppConfig.autosaveDelay, _save);
    setState(() {});
  }

  void _writeDraft() {
    if (_isEmptyNew) {
      _s.store.clearDraft(_nb, null);
      return;
    }
    _s.store.saveDraft(Draft(
      notebookId: _nb,
      memoId: _memoId,
      title: _title.text,
      body: _body.text,
      baseVersion: _baseVersion,
    ));
  }

  void _onNetwork() {
    if (!mounted) return;
    setState(() {});
    if (_network.online) {
      if (_dirty) _save();
      if (_presence == null && _memoId != null) _startPresence();
    }
  }

  Future<void> _save() async {
    _debounce?.cancel();
    if (_saving || _resolving) {
      _saveAgain = true;
      return;
    }
    if (!_dirty || !_network.online || _isEmptyNew) return;

    final title = _title.text;
    final body = _body.text;
    setState(() => _saving = true);
    try {
      final id = _memoId;
      if (id == null) {
        final res = await _s.api.post(_base, {'kind': 'text', 'title': title, 'body': body});
        final memo = Memo.fromJson(res);
        _memoId = memo.id;
        await _s.store.clearDraft(_nb, null);
        _applySaved(memo, title, body, merged: false);
        _startPresence();
      } else {
        final res = await _s.api.patch('$_base/$id', {'base_version': _baseVersion, 'title': title, 'body': body});
        _applySaved(Memo.fromJson(res['memo'] as Map<String, dynamic>), title, body, merged: res['merged'] == true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'edit_conflict') {
        await _resolveConflict(title, body, Memo.fromJson(e.body['current'] as Map<String, dynamic>));
      } else if (e.code == 'memo_deleted' || e.code == 'memo_not_found') {
        await _handleDeleted();
      } else if (e.isForbidden) {
        showMessage(context, '이 메모집에 더 이상 들어갈 수 없어요. 쓰던 내용은 기기에 남겨 뒀어요.');
      } else {
        showMessage(context, '저장하지 못했어요: ${e.message}');
      }
    } on OfflineException {
      // 초안은 이미 기기에 있다. 연결되면 _onNetwork에서 다시 저장한다.
      _writeDraft();
    } catch (e) {
      if (mounted) showMessage(context, '저장하지 못했어요. 연결되면 다시 시도할게요.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        if (_saveAgain) {
          _saveAgain = false;
          if (_dirty) _debounce = Timer(const Duration(milliseconds: 300), _save);
        }
      }
    }
  }

  /// 저장 결과 반영. 보내는 사이에 더 쓴 게 있으면 그 글은 지키고 다음 저장에서 다시 합친다.
  void _applySaved(Memo memo, String sentTitle, String sentBody, {required bool merged}) {
    _memo = memo;
    _s.store.saveMemo(memo.id, memo.toJson());
    if (!mounted) return;
    final untouched = _title.text == sentTitle && _body.text == sentBody;
    setState(() {
      if (untouched) {
        // 다른 사람의 수정이 합쳐졌으면 화면에도 반영
        if (merged) _setText(memo.title, memo.body);
        _baseVersion = memo.version;
        _syncedTitle = memo.title;
        _syncedBody = memo.body;
      } else if (!merged) {
        // 서버에는 보낸 글 그대로 저장됨. 그 뒤에 더 쓴 건 다음 저장으로
        _baseVersion = memo.version;
        _syncedTitle = memo.title;
        _syncedBody = memo.body;
      }
      // merged인데 그사이 더 썼으면: 기준 버전을 그대로 두고 다음 저장에서 서버가 다시 합친다
    });
    if (untouched) {
      _s.store.clearDraft(_nb, memo.id);
    } else {
      _writeDraft();
      _debounce = Timer(AppConfig.autosaveDelay, _save);
    }
    if (merged && untouched && mounted) {
      showMessage(context, '${memo.updatedBy.nickname}님이 고친 내용과 합쳐서 저장했어요.');
    }
  }

  Future<void> _resolveConflict(String mineTitle, String mineBody, Memo current) async {
    _resolving = true;
    _memo = current;
    final choice = await Navigator.of(context).push<ConflictChoice>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ConflictScreen(mineTitle: mineTitle, mineBody: mineBody, current: current),
      ),
    );
    _resolving = false;
    if (!mounted) return;

    switch (choice ?? ConflictChoice.keepBoth) {
      case ConflictChoice.mine:
        // 지금 저장된 버전을 기준으로 내 글을 다시 저장 = 덮어쓰기
        _baseVersion = current.version;
        _syncedTitle = current.title;
        _syncedBody = current.body;
        await _save();
      case ConflictChoice.theirs:
        await Clipboard.setData(ClipboardData(text: _joinForClipboard(mineTitle, mineBody)));
        _useServer(current);
        if (mounted) showMessage(context, '내가 쓴 내용은 복사해 뒀어요.');
      case ConflictChoice.keepBoth:
        try {
          final title = '${mineTitle.trim().isEmpty ? current.displayTitle : mineTitle.trim()} (내 수정본)';
          await _s.api.post(_base, {
            'kind': 'text',
            'title': title.length > 100 ? title.substring(0, 100) : title,
            'body': mineBody,
          });
          _useServer(current);
          if (mounted) showMessage(context, '내 수정본을 새 메모로 저장했어요.');
        } catch (e) {
          // 새 메모를 못 만들었으면 내 글을 그대로 두고 초안으로 남긴다
          _writeDraft();
          if (mounted) showFailure(context, e);
        }
    }
  }

  void _useServer(Memo memo) {
    setState(() {
      _showServer(memo);
    });
    _s.store.saveMemo(memo.id, memo.toJson());
    _s.store.clearDraft(_nb, memo.id);
  }

  String _joinForClipboard(String title, String body) => title.trim().isEmpty ? body : '$title\n\n$body';

  Future<void> _handleDeleted() async {
    final keep = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('다른 멤버가 이 메모를 지웠어요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: const Text('내가 쓴 내용을 새 메모로 저장할까요?', style: TextStyle(height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('버리기')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('새 메모로 저장')),
        ],
      ),
    );
    if (!mounted) return;
    final oldId = _memoId;
    if (oldId != null) {
      await _s.store.clearDraft(_nb, oldId);
      await _s.store.saveMemo(oldId, null);
    }
    if (keep == true) {
      _memoId = null;
      _baseVersion = 0;
      _syncedTitle = null;
      _syncedBody = null;
      _presence?.cancel();
      _presence = null;
      await _save();
    } else {
      _syncedTitle = _title.text;
      _syncedBody = _body.text;
      if (mounted) Navigator.of(context).pop(MemoDeleted(id));
    }
  }

  // ── 보고 있어요

  void _startPresence() {
    _presence?.cancel();
    _presence = Timer.periodic(AppConfig.presenceInterval, (_) => _ping());
    _ping();
  }

  Future<void> _ping() async {
    final id = _memoId;
    if (id == null || !_network.online) return;
    try {
      final res = await _s.api.post('$_base/$id/presence', {'editing': _dirty || _bodyFocus.hasFocus});
      if (!mounted) return;
      final viewers = (res['viewers'] as List<dynamic>).map((e) => Viewer.fromJson(e as Map<String, dynamic>)).toList();
      setState(() => _viewers = viewers);
      // 보고만 있는 동안 누가 고쳤으면 새 내용으로
      final version = (res['version'] as num).toInt();
      if (version > _baseVersion && !_dirty && !_saving && !_resolving) {
        final memo = Memo.fromJson(await _s.api.get('$_base/$id'));
        if (!mounted || _dirty || _saving) return;
        await _s.store.saveMemo(id, memo.toJson());
        setState(() => _showServer(memo));
      }
    } on ApiException catch (e) {
      if (e.code == 'memo_deleted' && mounted && !_dirty) {
        showMessage(context, e.message);
        Navigator.of(context).pop();
      }
    } catch (_) {}
  }

  // ── 나가기·삭제

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    _debounce?.cancel();
    // 자동 저장이 보내는 중이면 끝날 때까지 기다린다 (먼저 나가면 목록에 새 메모가 빠진 채로 보임)
    await _waitSaving();
    if (_isEmptyNew) {
      await _s.store.clearDraft(_nb, null);
    } else if (_dirty) {
      _writeDraft();
      if (_network.online) {
        await _save();
        await _waitSaving();
      }
      if (mounted && _dirty) {
        showMessage(context, _network.online ? '저장하지 못한 내용은 기기에 남겨 뒀어요.' : '오프라인이라 기기에 남겨 뒀어요. 연결되면 이어서 저장돼요.');
      }
    }
    // 저장된 메모를 돌려줘서 목록이 서버 응답을 기다리지 않고 바로 보여 준다
    if (mounted) Navigator.of(context).pop(_memo);
  }

  Future<void> _waitSaving() async {
    for (var i = 0; (_saving || _resolving) && i < 300 && mounted; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    _debounce?.cancel();
    _saveAgain = false;
  }

  Future<void> _delete() async {
    final id = _memoId;
    if (id == null) {
      await _s.store.clearDraft(_nb, null);
      _syncedTitle = _title.text;
      _syncedBody = _body.text;
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (!requireOnline(context, _network)) return;
    final ok = await confirmDialog(context, title: '이 메모를 휴지통으로 옮길까요?', message: '30일 안에 휴지통에서 되살릴 수 있어요.', action: '옮기기', danger: true);
    if (!ok) return;
    try {
      _debounce?.cancel();
      await _s.api.delete('$_base/$id');
      await _s.store.clearDraft(_nb, id);
      _syncedTitle = _title.text;
      _syncedBody = _body.text;
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  bool get _canDelete {
    final memo = _memo;
    if (memo == null) return true;
    return memo.createdBy.id == widget.notebook.memberId || isManager(widget.notebook.role);
  }

  bool get _canReport {
    final memo = _memo;
    return memo != null && canReportMemo(widget.notebook, memo.createdBy.id);
  }

  Future<void> _report() async {
    final memo = _memo;
    if (memo == null) return;
    await reportMemo(context,
        services: _s,
        notebook: widget.notebook,
        memoId: memo.id,
        title: memo.displayTitle,
        authorId: memo.createdBy.id,
        authorNickname: memo.createdBy.nickname);
  }

  List<Uri> get _links => findLinks('${_title.text}\n${_body.text}');

  String get _status {
    if (_saving) return '저장 중…';
    if (!_dirty || _isEmptyNew) return _memoId == null ? '' : '저장됨';
    if (!_network.online) return '오프라인 · 연결되면 저장돼요';
    return '저장 전';
  }

  @override
  Widget build(BuildContext context) {
    final memo = _memo;
    final editable = _editable;
    final canSave = _network.online && _dirty && !_saving && !_isEmptyNew;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          leading: BackButton(onPressed: _leave),
          title: Text(_status, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: canSave
                  ? () {
                      FocusScope.of(context).unfocus();
                      _save();
                    }
                  : null,
              child: const Text('저장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (_canDelete || _canReport)
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') _delete();
                  if (v == 'report') _report();
                },
                itemBuilder: (_) => [
                  if (_canDelete)
                    PopupMenuItem(
                      value: 'delete',
                      enabled: _network.online || _memoId == null,
                      child: Text(_memoId == null ? '쓰던 내용 버리기' : '휴지통으로'),
                    ),
                  if (_canReport) PopupMenuItem(value: 'report', enabled: _network.online, child: const Text('신고하기')),
                ],
              ),
          ],
        ),
        body: Column(
          children: [
            OfflineBanner(
              network: _network,
              message: _editedHere ? '오프라인이에요 · 쓰던 내용은 기기에 남아요' : '오프라인이에요 · 읽기만 할 수 있어요',
            ),
            ViewersBar(viewers: _viewers),
            Expanded(
              child: _loading && memo == null && _memoId != null
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                      ? Center(child: Text(_loadError!, style: const TextStyle(color: AppColors.textSecondary)))
                      : ListView(
                          // 아래로 끌면 키보드가 내려간다 (아이폰은 여러 줄 입력칸에 키보드 닫기 버튼이 없음)
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                          children: [
                            TextField(
                              controller: _title,
                              readOnly: !editable,
                              maxLength: 100,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _bodyFocus.requestFocus(),
                              onChanged: (_) => _onChanged(),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                              decoration: const InputDecoration(
                                hintText: '제목',
                                counterText: '',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                            if (memo != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '마지막 수정: ${memo.updatedBy.nickname} · ${relativeTime(memo.updatedAt)}',
                                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ),
                            TextField(
                              controller: _body,
                              focusNode: _bodyFocus,
                              autofocus: _autofocus,
                              readOnly: !editable,
                              maxLines: null,
                              minLines: 12,
                              keyboardType: TextInputType.multiline,
                              onChanged: (_) => _onChanged(),
                              style: const TextStyle(fontSize: 17, height: 1.6),
                              decoration: InputDecoration(
                                hintText: editable ? '메모를 입력하세요' : '',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ],
                        ),
            ),
            // 글 속 링크는 아래 줄에서 눌러 연다
            // 쓰는 중(키보드가 올라와 있을 때)에도 키보드 바로 위에 보인다
            if (_links.isNotEmpty) MemoLinkBar(links: _links),
          ],
        ),
      ),
    );
  }
}
