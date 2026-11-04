import 'package:flutter/material.dart';

import 'package:onehouse_core/onehouse_core.dart';

import '../models/ledger_summary.dart';
import '../utils/format.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
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
    } on ApiException catch (e) {
      // 다른 기기로 이전된 토큰이면 새 기기 계정으로 다시 시작
      if (e.isUnauthorized && !retried) {
        await widget.services.session.reset();
        return _load(retried: true);
      }
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is OfflineException ? e.message : '목록을 불러오지 못했어요.');
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
