import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

import '../services/memo_services.dart';
import '../utils/time.dart';
import '../widgets/offline_banner.dart';
import 'notebook_screen.dart';

/// 내 메모집 목록. 없으면 시작 화면.
class NotebookListScreen extends StatefulWidget {
  const NotebookListScreen({super.key, required this.services});

  final MemoServices services;

  @override
  State<NotebookListScreen> createState() => _NotebookListScreenState();
}

class _NotebookListScreenState extends State<NotebookListScreen> {
  List<SpaceSummary>? _notebooks;
  String? _error;

  MemoServices get _s => widget.services;

  @override
  void initState() {
    super.initState();
    // 마지막으로 받은 목록을 먼저 보여주고 서버에서 새로 받는다
    final cached = _s.store.notebooks();
    if (cached != null) _notebooks = cached.map(SpaceSummary.fromJson).toList();
    _load();
  }

  Future<void> _load({bool retried = false}) async {
    try {
      final res = await _s.api.get('/notebooks');
      final raw = (res['notebooks'] as List<dynamic>).cast<Map<String, dynamic>>();
      await _s.store.saveNotebooks(raw);
      if (!mounted) return;
      setState(() {
        _notebooks = raw.map(SpaceSummary.fromJson).toList();
        _error = null;
      });
    } on ApiException catch (e) {
      // 다른 기기로 이전된 토큰이면 새 기기 계정으로 다시 시작
      if (e.isUnauthorized && !retried) {
        await _s.app.session.reset();
        return _load(retried: true);
      }
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push<Object?>(MaterialPageRoute(builder: (_) => screen));
    await _load();
  }

  Future<void> _cancelRequest(SpaceSummary nb) async {
    try {
      await _s.api.post('/notebooks/${nb.id}/cancel-request');
      await _load();
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  void _guarded(Widget screen) {
    if (requireOnline(context, _s.network)) _open(screen);
  }

  @override
  Widget build(BuildContext context) {
    final notebooks = _notebooks;
    final app = _s.app;

    if (notebooks == null) {
      return Scaffold(
        body: Column(
          children: [
            SafeArea(bottom: false, child: OfflineBanner(network: _s.network, message: '오프라인이에요')),
            Expanded(
              child: Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : TextButton(onPressed: _load, child: Text('$_error\n다시 시도', textAlign: TextAlign.center)),
              ),
            ),
          ],
        ),
      );
    }

    if (notebooks.isEmpty) {
      return StartView(
        space: app.space,
        onCreate: () => _guarded(CreateSpaceScreen(services: app)),
        onJoin: () => _guarded(JoinScreen(services: app)),
        onTransfer: () => _guarded(TransferInScreen(services: app)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('내 메모집'), centerTitle: false),
      body: Column(
        children: [
          OfflineBanner(network: _s.network),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: notebooks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final nb = notebooks[i];
                  return nb.isPending
                      ? PendingCard(summary: nb, onRefresh: _load, onCancel: () => _cancelRequest(nb))
                      : _NotebookCard(
                          notebook: nb,
                          onTap: () => _open(NotebookScreen(services: _s, notebook: nb)),
                        );
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: OnlineBuilder(
            network: _s.network,
            builder: (context, online) => Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: online ? () => _open(JoinScreen(services: app)) : null,
                    child: const Text('코드로 참여'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: online ? () => _open(CreateSpaceScreen(services: app)) : null,
                    child: const Text('새 메모집'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotebookCard extends StatelessWidget {
  const _NotebookCard({required this.notebook, required this.onTap});

  final SpaceSummary notebook;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final role = notebook.role;
    final pending = notebook.pendingCount ?? 0;
    final memoCount = (notebook.raw['memo_count'] as num?)?.toInt() ?? 0;
    final last = DateTime.tryParse(notebook.raw['last_updated_at'] as String? ?? '');
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      notebook.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (role != null) ...[const SizedBox(width: 8), RoleBadge(role)],
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      '멤버 ${notebook.memberCount ?? 0}명${pending > 0 ? ' · 요청 $pending건' : ''}',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('메모 $memoCount개', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      if (last != null)
                        Text('${relativeTime(last)} 수정',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
