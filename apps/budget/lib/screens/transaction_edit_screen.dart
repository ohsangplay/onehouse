import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onehouse_core/onehouse_core.dart';

import '../api/budget_api.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../utils/format.dart';
import '../widgets/category_widgets.dart';

/// 금액 입력: 숫자만, 천 단위 쉼표
class AmountFormatter extends TextInputFormatter {
  static const maxAmount = 999999999999;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final value = int.tryParse(digits);
    if (value == null || value > maxAmount) return oldValue;
    final text = comma(value);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// 내역 쓰기·고치기. 저장하거나 지우면 true를 돌려준다.
class TransactionEditScreen extends StatefulWidget {
  const TransactionEditScreen({
    super.key,
    required this.api,
    required this.categories,
    required this.canManageCategories,
    required this.myNickname,
    this.existing,
    this.initialDate,
  });

  final BudgetApi api;
  final List<Category> categories;
  final bool canManageCategories;
  final String myNickname;
  final Txn? existing;
  final DateTime? initialDate;

  @override
  State<TransactionEditScreen> createState() => _TransactionEditScreenState();
}

class _TransactionEditScreenState extends State<TransactionEditScreen> {
  late final List<Category> _categories = [...widget.categories];
  late bool _income = widget.existing?.isIncome ?? false;
  late String? _categoryId = widget.existing?.categoryId;
  late DateTime _date = widget.existing?.spentAt ?? widget.initialDate ?? todayKst();
  late final _amount = TextEditingController(
    text: widget.existing == null ? '' : comma(widget.existing!.amount),
  );
  late final _memo = TextEditingController(text: widget.existing?.memo ?? '');
  bool _busy = false;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _amount.dispose();
    _memo.dispose();
    super.dispose();
  }

  void _setIncome(bool income) {
    setState(() {
      _income = income;
      final current = _categories.where((c) => c.id == _categoryId).firstOrNull;
      if (current != null && !current.usableFor(income)) _categoryId = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _addCategory() async {
    final created = await showAddCategorySheet(
      context,
      api: widget.api,
      initialType: _income ? CategoryType.income : CategoryType.expense,
    );
    if (created == null || !mounted) return;
    setState(() {
      _categories.add(created);
      if (created.usableFor(_income)) _categoryId = created.id;
    });
    showMessage(context, '${created.type.label} 카테고리 "${created.name}"을(를) 추가했어요');
  }

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    if (amount <= 0) return;
    setState(() => _busy = true);
    final memo = _memo.text.trim();
    final body = <String, dynamic>{
      'type': _income ? 'income' : 'expense',
      'amount': amount,
      'spent_at': dateKey(_date),
      'category_id': _categoryId,
      'memo': memo.isEmpty ? null : memo,
    };
    try {
      if (_editing) {
        await widget.api.updateTxn(widget.existing!.id, body);
      } else {
        await widget.api.createTxn(body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: '이 내역을 지울까요?',
      message: '가계부를 함께 쓰는 모든 사람에게서 사라져요.',
      action: '지우기',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.deleteTxn(widget.existing!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final usable = _categories.where((c) => c.usableFor(_income)).toList();
    final valid = parseAmount(_amount.text) > 0;
    final author = widget.existing?.memberNickname ?? widget.myNickname;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          tooltip: '닫기',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_editing ? '내역 고치기' : '내역 추가'),
        actions: [
          if (_editing)
            IconButton(
              tooltip: '내역 지우기',
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _TypeToggle(income: _income, onChanged: _setIncome),
          const SizedBox(height: 28),
          const Text('금액', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          TextField(
            controller: _amount,
            autofocus: !_editing,
            keyboardType: TextInputType.number,
            inputFormatters: [AmountFormatter()],
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: _income ? AppColors.income : AppColors.text,
            ),
            decoration: InputDecoration(
              hintText: '0',
              suffixText: '원',
              suffixStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text),
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: const UnderlineInputBorder(),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border, width: 2)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primary, width: 2)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 28),
          const Text('카테고리',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in usable)
                CategoryChoiceChip(
                  label: c.name,
                  type: c.type,
                  selected: c.id == _categoryId,
                  onTap: () => setState(() => _categoryId = c.id == _categoryId ? null : c.id),
                ),
              if (widget.canManageCategories)
                ActionChip(
                  avatar: Icon(Icons.add, size: 16, color: primary),
                  label: Text('추가', style: TextStyle(fontSize: 15, color: primary, fontWeight: FontWeight.w500)),
                  shape: StadiumBorder(side: BorderSide(color: primary)),
                  backgroundColor: AppColors.surface,
                  onPressed: _addCategory,
                ),
            ],
          ),
          if (usable.isEmpty && !widget.canManageCategories)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('카테고리는 방장·부방장이 추가할 수 있어요',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: AppColors.divider),
          _Row(
            label: '날짜',
            child: TextButton(
              onPressed: _pickDate,
              style: TextButton.styleFrom(foregroundColor: AppColors.text, padding: EdgeInsets.zero),
              child: Text(dateLabel(_date), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          _Row(
            label: '메모',
            child: Expanded(
              child: TextField(
                controller: _memo,
                maxLength: 100,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                decoration: const InputDecoration(
                  hintText: '예) 마트 장보기',
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          _Row(
            label: '작성자',
            child: Text(author, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton(
            onPressed: valid && !_busy ? _save : null,
            child: Text(_busy ? '저장하는 중…' : '저장'),
          ),
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.income, required this.onChanged});

  final bool income;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool value, Color color) {
      final selected = income == value;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: GestureDetector(
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow:
                    selected ? const [BoxShadow(color: Color(0x1F191C1F), blurRadius: 2, offset: Offset(0, 1))] : null,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFEEF0F3), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [tab('지출', false, AppColors.text), tab('수입', true, AppColors.income)]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(label, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
            ),
            if (child is Expanded) child else ...[const Spacer(), child],
          ],
        ),
      );
}
