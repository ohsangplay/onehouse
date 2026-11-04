import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

import '../models/category.dart';
import '../widgets/category_widgets.dart';
import '../widgets/filter_bar.dart';

/// 카테고리 필터 (전체 화면). 적용하면 고른 필터를 돌려준다.
class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key, required this.categories, required this.initial});

  final List<Category> categories;
  final FilterSelection initial;

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late final Set<String> _ids = {...widget.initial.categoryIds};
  late bool _uncategorized = widget.initial.uncategorized;

  int get _count => _ids.length + (_uncategorized ? 1 : 0);

  void _toggle(String id) => setState(() => _ids.contains(id) ? _ids.remove(id) : _ids.add(id));

  Widget _section(CategoryType type, String? note) {
    final items = widget.categories.where((c) => c.type == type).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TypeDot(type, size: 10),
              const SizedBox(width: 8),
              Text(type.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (note != null) ...[
                const SizedBox(width: 8),
                Text(note, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in items)
                CategoryChoiceChip(
                  label: c.name,
                  type: type,
                  selected: _ids.contains(c.id),
                  showCheck: true,
                  onTap: () => _toggle(c.id),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          tooltip: '닫기',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('카테고리 필터'),
        actions: [
          TextButton(
            onPressed: _count == 0
                ? null
                : () => setState(() {
                      _ids.clear();
                      _uncategorized = false;
                    }),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('초기화', style: TextStyle(fontSize: 15)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text('여러 개를 함께 고를 수 있어요', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ),
          _section(CategoryType.common, '지출·수입 모두'),
          _section(CategoryType.expense, null),
          _section(CategoryType.income, null),
          Row(
            children: [
              const Text('기타', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('카테고리를 지운 내역', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: CategoryChoiceChip(
              label: '미분류',
              type: CategoryType.common,
              selected: _uncategorized,
              showCheck: true,
              onTap: () => setState(() => _uncategorized = !_uncategorized),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(
              FilterSelection(categoryIds: {..._ids}, uncategorized: _uncategorized),
            ),
            child: Text(_count == 0 ? '전체 보기' : '필터 $_count개 적용'),
          ),
        ),
      ),
    );
  }
}
