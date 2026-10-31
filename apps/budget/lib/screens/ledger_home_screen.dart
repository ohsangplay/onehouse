import 'package:flutter/material.dart';

import 'package:onehouse_core/onehouse_core.dart';

import '../models/ledger_summary.dart';
import '../theme.dart';
import '../utils/format.dart';

/// 월별 내역 (목록 보기). 달력·필터·내역 작성은 다음 단계에서 붙인다.
class LedgerHomeScreen extends StatefulWidget {
  const LedgerHomeScreen({super.key, required this.services, required this.ledger});

  final AppServices services;
  final LedgerSummary ledger;

  @override
  State<LedgerHomeScreen> createState() => _LedgerHomeScreenState();
}

class _LedgerHomeScreenState extends State<LedgerHomeScreen> {
  late String _month = currentMonth();
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await widget.services.api.get('/ledgers/${widget.ledger.id}/transactions?month=$_month');
      if (!mounted) return;
      setState(() {
        _data = res;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isForbidden) {
        // 차단됐거나 나간 가계부
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이 가계부에 더 이상 접근할 수 없어요.')),
        );
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SpaceSettingsScreen(services: widget.services, spaceId: widget.ledger.id)),
    );
    // 나갔거나 삭제했으면 목록으로
    if (result == true && mounted) Navigator.of(context).pop(true);
  }

  void _moveMonth(int delta) {
    final parts = _month.split('-').map(int.parse).toList();
    final d = DateTime(parts[0], parts[1] + delta);
    setState(() {
      _month = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      _data = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final summary = data?['summary'] as Map<String, dynamic>?;
    final income = summary?['income'] as int? ?? 0;
    final expense = summary?['expense'] as int? ?? 0;
    final items = (data?['transactions'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final parts = _month.split('-');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ledger.name),
        actions: [
          IconButton(tooltip: '가계부 설정', onPressed: _openSettings, icon: const Icon(Icons.settings_outlined)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: BudgetColors.primary,
        foregroundColor: Colors.white,
        tooltip: '내역 추가',
        onPressed: () {
          // TODO: 내역 작성 화면 (POST /ledgers/:id/transactions)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('내역 작성 화면은 다음 단계에서 붙여요.')),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '이전 달',
                  onPressed: () => _moveMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${parts[0]}년 ${int.parse(parts[1])}월',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  tooltip: '다음 달',
                  onPressed: () => _moveMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('이번 달 남은 돈', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  Text(won(income - expense), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  const Divider(height: 28, color: AppColors.divider),
                  Row(
                    children: [
                      Expanded(child: _SummaryCell(label: '수입', value: won(income), color: AppColors.income)),
                      Expanded(child: _SummaryCell(label: '지출', value: won(expense), color: AppColors.text)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (data == null && _error == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null) Center(child: Text(_error!)),
            if (data != null && items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('이번 달 내역이 없어요', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            for (final tx in items) _TransactionTile(tx: tx),
          ],
        ),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx});

  final Map<String, dynamic> tx;

  @override
  Widget build(BuildContext context) {
    final isIncome = tx['type'] == 'income';
    final amount = tx['amount'] as int;
    final categoryName = tx['category_name'] as String? ?? '미분류';
    final (fg, bg) = switch (tx['category_type'] as String?) {
      'expense' => (AppColors.expenseFg, AppColors.expenseBg),
      'income' => (AppColors.incomeFg, AppColors.incomeBg),
      _ => (AppColors.commonFg, AppColors.commonBg),
    };
    final memo = tx['memo'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Text(
              categoryName.length > 2 ? categoryName.substring(0, 2) : categoryName,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memo == null || memo.isEmpty ? categoryName : memo,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${tx['spent_at']} · ${tx['member_nickname']}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            won(isIncome ? amount : -amount, signed: true),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isIncome ? AppColors.income : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
