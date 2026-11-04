import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

import '../widgets/ad_banner.dart';
import '../services/memo_services.dart';
import '../utils/time.dart';
import '../widgets/offline_banner.dart';

/// 휴지통: 지운 지 30일 안 된 메모. 쓴 사람과 방장·부방장이 되살리거나, 30일을 기다리지 않고 바로 완전히 지울 수 있다.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key, required this.services, required this.notebookId});

  final MemoServices services;
  final String notebookId;

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<Map<String, dynamic>>? _items;
  int _days = 30;
  String? _error;

  String get _base => '/notebooks/${widget.notebookId}/memos';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await widget.services.api.get('$_base/trash');
      if (!mounted) return;
      setState(() {
        _items = (res['memos'] as List<dynamic>).cast<Map<String, dynamic>>();
        _days = (res['trash_days'] as num?)?.toInt() ?? 30;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  Future<void> _restore(Map<String, dynamic> m) async {
    if (!requireOnline(context, widget.services.network)) return;
    try {
      await widget.services.api.post('$_base/${m['id']}/restore');
      if (!mounted) return;
      showMessage(context, '메모를 되살렸어요.');
      await _load();
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  String _title(Map<String, dynamic> m) {
    final title = (m['title'] as String? ?? '').trim();
    if (title.isNotEmpty) return title;
    final first = (m['preview'] as String? ?? '').split('\n').first.trim();
    return first.isEmpty ? '제목 없음' : first;
  }

  Future<void> _deleteForever(Map<String, dynamic> m) async {
    if (!requireOnline(context, widget.services.network)) return;
    final ok = await confirmDialog(
      context,
      title: '\'${_title(m)}\' 메모를 완전히 지울까요?',
      message: '완전히 지운 메모는 되살릴 수 없어요.',
      action: '완전히 지우기',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      await widget.services.api.delete('$_base/${m['id']}/permanent');
      if (!mounted) return;
      showMessage(context, '메모를 완전히 지웠어요.');
      await _load();
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  Future<void> _emptyTrash() async {
    if (!requireOnline(context, widget.services.network)) return;
    final mine = (_items ?? const []).where((m) => m['can_restore'] == true).length;
    final all = _items?.length ?? 0;
    final ok = await confirmDialog(
      context,
      title: '휴지통을 비울까요?',
      message: mine == all
          ? '메모 $all개를 완전히 지워요. 되살릴 수 없어요.'
          : '내가 지울 수 있는 메모 $mine개를 완전히 지워요. 되살릴 수 없어요.\n(다른 사람이 쓴 메모는 쓴 사람이나 방장·부방장만 지울 수 있어요.)',
      action: '비우기',
      danger: true,
    );
    if (!ok || !mounted) return;
    try {
      final res = await widget.services.api.delete('$_base/trash');
      if (!mounted) return;
      showMessage(context, '메모 ${res['deleted'] ?? mine}개를 완전히 지웠어요.');
      await _load();
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final canEmpty = items != null && items.any((m) => m['can_restore'] == true);
    return Scaffold(
      appBar: AppBar(
        title: const Text('휴지통'),
        actions: [
          if (canEmpty)
            TextButton(
              onPressed: _emptyTrash,
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('비우기'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: const AdBanner(),
      body: Column(
        children: [
          OfflineBanner(network: widget.services.network),
          Expanded(
            child: items == null
                ? Center(
                    child: _error == null
                        ? const CircularProgressIndicator()
                        : TextButton(onPressed: _load, child: Text('$_error\n다시 시도', textAlign: TextAlign.center)),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                          child: Text('지운 메모는 $_days일 동안 여기 있다가 사라져요. 바로 완전히 지울 수도 있어요.',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ),
                        if (items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 60),
                            child: Center(
                              child: Text('휴지통이 비어 있어요', style: TextStyle(color: AppColors.textSecondary)),
                            ),
                          ),
                        for (final m in items)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                              title: Text(
                                _title(m),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                '${m['deleted_by'] ?? '알 수 없음'} · ${relativeTime(DateTime.tryParse(m['deleted_at'] as String? ?? '') ?? DateTime.now())} 삭제',
                              ),
                              trailing: m['can_restore'] == true
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton(onPressed: () => _restore(m), child: const Text('되살리기')),
                                        IconButton(
                                          tooltip: '완전히 지우기',
                                          icon: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
                                          onPressed: () => _deleteForever(m),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
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
