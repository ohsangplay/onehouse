import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

import '../services/memo_services.dart';
import '../utils/time.dart';
import '../widgets/offline_banner.dart';

/// 휴지통: 지운 지 30일 안 된 메모. 쓴 사람과 방장·부방장이 되살릴 수 있다.
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

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('휴지통')),
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
                          child: Text('지운 메모는 $_days일 동안 여기 있다가 사라져요.',
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
                                (m['title'] as String? ?? '').trim().isEmpty
                                    ? ((m['preview'] as String? ?? '').split('\n').first.trim().isEmpty
                                        ? '제목 없음'
                                        : (m['preview'] as String).split('\n').first.trim())
                                    : (m['title'] as String).trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                '${m['deleted_by'] ?? '알 수 없음'} · ${relativeTime(DateTime.tryParse(m['deleted_at'] as String? ?? '') ?? DateTime.now())} 삭제',
                              ),
                              trailing: m['can_restore'] == true
                                  ? TextButton(onPressed: () => _restore(m), child: const Text('되살리기'))
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
