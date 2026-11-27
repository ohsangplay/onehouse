import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

import '../config.dart';
import '../widgets/ad_banner.dart';
import '../services/memo_services.dart';
import '../services/push.dart';
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
  bool _pushRegistered = false;
  StreamSubscription<Map<String, dynamic>>? _pushSub;
  StreamSubscription<Uri>? _linkSub;
  String? _lastLinkCode;
  DateTime? _lastLinkAt;

  MemoServices get _s => widget.services;

  @override
  void initState() {
    super.initState();
    // 마지막으로 받은 목록을 먼저 보여주고 서버에서 새로 받는다
    final cached = _s.store.notebooks();
    if (cached != null) _notebooks = cached.map(SpaceSummary.fromJson).toList();
    _load();
    // 참여 요청·승인 알림이 오면 목록(참여 요청 수, 승인 대기)을 새로 받는다
    _pushSub = Push.events.listen((_) => _load());
    _listenInviteLinks();
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    _linkSub?.cancel();
    super.dispose();
  }

  /// 초대 링크(onehouse-memo://join?code=…)로 열리면 참여 화면에 코드를 채워서 띄운다.
  /// 앱이 꺼져 있다가 링크로 켜진 경우(처음 링크)와 켜져 있을 때 받은 링크 모두.
  void _listenInviteLinks() {
    if (kIsWeb) return;
    try {
      final links = AppLinks();
      _linkSub = links.uriLinkStream.listen(_onLink, onError: (_) {});
      links.getInitialLink().then((uri) {
        if (uri != null) _onLink(uri);
      }).catchError((_) {});
    } catch (_) {
      // 링크 플러그인이 없는 환경(테스트 등)에서는 무시
    }
  }

  void _onLink(Uri uri) {
    if (uri.scheme != inviteScheme || uri.host != 'join') return;
    final code = uri.queryParameters['code']?.trim();
    if (code == null || code.isEmpty) return;
    // 처음 링크가 스트림과 getInitialLink 양쪽으로 들어올 수 있어 한 번만 연다
    final now = DateTime.now();
    if (code == _lastLinkCode && _lastLinkAt != null && now.difference(_lastLinkAt!) < const Duration(seconds: 5)) {
      return;
    }
    _lastLinkCode = code;
    _lastLinkAt = now;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open(JoinScreen(services: _s.app, initialCode: code));
    });
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
      // 메모집이 생긴 뒤(만들었거나 참여를 요청했을 때) 알림 권한을 묻고 토큰을 등록한다
      if (raw.isNotEmpty && !_pushRegistered) {
        _pushRegistered = true;
        Push.register(_s.api);
      }
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
        privacyUrl: privacyUrl(app.api),
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
      bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
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
            // 광고가 없으면 아래 안전 영역만 차지한다
            const AdBanner(),
          ],
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
