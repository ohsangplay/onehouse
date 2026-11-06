import 'dart:async';

import 'package:flutter/material.dart';
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

/// 체크리스트.
///
/// - 항목은 한 줄씩 따로 저장돼서 다른 항목을 동시에 고쳐도 부딪히지 않는다
/// - 체크·해제는 오프라인에서도 되고, 연결되면 순서대로 올라간다 (마지막에 누른 사람이 이김)
/// - 항목 추가·글자 수정·삭제·순서 바꾸기는 온라인에서만
/// - 같은 항목 글자를 동시에 고치면 어느 쪽으로 할지 고른다
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key, required this.services, required this.notebook, required this.memoId});

  final MemoServices services;
  final SpaceSummary notebook;
  final String memoId;

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final _add = TextEditingController();
  final _addFocus = FocusNode();
  Memo? _memo;
  String? _error;
  List<Viewer> _viewers = const [];
  bool _busy = false;

  /// 서버에 보내는 중인 새 항목(임시 id). 바로 목록에 보여주고, 응답이 오면 진짜 항목으로 바꾼다
  final Set<String> _adding = {};
  Future<void> _addQueue = Future.value();
  int _tempSeq = 0;
  bool _editing = false;
  Timer? _presence;

  MemoServices get _s => widget.services;
  NetworkStatus get _network => _s.network;
  String get _nb => widget.notebook.id;
  String get _base => '/notebooks/$_nb/memos/${widget.memoId}';

  @override
  void initState() {
    super.initState();
    final cached = _s.store.memo(widget.memoId);
    if (cached != null) _memo = _withPending(Memo.fromJson(cached));
    _s.syncTick.addListener(_load);
    _network.addListener(_onNetwork);
    _load();
    _presence = Timer.periodic(AppConfig.presenceInterval, (_) => _ping());
  }

  @override
  void dispose() {
    _presence?.cancel();
    _s.syncTick.removeListener(_load);
    _network.removeListener(_onNetwork);
    _s.api.delete('$_base/presence').catchError((_) => <String, dynamic>{});
    _add.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  void _onNetwork() {
    if (mounted) setState(() {});
  }

  /// 아직 못 보낸 오프라인 체크를 화면에 겹쳐 보여준다
  Memo _withPending(Memo memo) {
    final pending = {
      for (final c in _s.store.pendingChecks().where((c) => c.memoId == memo.id)) c.itemId: c.checked,
    };
    if (pending.isEmpty) return memo;
    return memo.copyWith(
      items: [for (final i in memo.items) pending.containsKey(i.id) ? i.copyWith(checked: pending[i.id]) : i],
    );
  }

  int get _pendingHere => _s.store.pendingChecks().where((c) => c.memoId == widget.memoId).length;

  // 보내는 중인 임시 항목은 기기에 저장하지 않는다
  Future<void> _store(Memo memo) => _s.store.saveMemo(
      memo.id, memo.copyWith(items: memo.items.where((i) => !_adding.contains(i.id)).toList()).toJson());

  Future<void> _load() async {
    try {
      final memo = Memo.fromJson(await _s.api.get(_base));
      await _store(memo);
      if (!mounted) return;
      setState(() {
        _memo = _withPending(memo);
        _viewers = memo.viewers;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'memo_deleted' || e.code == 'memo_not_found' || e.isForbidden) {
        showMessage(context, e.isForbidden ? '이 메모집에 더 이상 들어갈 수 없어요.' : e.message);
        Navigator.of(context).pop();
        return;
      }
      setState(() => _error = e.message);
    } catch (e) {
      if (mounted && _memo == null) setState(() => _error = '오프라인이라 이 메모를 불러오지 못했어요.');
    }
  }

  Future<void> _ping() async {
    final memo = _memo;
    if (memo == null || !_network.online) return;
    try {
      final res = await _s.api.post('$_base/presence', {'editing': _editing});
      if (!mounted) return;
      setState(() {
        _viewers = (res['viewers'] as List<dynamic>).map((e) => Viewer.fromJson(e as Map<String, dynamic>)).toList();
      });
      final updatedAt = DateTime.tryParse(res['updated_at'] as String? ?? '');
      final title = res['version'] != memo.version;
      if (!_editing && !_busy && _adding.isEmpty && (title || (updatedAt != null && updatedAt.isAfter(memo.updatedAt)))) {
        await _load();
      }
    } catch (_) {}
  }

  void _replaceItem(MemoItem item) {
    final memo = _memo;
    if (memo == null) return;
    final next = memo.copyWith(items: [for (final i in memo.items) i.id == item.id ? item : i]);
    setState(() => _memo = next);
    _store(next);
  }

  void _removeItem(String itemId) {
    final memo = _memo;
    if (memo == null) return;
    final next = memo.copyWith(items: memo.items.where((i) => i.id != itemId).toList());
    setState(() => _memo = next);
    _store(next);
  }

  // ── 체크 (오프라인 가능)

  Future<void> _toggle(MemoItem item) async {
    final checked = !item.checked;
    _replaceItem(item.copyWith(checked: checked, clearCheckedBy: !checked, checkedBy: checked ? '나' : null));
    if (!_network.online) {
      await _s.store.addPendingCheck(
        PendingCheck(notebookId: _nb, memoId: widget.memoId, itemId: item.id, checked: checked),
      );
      if (mounted) setState(() {});
      return;
    }
    try {
      final res = await _s.api.post('$_base/items/${item.id}/check', {'checked': checked});
      if (mounted) _replaceItem(MemoItem.fromJson(res));
    } on OfflineException {
      await _s.store.addPendingCheck(
        PendingCheck(notebookId: _nb, memoId: widget.memoId, itemId: item.id, checked: checked),
      );
      if (mounted) setState(() {});
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'item_deleted' || e.code == 'item_not_found') {
        _removeItem(item.id);
        showMessage(context, '다른 멤버가 지운 항목이에요.');
      } else {
        _replaceItem(item);
        showError(context, e);
      }
    }
  }

  // ── 온라인에서만

  /// 항목 추가: 입력칸을 바로 비우고 목록에 먼저 보여준 뒤, 서버에는 넣은 순서대로 보낸다
  void _addItem() {
    final text = _add.text.trim();
    final memo = _memo;
    if (text.isEmpty || memo == null) return;
    if (!requireOnline(context, _network)) return;
    final tempId = 'adding-${_tempSeq++}';
    final temp = MemoItem(
      id: tempId,
      text: text,
      checked: false,
      sortOrder: memo.items.length,
      version: 1,
      updatedAt: DateTime.now(),
      updatedBy: Person(widget.notebook.memberId, widget.notebook.nickname),
    );
    _adding.add(tempId);
    setState(() => _memo = memo.copyWith(items: [...memo.items, temp]));
    _add.clear();
    _addFocus.requestFocus();
    _addQueue = _addQueue.then((_) => _sendNewItem(tempId, text));
  }

  Future<void> _sendNewItem(String tempId, String text) async {
    try {
      final res = await _s.api.post('$_base/items', {'text': text});
      _adding.remove(tempId);
      final memo = _memo;
      if (memo == null || !mounted) return;
      final real = MemoItem.fromJson(res);
      final next = memo.copyWith(items: [for (final i in memo.items) i.id == tempId ? real : i]);
      setState(() => _memo = next);
      await _store(next);
    } catch (e) {
      _adding.remove(tempId);
      if (!mounted) return;
      final memo = _memo;
      if (memo != null) {
        setState(() => _memo = memo.copyWith(items: memo.items.where((i) => i.id != tempId).toList()));
      }
      // 못 넣은 글자는 입력칸에 돌려준다 (다른 걸 쓰는 중이면 그대로 둠)
      if (_add.text.trim().isEmpty) _add.text = text;
      showFailure(context, e);
    }
  }

  Future<void> _editItem(MemoItem item) async {
    if (!requireOnline(context, _network)) return;
    setState(() => _editing = true);
    final text = await promptText(context, title: '항목 고치기', initial: item.text, maxLength: 200);
    if (mounted) setState(() => _editing = false);
    if (text == null || text == item.text || !mounted) return;
    await _saveItemText(item, text, item.version);
  }

  Future<void> _saveItemText(MemoItem item, String text, int baseVersion) async {
    try {
      final res = await _s.api.patch('$_base/items/${item.id}', {'base_version': baseVersion, 'text': text});
      if (mounted) _replaceItem(MemoItem.fromJson(res));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'item_conflict') {
        final current = MemoItem.fromJson(e.body['current'] as Map<String, dynamic>);
        _replaceItem(current);
        final mine = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('${current.updatedBy.nickname}님이 먼저 고쳤어요',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('저장된 내용', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                Text(current.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                const Text('내가 쓴 내용', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('저장된 내용 쓰기')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('내 내용으로 저장')),
            ],
          ),
        );
        if (mine == true) await _saveItemText(current, text, current.version);
      } else if (e.code == 'item_deleted' || e.code == 'item_not_found') {
        _removeItem(item.id);
        showMessage(context, '다른 멤버가 지운 항목이에요.');
      } else {
        showError(context, e);
      }
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<bool> _deleteItem(MemoItem item) async {
    if (!requireOnline(context, _network)) return false;
    try {
      await _s.api.delete('$_base/items/${item.id}');
      _removeItem(item.id);
      return true;
    } on ApiException catch (e) {
      if (e.code == 'item_not_found') {
        _removeItem(item.id);
        return true;
      }
      if (mounted) showError(context, e);
      return false;
    } catch (e) {
      if (mounted) showFailure(context, e);
      return false;
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final memo = _memo;
    if (memo == null) return;
    if (_adding.isNotEmpty) {
      showMessage(context, '새 항목을 저장하는 중이에요. 잠시 뒤에 옮겨 주세요.');
      return;
    }
    if (!requireOnline(context, _network)) return;
    final items = [...memo.items];
    if (newIndex > oldIndex) newIndex -= 1;
    items.insert(newIndex, items.removeAt(oldIndex));
    setState(() => _memo = memo.copyWith(items: items));
    try {
      final res = await _s.api.put('$_base/items/order', {'ids': items.map((i) => i.id).toList()});
      final saved = (res['items'] as List<dynamic>).map((e) => MemoItem.fromJson(e as Map<String, dynamic>)).toList();
      if (!mounted) return;
      final next = memo.copyWith(items: saved);
      setState(() => _memo = _withPending(next));
      await _store(next);
    } catch (e) {
      if (!mounted) return;
      setState(() => _memo = memo);
      showFailure(context, e);
    }
  }

  Future<void> _rename() async {
    final memo = _memo;
    if (memo == null || !requireOnline(context, _network)) return;
    setState(() => _editing = true);
    final title = await promptText(context, title: '체크리스트 이름', initial: memo.title, maxLength: 100);
    if (mounted) setState(() => _editing = false);
    if (title == null || title == memo.title || !mounted) return;
    await _saveTitle(title, memo.version);
  }

  Future<void> _saveTitle(String title, int baseVersion) async {
    try {
      final res = await _s.api.patch(_base, {'base_version': baseVersion, 'title': title});
      final saved = Memo.fromJson(res['memo'] as Map<String, dynamic>);
      if (!mounted) return;
      setState(() => _memo = _withPending(saved));
      await _store(saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'edit_conflict') {
        final current = Memo.fromJson(e.body['current'] as Map<String, dynamic>);
        setState(() => _memo = _withPending(current));
        final mine = await confirmDialog(
          context,
          title: '${current.updatedBy.nickname}님이 이름을 먼저 바꿨어요',
          message: '저장된 이름: ${current.title}\n내가 쓴 이름: $title',
          action: '내 이름으로 저장',
        );
        if (mine) await _saveTitle(title, current.version);
      } else {
        showError(context, e);
      }
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<void> _menu(String action) async {
    if (!requireOnline(context, _network)) return;
    final memo = _memo;
    if (action == 'report' && memo != null) {
      await reportMemo(context,
          services: _s,
          notebook: widget.notebook,
          memoId: memo.id,
          title: memo.displayTitle,
          authorId: memo.createdBy.id,
          authorNickname: memo.createdBy.nickname);
      return;
    }
    try {
      if (action == 'clear') {
        final ok = await confirmDialog(context, title: '체크한 항목을 지울까요?', action: '지우기', danger: true);
        if (!ok) return;
        await _s.api.post('$_base/items/clear-checked');
        await _load();
      } else if (action == 'delete') {
        final ok = await confirmDialog(context, title: '이 체크리스트를 휴지통으로 옮길까요?', message: '30일 안에 휴지통에서 되살릴 수 있어요.', action: '옮기기', danger: true);
        if (!ok) return;
        await _s.api.delete(_base);
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  bool get _canDelete {
    final memo = _memo;
    return memo != null && (memo.createdBy.id == widget.notebook.memberId || isManager(widget.notebook.role));
  }

  @override
  Widget build(BuildContext context) {
    final memo = _memo;
    final online = _network.online;
    final primary = Theme.of(context).colorScheme.primary;
    final done = memo?.items.where((i) => i.checked).length ?? 0;
    final pending = _pendingHere;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: InkWell(
          onTap: _rename,
          child: Text(memo == null || memo.title.trim().isEmpty ? '체크리스트' : memo.title),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (_) => [
              PopupMenuItem(value: 'clear', enabled: online && done > 0, child: const Text('체크한 항목 지우기')),
              if (_canDelete) PopupMenuItem(value: 'delete', enabled: online, child: const Text('휴지통으로')),
              if (memo != null && canReportMemo(widget.notebook, memo.createdBy.id))
                PopupMenuItem(value: 'report', enabled: online, child: const Text('신고하기')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          OfflineBanner(network: _network, message: '오프라인이에요 · 체크만 할 수 있어요'),
          ViewersBar(viewers: _viewers),
          if (pending > 0)
            Container(
              width: double.infinity,
              color: AppColors.commonBg,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('체크 $pending개가 연결되면 반영돼요', style: const TextStyle(fontSize: 13, color: AppColors.commonFg)),
            ),
          if (memo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Text('$done/${memo.items.length} 완료',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primary)),
                  const Spacer(),
                  Text(
                    '마지막 수정: ${memo.updatedBy.nickname} · ${relativeTime(memo.updatedAt)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          Expanded(
            child: memo == null
                ? Center(
                    child: _error == null
                        ? const CircularProgressIndicator()
                        : Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: memo.items.isEmpty
                        ? ListView(
                            children: const [
                              Padding(
                                padding: EdgeInsets.only(top: 80),
                                child: Center(
                                  child: Text('아래에 첫 항목을 넣어 보세요',
                                      style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
                                ),
                              ),
                            ],
                          )
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                            buildDefaultDragHandles: false,
                            itemCount: memo.items.length,
                            // 새 onReorderItem은 Flutter 3.41부터라 예전 버전과 같이 쓰려고 onReorder를 둔다
                            // ignore: deprecated_member_use
                            onReorder: _reorder,
                            itemBuilder: (context, i) {
                              final item = memo.items[i];
                              final pending = _adding.contains(item.id);
                              return Dismissible(
                                key: ValueKey(item.id),
                                direction: online && !pending ? DismissDirection.endToStart : DismissDirection.none,
                                confirmDismiss: (_) => _deleteItem(item),
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: AppColors.danger,
                                  child: const Icon(Icons.delete_outline, color: Colors.white),
                                ),
                                child: _ItemTile(
                                  item: item,
                                  index: i,
                                  online: online && !pending,
                                  pending: pending,
                                  onToggle: () => _toggle(item),
                                  onEdit: () => _editItem(item),
                                ),
                              );
                            },
                          ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _add,
                      focusNode: _addFocus,
                      enabled: online && memo != null,
                      maxLength: 200,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addItem(),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: online ? '항목 추가' : '오프라인에서는 추가할 수 없어요',
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '추가',
                    onPressed: online && _add.text.trim().isNotEmpty && !_busy ? _addItem : null,
                    icon: Icon(Icons.add_circle, color: online ? primary : AppColors.border, size: 32),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.index,
    required this.online,
    required this.onToggle,
    required this.onEdit,
    this.pending = false,
  });

  final MemoItem item;
  final int index;
  final bool online;

  /// 서버에 보내는 중 (흐리게, 체크·고치기 막음)
  final bool pending;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final checkedBy = item.checkedBy;
    final links = findLinks(item.text);
    return Material(
      color: AppColors.background,
      child: Opacity(
       opacity: pending ? 0.55 : 1,
       child: Row(
        children: [
          Checkbox(value: item.checked, onChanged: pending ? null : (_) => onToggle()),
          Expanded(
            child: InkWell(
              onTap: online ? onEdit : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.text,
                      style: TextStyle(
                        fontSize: 16,
                        color: item.checked ? AppColors.textSecondary : AppColors.text,
                        decoration: item.checked ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (item.checked && checkedBy != null)
                      Text('$checkedBy 체크', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
          if (links.isNotEmpty)
            IconButton(
              tooltip: '링크 열기',
              icon: Icon(Icons.open_in_new, size: 20, color: Theme.of(context).colorScheme.primary),
              onPressed: () => openMemoLinks(context, links),
            ),
          if (online)
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Icon(Icons.drag_handle, color: AppColors.border),
              ),
            ),
        ],
       ),
      ),
    );
  }
}
