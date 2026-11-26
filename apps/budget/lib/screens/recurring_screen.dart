import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

import '../api/budget_api.dart';
import '../models/category.dart';
import '../models/recurring.dart';
import '../utils/format.dart';
import 'transaction_edit_screen.dart';

/// 고정 지출·수입과 할부 관리. 바뀐 게 있으면 true를 돌려준다.
class RecurringScreen extends StatefulWidget {
  const RecurringScreen({
    super.key,
    required this.api,
    required this.categories,
    required this.canManageCategories,
    required this.myNickname,
    required this.myMemberId,
    required this.isManager,
  });

  final BudgetApi api;
  final List<Category> categories;
  final bool canManageCategories;
  final String myNickname;
  final String? myMemberId;
  final bool isManager;

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  List<RecurringRule>? _rules;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rules = await widget.api.recurring();
      if (!mounted) return;
      setState(() {
        _rules = rules;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  bool _canEdit(RecurringRule r) => widget.isManager || r.memberId == widget.myMemberId;

  Future<void> _add() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TransactionEditScreen(
          api: widget.api,
          categories: widget.categories,
          canManageCategories: widget.canManageCategories,
          myNickname: widget.myNickname,
          initialRepeat: EntryRepeat.monthly,
        ),
      ),
    );
    if (saved == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _open(RecurringRule r) async {
    if (!_canEdit(r)) {
      showMessage(context, '만든 사람(${r.memberNickname})이나 방장·부방장만 바꿀 수 있어요');
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(_subtitle(r)),
            ),
            const Divider(height: 1),
            if (!r.installment)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('금액·날짜 바꾸기'),
                subtitle: const Text('다음 회차부터 바뀌어요'),
                onTap: () => Navigator.of(context).pop('edit'),
              ),
            ListTile(
              leading: const Icon(Icons.short_text),
              title: const Text('메모 바꾸기'),
              onTap: () => Navigator.of(context).pop('memo'),
            ),
            ListTile(
              leading: const Icon(Icons.stop_circle_outlined, color: AppColors.danger),
              title: Text(r.installment ? '할부 지우기' : '그만하기', style: const TextStyle(color: AppColors.danger)),
              subtitle: const Text('지금까지 기록된 내역은 남아요'),
              onTap: () => Navigator.of(context).pop('stop'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    try {
      switch (action) {
        case 'edit':
          final result = await showDialog<(int, int)>(
            context: context,
            builder: (_) => _FixedEditDialog(rule: r),
          );
          if (result == null) return;
          await widget.api.updateRecurring(r.id, {'amount': result.$1, 'day': result.$2});
        case 'memo':
          final memo = await promptText(context, title: '메모', initial: r.memo ?? '', maxLength: 100);
          if (memo == null) return;
          await widget.api.updateRecurring(r.id, {'memo': memo.trim().isEmpty ? null : memo.trim()});
        case 'stop':
          final ok = await confirmDialog(
            context,
            title: r.installment ? '"${r.title}" 할부를 지울까요?' : '"${r.title}"을(를) 그만할까요?',
            message: '앞으로 자동으로 기록하지 않아요. 지금까지 기록된 내역은 가계부에 그대로 남고, 필요하면 하나씩 지울 수 있어요.',
            action: r.installment ? '지우기' : '그만하기',
            danger: true,
          );
          if (!ok) return;
          await widget.api.deleteRecurring(r.id);
      }
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  String _subtitle(RecurringRule r) {
    final parts = <String>[];
    if (r.installment) {
      parts.add('매월 ${r.day}일 · ${comma(r.perMonth)}원 × ${r.months}개월');
      parts.add('${r.done}/${r.months}회 기록');
      if ((r.remainingAmount ?? 0) > 0) parts.add('남은 금액 ${comma(r.remainingAmount!)}원');
    } else {
      parts.add('매월 ${r.day}일');
    }
    if (r.finished) {
      parts.add('끝남');
    } else if (r.nextDate != null) {
      parts.add('다음 ${r.nextDate!.month}/${r.nextDate!.day}');
    }
    parts.add(r.memberNickname);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final rules = _rules;
    final fixed = rules?.where((r) => !r.installment).toList() ?? const <RecurringRule>[];
    final installments = rules?.where((r) => r.installment).toList() ?? const <RecurringRule>[];
    final monthlyIncome = fixed.where((r) => r.isIncome).fold<int>(0, (s, r) => s + r.amount);
    final monthlyExpense = fixed.where((r) => !r.isIncome).fold<int>(0, (s, r) => s + r.amount) +
        installments.where((r) => !r.finished).fold<int>(0, (s, r) => s + r.perMonth);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('고정·할부 관리')),
        body: rules == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : TextButton(onPressed: _load, child: Text('$_error\n다시 시도', textAlign: TextAlign.center)),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          Expanded(child: _Total(label: '매월 고정 수입', value: monthlyIncome, color: AppColors.income)),
                          Expanded(child: _Total(label: '매월 고정 지출·할부', value: monthlyExpense, color: AppColors.text)),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 12, 4, 4),
                      child: Text(
                        '정한 날이 되면 가계부에 자동으로 기록돼요. 기록된 내역은 하나씩 고치거나 지울 수 있어요.',
                        style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
                      ),
                    ),
                    _Section(title: '매월 고정', empty: '월급, 관리비, 통신비처럼 매달 같은 금액을 넣어 두세요', rules: fixed, subtitle: _subtitle, onTap: _open),
                    _Section(title: '할부', empty: '내역 추가에서 \'할부\'를 고르면 여기에 모여요', rules: installments, subtitle: _subtitle, onTap: _open),
                  ],
                ),
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: FilledButton.icon(
              onPressed: rules == null ? null : _add,
              icon: const Icon(Icons.add),
              label: const Text('고정·할부 추가'),
            ),
          ),
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text('${comma(value)}원', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        ],
      );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.empty,
    required this.rules,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String empty;
  final List<RecurringRule> rules;
  final String Function(RecurringRule) subtitle;
  final void Function(RecurringRule) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
          child: rules.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(empty, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                )
              : Column(
                  children: [
                    for (var i = 0; i < rules.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 16, color: AppColors.divider),
                      ListTile(
                        title: Text(rules[i].title, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(subtitle(rules[i]), style: const TextStyle(fontSize: 13)),
                        trailing: Text(
                          '${rules[i].isIncome ? '+' : '-'}${comma(rules[i].perMonth)}원',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: rules[i].isIncome ? AppColors.income : AppColors.text,
                          ),
                        ),
                        onTap: () => onTap(rules[i]),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// 고정 금액·날짜 바꾸기
class _FixedEditDialog extends StatefulWidget {
  const _FixedEditDialog({required this.rule});

  final RecurringRule rule;

  @override
  State<_FixedEditDialog> createState() => _FixedEditDialogState();
}

class _FixedEditDialogState extends State<_FixedEditDialog> {
  late final _amount = TextEditingController(text: comma(widget.rule.amount));
  late int _day = widget.rule.day;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = parseAmount(_amount.text);
    return AlertDialog(
      title: const Text('금액·날짜 바꾸기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [AmountFormatter()],
            decoration: const InputDecoration(labelText: '매월 금액', suffixText: '원'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('매월'),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _day,
                items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d일'))],
                onChanged: (d) => setState(() => _day = d ?? _day),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
        FilledButton(
          onPressed: amount > 0 ? () => Navigator.of(context).pop((amount, _day)) : null,
          child: const Text('저장'),
        ),
      ],
    );
  }
}
