import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/ledger_summary.dart';
import '../services/app_services.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'create_ledger_screen.dart';
import 'join_screen.dart';
import 'ledger_home_screen.dart';
import 'start_view.dart';
import 'transfer_in_screen.dart';

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
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '목록을 불러오지 못했어요.');
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
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
        onCreate: () => _open(CreateLedgerScreen(services: services)),
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
                ? _PendingCard(
                    ledger: ledger,
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                  onPressed: () => _open(CreateLedgerScreen(services: services)),
                  child: const Text('새 가계부'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge(this.role);

  final LedgerRole role;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (role) {
      LedgerRole.owner => (AppColors.primary, const Color(0xFFE3F0EB)),
      LedgerRole.coOwner => (AppColors.income, AppColors.incomeBg),
      LedgerRole.member => (AppColors.commonFg, AppColors.commonBg),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        roleLabel(role),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
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
                  if (role != null) ...[const SizedBox(width: 8), _RoleBadge(role)],
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

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.ledger, required this.onRefresh, required this.onCancel});

  final LedgerSummary ledger;
  final VoidCallback onRefresh;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7CCD2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  ledger.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.expenseBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '승인 대기',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.expenseFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '방장 승인을 기다리고 있어요. 승인되면 여기서 바로 열 수 있어요.',
            style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: onRefresh,
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                child: const Text('새로고침', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: AppColors.textSecondary,
                ),
                child: const Text('요청 취소', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
