import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

import '../api/budget_api.dart';
import '../models/category.dart';
import '../models/ledger_summary.dart';
import '../models/transaction.dart';
import '../utils/format.dart';
import '../widgets/ad_banner.dart';
import '../widgets/category_widgets.dart';
import '../widgets/filter_bar.dart';
import 'categories_screen.dart';
import 'filter_screen.dart';
import 'transaction_edit_screen.dart';

/// 월별 내역: 목록·달력 보기, 카테고리 필터, 내역 추가·고치기
class LedgerHomeScreen extends StatefulWidget {
  const LedgerHomeScreen({super.key, required this.services, required this.ledger});

  final AppServices services;
  final LedgerSummary ledger;

  @override
  State<LedgerHomeScreen> createState() => _LedgerHomeScreenState();
}

class _LedgerHomeScreenState extends State<LedgerHomeScreen> {
  late final BudgetApi _api = BudgetApi(widget.services.api, widget.ledger.id);

  late String _name = widget.ledger.name;
  late String _nickname = widget.ledger.nickname;
  late SpaceRole? _role = widget.ledger.role;
  List<Category> _categories = const [];

  String _month = currentMonth();
  bool _calendar = false;
  FilterSelection _filter = const FilterSelection();
  DateTime? _selectedDay = todayKst();

  MonthData? _data;
  String? _error;
  int _loadSeq = 0;
  bool _changed = false;

  bool get _manager => isManager(_role);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([_api.detail(), _api.categories()]);
      if (!mounted) return;
      final detail = results[0] as Map<String, dynamic>;
      final member = detail['member'] as Map<String, dynamic>;
      setState(() {
        _name = detail['name'] as String;
        _nickname = member['nickname'] as String;
        _role = parseRole(member['role'] as String?);
        _categories = results[1] as List<Category>;
        _filter = _filter.prune(_categories);
      });
    } catch (e) {
      if (_handleGone(e)) return;
    }
    await _loadMonth();
  }

  Future<void> _loadMonth() async {
    final seq = ++_loadSeq;
    try {
      final data = await _api.month(
        _month,
        categoryIds: _filter.categoryIds,
        uncategorized: _filter.uncategorized,
      );
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } catch (e) {
      if (!mounted || seq != _loadSeq) return;
      if (_handleGone(e)) return;
      setState(() => _error = errorMessage(e));
    }
  }

  /// 차단됐거나 지워진 가계부면 목록으로
  bool _handleGone(Object e) {
    if (e is ApiException && (e.isForbidden || e.status == 404)) {
      if (mounted) {
        showMessage(context, '이 가계부에 더 이상 접근할 수 없어요.');
        Navigator.of(context).pop(true);
      }
      return true;
    }
    return false;
  }

  void _moveMonth(int delta) {
    setState(() {
      _month = addMonths(_month, delta);
      _data = null;
      final today = todayKst();
      _selectedDay = monthKey(today) == _month ? today : null;
    });
    _loadMonth();
  }

  void _applyFilter(FilterSelection next) {
    setState(() {
      _filter = next;
      _data = null;
    });
    _loadMonth();
  }

  Future<void> _openFilter() async {
    final next = await Navigator.of(context).push<FilterSelection>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FilterScreen(categories: _categories, initial: _filter),
      ),
    );
    if (next != null) _applyFilter(next);
  }

  Future<void> _edit({Txn? existing}) async {
    DateTime? initial;
    if (existing == null) {
      final today = todayKst();
      initial = (_calendar ? _selectedDay : null) ?? (monthKey(today) == _month ? today : parseDate('$_month-01'));
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TransactionEditScreen(
          api: _api,
          categories: _categories,
          canManageCategories: _manager,
          myNickname: _nickname,
          existing: existing,
          initialDate: initial,
        ),
      ),
    );
    if (saved == true) {
      _changed = true;
      await _loadAll();
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SpaceSettingsScreen(
          services: widget.services,
          spaceId: widget.ledger.id,
          extraTiles: (context, role, markChanged) => [
            if (isManager(role))
              ListTile(
                leading: const Icon(Icons.sell_outlined),
                title: const Text('카테고리 관리'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => CategoriesScreen(api: _api)),
                  );
                  if (changed == true) markChanged();
                },
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      Navigator.of(context).pop(true);
      return;
    }
    _changed = true;
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_name),
          actions: [
            IconButton(tooltip: '가계부 설정', icon: const Icon(Icons.menu), onPressed: _openSettings),
          ],
        ),
        bottomNavigationBar: const AdBanner(),
        floatingActionButton: FloatingActionButton(
          tooltip: '내역 추가',
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          onPressed: () => _edit(),
          child: const Icon(Icons.add),
        ),
        body: RefreshIndicator(
          onRefresh: _loadAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              _MonthBar(
                month: _month,
                calendar: _calendar,
                onPrev: () => _moveMonth(-1),
                onNext: () => _moveMonth(1),
                onView: (v) => setState(() => _calendar = v),
              ),
              const SizedBox(height: 4),
              FilterBar(
                selection: _filter,
                categories: _categories,
                onOpen: _openFilter,
                onRemove: (id) => _applyFilter(_filter.without(id)),
              ),
              const SizedBox(height: 12),
              if (data == null && _error == null)
                const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator())),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: TextButton(onPressed: _loadMonth, child: Text('$_error\n다시 시도', textAlign: TextAlign.center)),
                  ),
                ),
              if (data != null) ...[
                _SummaryCard(data: data, filtered: !_filter.isEmpty, current: _month == currentMonth()),
                const SizedBox(height: 16),
                if (_calendar) ..._calendarView(data) else ..._listView(data),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _listView(MonthData data) {
    if (data.items.isEmpty) {
      return [
        _Empty(
          text: _filter.isEmpty ? '${monthLabel(_month)} 내역이 없어요' : '고른 카테고리의 내역이 없어요',
          sub: _filter.isEmpty ? '오른쪽 아래 + 버튼으로 첫 내역을 남겨 보세요' : null,
        ),
      ];
    }
    return [
      for (final (day, items) in data.byDay()) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text(dayHeading(day),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        ),
        _TxnGroup(items: items, onTap: (t) => _edit(existing: t)),
        const SizedBox(height: 12),
      ],
    ];
  }

  List<Widget> _calendarView(MonthData data) {
    final selected = _selectedDay;
    final dayItems = selected == null ? const <Txn>[] : data.items.where((t) => t.spentAt == selected).toList();
    return [
      _CalendarGrid(
        month: _month,
        totals: data.dailyTotals(),
        selected: selected,
        today: todayKst(),
        onSelect: (d) => setState(() => _selectedDay = d),
      ),
      const SizedBox(height: 16),
      if (selected == null)
        const _Empty(text: '날짜를 누르면 그날 내역이 보여요')
      else ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(dayHeading(selected),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        ),
        if (dayItems.isEmpty)
          const _Empty(text: '이날 내역이 없어요', compact: true)
        else
          _TxnGroup(items: dayItems, onTap: (t) => _edit(existing: t)),
      ],
    ];
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.calendar,
    required this.onPrev,
    required this.onNext,
    required this.onView,
  });

  final String month;
  final bool calendar;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<bool> onView;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool value) {
      final selected = calendar == value;
      return Semantics(
        selected: selected,
        button: true,
        label: '$label 보기',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => onView(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow:
                  selected ? const [BoxShadow(color: Color(0x1F191C1F), blurRadius: 2, offset: Offset(0, 1))] : null,
            ),
            child: Text(label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.text : AppColors.textSecondary,
                )),
          ),
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(tooltip: '이전 달', onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
          Text(monthLabel(month), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          IconButton(tooltip: '다음 달', onPressed: onNext, icon: const Icon(Icons.chevron_right)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: const Color(0xFFE7E9ED), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [seg('목록', false), seg('달력', true)]),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data, required this.filtered, required this.current});

  final MonthData data;
  final bool filtered;

  /// 이번 달이면 "이번 달 남은 돈", 아니면 "10월 남은 돈"
  final bool current;

  @override
  Widget build(BuildContext context) {
    final balance = data.income - data.expense;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(filtered ? '필터 합계' : (current ? '이번 달 남은 돈' : '${int.parse(data.month.substring(5))}월 남은 돈'),
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(won(balance), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
          const Divider(height: 28, color: AppColors.divider),
          Row(
            children: [
              Expanded(child: _Cell(label: '수입', value: won(data.income), color: AppColors.income)),
              Expanded(child: _Cell(label: '지출', value: won(data.expense), color: AppColors.text)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        ],
      );
}

class _TxnGroup extends StatelessWidget {
  const _TxnGroup({required this.items, required this.onTap});

  final List<Txn> items;
  final ValueChanged<Txn> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 68, color: Color(0xFFF0F1F3)),
            _TxnTile(txn: items[i], onTap: () => onTap(items[i])),
          ],
        ],
      ),
    );
  }
}

class _TxnTile extends StatelessWidget {
  const _TxnTile({required this.txn, required this.onTap});

  final Txn txn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CategoryBadge(name: txn.categoryName, type: txn.categoryType),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txn.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(txn.memberNickname, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              won(txn.signed, signed: true),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: txn.isIncome ? AppColors.income : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.totals,
    required this.selected,
    required this.today,
    required this.onSelect,
  });

  final String month;
  final Map<int, (int, int)> totals;
  final DateTime? selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final first = parseDate('$month-01');
    final days = DateTime(first.year, first.month + 1, 0).day;
    final offset = first.weekday % 7; // 일요일 시작
    final cells = offset + days;
    final rows = (cells / 7).ceil();
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      weekdays[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: i == 0 ? AppColors.danger : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Builder(builder: (context) {
                      final n = r * 7 + c - offset + 1;
                      if (n < 1 || n > days) return const SizedBox(height: 56);
                      final date = DateTime(first.year, first.month, n);
                      final (income, expense) = totals[n] ?? (0, 0);
                      final isSelected = selected == date;
                      final isToday = today == date;
                      final fg = isSelected ? Colors.white : AppColors.text;
                      return Semantics(
                        button: true,
                        selected: isSelected,
                        label: '$n일${expense > 0 ? ' 지출 ${won(expense)}' : ''}${income > 0 ? ' 수입 ${won(income)}' : ''}',
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTap: () => onSelect(date),
                          child: Container(
                            height: 56,
                            margin: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              color: isSelected ? primary : null,
                              borderRadius: BorderRadius.circular(10),
                              border: isToday && !isSelected ? Border.all(color: primary.withValues(alpha: 0.5)) : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('$n', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
                                if (expense > 0)
                                  Text(
                                    compactWon(expense),
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected ? Colors.white : AppColors.commonFg,
                                    ),
                                  ),
                                if (income > 0)
                                  Text(
                                    '+${compactWon(income)}',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? Colors.white : AppColors.income,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, this.sub, this.compact = false});

  final String text;
  final String? sub;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(vertical: compact ? 24 : 40, horizontal: 20),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
            if (sub != null) ...[
              const SizedBox(height: 6),
              Text(sub!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ],
        ),
      );
}
