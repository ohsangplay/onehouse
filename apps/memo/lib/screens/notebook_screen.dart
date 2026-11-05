import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

import '../widgets/ad_banner.dart';
import '../models/memo.dart';
import '../services/memo_services.dart';
import '../theme.dart';
import '../utils/time.dart';
import '../widgets/offline_banner.dart';
import '../widgets/report_memo.dart';
import 'checklist_screen.dart';
import 'text_memo_screen.dart';
import 'trash_screen.dart';

/// 메모집 안의 메모 목록: 고정한 메모 먼저, 그다음 최근에 바뀐 순
class NotebookScreen extends StatefulWidget {
  const NotebookScreen({super.key, required this.services, required this.notebook});

  final MemoServices services;
  final SpaceSummary notebook;

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  List<MemoSummary>? _memos;
  Set<String> _drafts = const {};
  String? _error;
  late String _name = widget.notebook.name;

  MemoServices get _s => widget.services;
  String get _id => widget.notebook.id;
  String get _base => '/notebooks/$_id';

  @override
  void initState() {
    super.initState();
    final cached = _s.store.memos(_id);
    if (cached != null) _memos = cached.map(MemoSummary.fromJson).toList();
    _drafts = _s.store.draftMemoIds(_id);
    _s.syncTick.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _s.syncTick.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await _s.api.get('$_base/memos');
      final raw = (res['memos'] as List<dynamic>).cast<Map<String, dynamic>>();
      await _s.store.saveMemos(_id, raw);
      if (!mounted) return;
      setState(() {
        _memos = raw.map(MemoSummary.fromJson).toList();
        _drafts = _s.store.draftMemoIds(_id);
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isForbidden || e.status == 404) {
        showMessage(context, '이 메모집에 더 이상 들어갈 수 없어요.');
        Navigator.of(context).pop();
        return;
      }
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _drafts = _s.store.draftMemoIds(_id);
        _error = _memos == null ? errorMessage(e) : null;
      });
    }
  }

  bool _canDelete(MemoSummary m) => m.createdBy.id == widget.notebook.memberId || isManager(widget.notebook.role);

  Future<void> _openMemo(String? memoId, MemoKind kind) async {
    final screen = kind == MemoKind.checklist
        ? ChecklistScreen(services: _s, notebook: widget.notebook, memoId: memoId!)
        : TextMemoScreen(services: _s, notebook: widget.notebook, memoId: memoId);
    final saved = await Navigator.of(context).push<Object?>(MaterialPageRoute(builder: (_) => screen));
    if (saved is Memo && mounted) _upsert(saved);
    await _load();
  }

  /// 방금 저장한 메모를 목록에 먼저 반영 (서버 목록은 _load가 이어서 맞춘다)
  void _upsert(Memo memo) {
    final list = [...?_memos];
    final summary = MemoSummary(
      id: memo.id,
      kind: memo.kind,
      title: memo.title,
      preview: memo.body.length > 200 ? memo.body.substring(0, 200) : memo.body,
      pinned: memo.pinned,
      itemCount: memo.items.length,
      checkedCount: memo.items.where((i) => i.checked).length,
      createdBy: memo.createdBy,
      updatedBy: memo.updatedBy,
      updatedAt: memo.updatedAt,
    );
    list.removeWhere((m) => m.id == memo.id);
    list.add(summary);
    // 서버와 같은 순서: 고정한 메모 먼저, 그다음 최근에 바뀐 순
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    setState(() {
      _memos = list;
      _drafts = _s.store.draftMemoIds(_id);
    });
  }

  Future<void> _newMemo() async {
    if (!requireOnline(context, _s.network)) return;
    final kind = await showModalBottomSheet<MemoKind>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notes),
              title: const Text('글 메모'),
              subtitle: const Text('자유롭게 쓰는 메모'),
              onTap: () => Navigator.of(context).pop(MemoKind.text),
            ),
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('체크리스트'),
              subtitle: const Text('장보기·준비물처럼 하나씩 체크'),
              onTap: () => Navigator.of(context).pop(MemoKind.checklist),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;
    if (kind == MemoKind.text) return _openMemo(null, kind);

    final title = await promptText(context, title: '새 체크리스트', hint: '예) 장보기', maxLength: 100, action: '만들기');
    if (title == null || !mounted) return;
    try {
      final res = await _s.api.post('$_base/memos', {'kind': 'checklist', 'title': title});
      if (mounted) await _openMemo(res['id'] as String, MemoKind.checklist);
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<void> _actions(MemoSummary m) async {
    if (!requireOnline(context, _s.network)) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(m.displayTitle,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: Icon(m.pinned ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(m.pinned ? '고정 해제' : '맨 위에 고정'),
              onTap: () => Navigator.of(context).pop('pin'),
            ),
            if (_canDelete(m))
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('휴지통으로', style: TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            if (canReportMemo(widget.notebook, m.createdBy.id))
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('신고하기'),
                onTap: () => Navigator.of(context).pop('report'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'report') {
      await reportMemo(context,
          services: _s,
          notebook: widget.notebook,
          memoId: m.id,
          title: m.displayTitle,
          authorId: m.createdBy.id,
          authorNickname: m.createdBy.nickname);
      return;
    }
    try {
      if (action == 'pin') {
        await _s.api.patch('$_base/memos/${m.id}/pin', {'pinned': !m.pinned});
      } else if (action == 'delete') {
        await _s.api.delete('$_base/memos/${m.id}');
        if (mounted) showMessage(context, '휴지통으로 옮겼어요. 30일 안에 되살릴 수 있어요.');
      }
      await _load();
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<void> _settings() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SpaceSettingsScreen(services: _s.app, spaceId: _id)),
    );
    if (!mounted) return;
    if (result == true) {
      Navigator.of(context).pop();
      return;
    }
    // 이름이 바뀌었을 수 있다
    try {
      final detail = await _s.api.get(_base);
      if (mounted) setState(() => _name = detail['name'] as String);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final memos = _memos;
    final hasNewDraft = _drafts.contains('new');
    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        actions: [
          IconButton(
            tooltip: '휴지통',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await Navigator.of(context).push<void>(MaterialPageRoute(
                builder: (_) => TrashScreen(services: _s, notebookId: _id),
              ));
              await _load();
            },
          ),
          IconButton(tooltip: '메모집 설정', icon: const Icon(Icons.settings_outlined), onPressed: _settings),
        ],
      ),
      bottomNavigationBar: const AdBanner(),
      floatingActionButton: OnlineBuilder(
        network: _s.network,
        builder: (context, online) => FloatingActionButton.extended(
          onPressed: online ? _newMemo : () => showOfflineNotice(context),
          backgroundColor: online ? Theme.of(context).colorScheme.primary : const Color(0xFFB9BEC5),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('새 메모'),
        ),
      ),
      body: Column(
        children: [
          OfflineBanner(network: _s.network),
          Expanded(
            child: memos == null
                ? Center(
                    child: _error == null
                        ? const CircularProgressIndicator()
                        : TextButton(onPressed: _load, child: Text('$_error\n다시 시도', textAlign: TextAlign.center)),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: [
                        if (hasNewDraft)
                          _DraftCard(onTap: () => _openMemo(null, MemoKind.text)),
                        if (memos.isEmpty && !hasNewDraft)
                          const Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Center(
                              child: Text(
                                '아직 메모가 없어요.\n아래 "새 메모"로 첫 메모를 써 보세요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 15, height: 1.6, color: AppColors.textSecondary),
                              ),
                            ),
                          ),
                        for (final m in memos)
                          _MemoCard(
                            memo: m,
                            unsaved: _drafts.contains(m.id),
                            onTap: () => _openMemo(m.id, m.kind),
                            onLongPress: () => _actions(m),
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

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: MemoColors.soft,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.edit_note, color: MemoColors.primary),
            title: const Text('쓰던 새 메모가 있어요', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('연결이 끊겨 아직 저장되지 않았어요. 눌러서 이어 쓰기'),
            onTap: onTap,
          ),
        ),
      );
}

class _MemoCard extends StatelessWidget {
  const _MemoCard({required this.memo, required this.unsaved, required this.onTap, required this.onLongPress});

  final MemoSummary memo;
  final bool unsaved;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final checklist = memo.kind == MemoKind.checklist;
    final preview = memo.preview.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (memo.pinned) ...[
                      Icon(Icons.push_pin, size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                    ],
                    if (checklist) ...[
                      const Icon(Icons.checklist, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        memo.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (checklist && memo.itemCount > 0)
                      Text(
                        '${memo.checkedCount}/${memo.itemCount}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                  ],
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    preview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF3D434A)),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${memo.updatedBy.nickname} · ${relativeTime(memo.updatedAt)} 수정',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                    if (unsaved) const Tag('저장 안 됨'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
