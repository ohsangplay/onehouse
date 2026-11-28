import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:onehouse_core/onehouse_core.dart';

import '../models/ledger_summary.dart';
import '../utils/format.dart';
import '../config.dart';
import '../services/push.dart';
import '../widgets/ad_banner.dart';
import 'ledger_home_screen.dart';

class LedgerListScreen extends StatefulWidget {
  const LedgerListScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<LedgerListScreen> createState() => _LedgerListScreenState();
}

class _LedgerListScreenState extends State<LedgerListScreen> {
  List<LedgerSummary>? _ledgers;
  String? _error;
  bool _pushRegistered = false;
  StreamSubscription<Map<String, dynamic>>? _pushSub;
  StreamSubscription<Uri>? _linkSub;
  String? _lastLinkCode;
  DateTime? _lastLinkAt;
  /// 링크로 받은 초대 코드: 목록을 처음 불러온 뒤(첫 화면이 자리 잡은 뒤)에 참여 화면을 연다
  String? _pendingInviteCode;

  @override
  void initState() {
    super.initState();
    _load();
    // 참여 요청·승인 알림이 오면 목록(대기 수·새 가계부)을 새로 고친다
    _pushSub = Push.events.listen((data) {
      if (!mounted) return;
      if (data['opened'] == 'true') {
        _openFromPush(data);
      } else {
        _load();
      }
    });
    _listenInviteLinks();
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    _linkSub?.cancel();
    super.dispose();
  }

  /// 알림을 눌렀을 때: 참여 요청 → 그 가계부의 멤버 관리, 그 밖(승인·내역) → 그 가계부
  Future<void> _openFromPush(Map<String, dynamic> data) async {
    final spaceId = data['space_id'] as String?;
    if (spaceId == null) return;
    await _load();
    if (!mounted) return;
    final ledger = _ledgers?.where((l) => l.id == spaceId).firstOrNull;
    if (ledger == null || ledger.isPending) return;
    // 이미 다른 화면이 열려 있으면 목록으로 돌아온 뒤 연다
    Navigator.of(context).popUntil((route) => route.isFirst);
    final role = ledger.role ?? SpaceRole.member;
    if (data['type'] == 'join_request' && isManager(role)) {
      await _open(MembersScreen(
        services: widget.services,
        spaceId: ledger.id,
        myMemberId: ledger.memberId,
        myRole: role,
      ));
    } else {
      await _open(LedgerHomeScreen(services: widget.services, ledger: ledger));
    }
  }

  /// 초대 링크(onehouse-budget://join?code=…)로 열리면 참여 화면에 코드를 채워서 띄운다.
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
    _pendingInviteCode = code;
    // 앱이 막 켜진 경우엔 목록을 불러온 뒤 _load에서 연다
    if (_ledgers != null || _error != null) _openPendingInvite();
  }

  void _openPendingInvite() {
    final code = _pendingInviteCode;
    if (code == null) return;
    _pendingInviteCode = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 다른 화면이 열려 있으면 목록으로 돌아온 뒤 연다
      Navigator.of(context).popUntil((route) => route.isFirst);
      _open(JoinScreen(services: widget.services, initialCode: code));
    });
  }

  Future<void> _load({bool retried = false}) async {
    try {
      final res = await widget.services.api.get('/ledgers');
      final items = (res['ledgers'] as List<dynamic>)
          .map((e) => LedgerSummary.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _ledgers = items;
        _error = null;
      });
      // 앱이 꺼져 있다가 알림을 눌러 켜진 경우
      final pending = Push.takePendingOpen();
      if (pending != null) WidgetsBinding.instance.addPostFrameCallback((_) => _openFromPush(pending));
      // 앱이 꺼져 있다가 초대 링크로 켜진 경우
      _openPendingInvite();
      // 가계부가 생긴 뒤에 알림 권한을 묻는다 (처음 켜자마자 묻지 않게)
      if (items.isNotEmpty && !_pushRegistered) {
        _pushRegistered = true;
        Push.register(widget.services.api);
      }
    } on ApiException catch (e) {
      // 다른 기기로 이전된 토큰이면 새 기기 계정으로 다시 시작
      if (e.isUnauthorized && !retried) {
        await widget.services.session.reset();
        return _load(retried: true);
      }
      if (!mounted) return;
      setState(() => _error = e.message);
      _openPendingInvite();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is OfflineException ? e.message : '목록을 불러오지 못했어요.');
      _openPendingInvite();
    }
  }

  Future<void> _open(Widget screen) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => screen),
    );
    if (changed == true) await _load();
  }

  Future<void> _cancelRequest(LedgerSummary ledger) async {
    try {
      await widget.services.api.post('/ledgers/${ledger.id}/cancel-request');
      await _load();
    } catch (e) {
      if (!mounted) return;
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledgers = _ledgers;
    final services = widget.services;

    if (ledgers == null) {
      return Scaffold(
        body: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : TextButton(onPressed: _load, child: Text('$_error\n다시 시도', textAlign: TextAlign.center)),
        ),
      );
    }

    if (ledgers.isEmpty) {
      return StartView(
        space: services.space,
        privacyUrl: privacyUrl(services.api),
        onCreate: () => _open(CreateSpaceScreen(services: services)),
        onJoin: () => _open(JoinScreen(services: services)),
        onTransfer: () => _open(TransferInScreen(services: services)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 가계부'),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: ledgers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final ledger = ledgers[i];
            return ledger.isPending
                ? PendingCard(
                    summary: ledger.toSpaceSummary(),
                    onRefresh: _load,
                    onCancel: () => _cancelRequest(ledger),
                  )
                : _LedgerCard(
                    ledger: ledger,
                    onTap: () => _open(LedgerHomeScreen(services: services, ledger: ledger)),
                  );
          },
        ),
      ),
      // 버튼 아래에 광고 배너 (아래 안전 영역은 배너가 챙긴다)
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _open(JoinScreen(services: services)),
                    child: const Text('코드로 참여'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _open(CreateSpaceScreen(services: services)),
                    child: const Text('새 가계부'),
                  ),
                ),
              ],
            ),
          ),
          const AdBanner(),
        ],
      ),
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.ledger, required this.onTap});

  final LedgerSummary ledger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final role = ledger.role;
    final pending = ledger.pendingCount ?? 0;
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
                      ledger.name,
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
                      '멤버 ${ledger.memberCount ?? 0}명${pending > 0 ? ' · 요청 $pending건' : ''}',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('이번 달 지출', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      Text(
                        won(ledger.monthExpense ?? 0),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
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
