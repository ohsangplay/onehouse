import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

import '../api/budget_api.dart';
import '../models/category.dart';

/// 내역 목록 왼쪽의 카테고리 상자 (종류 색)
class CategoryBadge extends StatelessWidget {
  const CategoryBadge({super.key, required this.name, required this.type});

  final String? name;
  final CategoryType? type;

  @override
  Widget build(BuildContext context) {
    final label = name ?? '미분류';
    final t = type ?? CategoryType.common;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label.characters.take(2).toString(),
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.fg),
      ),
    );
  }
}

/// 종류 점 + 이름 (공통 / 지출 / 수입)
class TypeDot extends StatelessWidget {
  const TypeDot(this.type, {super.key, this.size = 8});

  final CategoryType type;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: type.dot, shape: BoxShape.circle),
      );
}

/// 고르는 칩 (내역 작성·필터 화면). 고르면 종류 색으로 채워진다.
class CategoryChoiceChip extends StatelessWidget {
  const CategoryChoiceChip({
    super.key,
    required this.label,
    required this.type,
    required this.selected,
    required this.onTap,
    this.showCheck = false,
  });

  final String label;
  final CategoryType type;
  final bool selected;
  final VoidCallback onTap;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    final tinted = type != CategoryType.common;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? type.bg : (tinted ? type.bg.withValues(alpha: 0.35) : AppColors.surface),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? type.dot : (tinted ? type.dot.withValues(alpha: 0.35) : AppColors.border),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: EdgeInsets.fromLTRB(showCheck && selected ? 10 : 14, 8, 14, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showCheck && selected) ...[
                  Icon(Icons.check, size: 16, color: type.fg),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected || tinted ? type.fg : AppColors.text,
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

/// 공통 / 지출 / 수입 고르는 3칸 버튼
class CategoryTypeSelector extends StatelessWidget {
  const CategoryTypeSelector({super.key, required this.value, required this.onChanged, this.counts});

  final CategoryType value;
  final ValueChanged<CategoryType> onChanged;

  /// 탭에 개수를 붙일 때
  final Map<CategoryType, int>? counts;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFE7E9ED), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          for (final t in CategoryType.values)
            Expanded(
              child: Semantics(
                selected: t == value,
                button: true,
                child: GestureDetector(
                  onTap: () => onChanged(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 42,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: t == value ? AppColors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: t == value
                          ? const [BoxShadow(color: Color(0x1F191C1F), blurRadius: 2, offset: Offset(0, 1))]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TypeDot(t),
                        const SizedBox(width: 6),
                        Text(
                          counts == null ? t.label : '${t.label} ${counts![t] ?? 0}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: t == value ? FontWeight.w700 : FontWeight.w500,
                            color: t == value ? t.fg : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 카테고리 추가 시트. 만든 카테고리를 돌려준다.
Future<Category?> showAddCategorySheet(
  BuildContext context, {
  required BudgetApi api,
  CategoryType initialType = CategoryType.expense,
}) {
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) => _AddCategorySheet(api: api, initialType: initialType),
  );
}

class _AddCategorySheet extends StatefulWidget {
  const _AddCategorySheet({required this.api, required this.initialType});

  final BudgetApi api;
  final CategoryType initialType;

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  late CategoryType _type = widget.initialType;
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final created = await widget.api.addCategory(_type, _name.text.trim());
      if (mounted) Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _name.text.trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('카테고리 추가', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          const Text('종류', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          CategoryTypeSelector(value: _type, onChanged: (t) => setState(() => _type = t)),
          const SizedBox(height: 8),
          Text(_type.usage, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          const Text('이름', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            autofocus: true,
            maxLength: 10,
            decoration: const InputDecoration(hintText: '예) 구독료', counterText: ''),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => name.isEmpty || _busy ? null : _submit(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Expanded(
                  child: Text('라벨 미리보기', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ),
                FilterLabel(label: name.isEmpty ? '이름' : name, type: _type),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: name.isEmpty || _busy ? null : _submit,
            child: Text(_busy ? '추가하는 중…' : '추가'),
          ),
        ],
      ),
    );
  }
}

/// 적용된 필터 라벨 (종류 색, ×로 빼기)
class FilterLabel extends StatelessWidget {
  const FilterLabel({super.key, required this.label, required this.type, this.onRemove});

  final String label;
  final CategoryType type;
  final VoidCallback? onRemove;

  static const height = 32.0;
  static const textStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w500);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: EdgeInsets.only(left: 12, right: onRemove == null ? 12 : 0),
      decoration: BoxDecoration(color: type.bg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: textStyle.copyWith(color: type.fg)),
          if (onRemove != null)
            SizedBox(
              width: 30,
              height: height,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 15,
                tooltip: '$label 필터 빼기',
                onPressed: onRemove,
                icon: Icon(Icons.close, color: type.fg),
              ),
            ),
        ],
      ),
    );
  }
}
