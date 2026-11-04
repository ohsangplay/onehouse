import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

import '../models/category.dart';
import 'category_widgets.dart';

/// 걸려 있는 카테고리 필터. 아무것도 없으면 전체.
class FilterSelection {
  const FilterSelection({this.categoryIds = const {}, this.uncategorized = false});

  final Set<String> categoryIds;

  /// 미분류(카테고리를 지운 내역)도 포함
  final bool uncategorized;

  bool get isEmpty => categoryIds.isEmpty && !uncategorized;
  int get count => categoryIds.length + (uncategorized ? 1 : 0);

  FilterSelection without(String? id) => id == null
      ? FilterSelection(categoryIds: categoryIds)
      : FilterSelection(categoryIds: {...categoryIds}..remove(id), uncategorized: uncategorized);

  /// 지워진 카테고리는 필터에서 뺀다
  FilterSelection prune(List<Category> categories) {
    final alive = categories.map((c) => c.id).toSet();
    return FilterSelection(categoryIds: categoryIds.intersection(alive), uncategorized: uncategorized);
  }

  /// 라벨로 보여줄 (id, 이름, 종류). 고른 순서는 카테고리 목록 순서(공통→지출→수입)를 따른다. 미분류는 id null
  List<(String?, String, CategoryType)> labels(List<Category> categories) => [
        for (final c in categories)
          if (categoryIds.contains(c.id)) (c.id, c.name, c.type),
        if (uncategorized) (null, '미분류', CategoryType.common),
      ];
}

/// 한 줄에 들어가는 라벨 수. 다 못 넣으면 +N 칩 자리를 남긴다.
int visibleLabelCount(List<double> widths, double available, {double gap = 6, double plusWidth = 48}) {
  var used = 0.0;
  for (var i = 0; i < widths.length; i++) {
    final isLast = i == widths.length - 1;
    final need = used + (i == 0 ? 0 : gap) + widths[i];
    final reserve = isLast ? 0 : gap + plusWidth;
    if (need + reserve > available) return i;
    used = need;
  }
  return widths.length;
}

/// 필터 버튼 + 적용된 라벨(×) + 넘치면 +N
class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.selection,
    required this.categories,
    required this.onOpen,
    required this.onRemove,
  });

  final FilterSelection selection;
  final List<Category> categories;
  final VoidCallback onOpen;
  final ValueChanged<String?> onRemove;

  static const _gap = 6.0;

  double _labelWidth(BuildContext context, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: FilterLabel.textStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return 12 + painter.width + 30;
  }

  @override
  Widget build(BuildContext context) {
    final labels = selection.labels(categories);
    final active = labels.isNotEmpty;

    // 머티리얼 버튼을 써야 접근성(버튼 역할·탭 동작)이 제대로 잡힌다
    final fg = active ? Colors.white : AppColors.text;
    final button = OutlinedButton.icon(
      onPressed: onOpen,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, FilterLabel.height + 4),
        maximumSize: const Size(double.infinity, FilterLabel.height + 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: active ? AppColors.text : AppColors.surface,
        foregroundColor: fg,
        side: BorderSide(color: active ? AppColors.text : AppColors.border),
        shape: const StadiumBorder(),
        textStyle: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w700 : FontWeight.w500),
      ),
      icon: Icon(Icons.filter_alt_outlined, size: 17, color: fg),
      label: Text(active ? '필터 ${labels.length}' : '필터'),
    );

    return Row(
      children: [
        button,
        const SizedBox(width: 8),
        Expanded(
          child: !active
              ? const Text('전체 카테고리', style: TextStyle(fontSize: 14, color: AppColors.textSecondary))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final widths = [for (final l in labels) _labelWidth(context, l.$2)];
                    final shown = visibleLabelCount(widths, constraints.maxWidth, gap: _gap);
                    final hidden = labels.length - shown;
                    return Row(
                      children: [
                        for (var i = 0; i < shown; i++) ...[
                          if (i > 0) const SizedBox(width: _gap),
                          FilterLabel(
                            label: labels[i].$2,
                            type: labels[i].$3,
                            onRemove: () => onRemove(labels[i].$1),
                          ),
                        ],
                        if (hidden > 0) ...[
                          if (shown > 0) const SizedBox(width: _gap),
                          Tooltip(
                            message: '나머지 필터 $hidden개 보기',
                            child: OutlinedButton(
                              onPressed: onOpen,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, FilterLabel.height),
                                maximumSize: const Size(double.infinity, FilterLabel.height),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                backgroundColor: AppColors.surface,
                                foregroundColor: AppColors.text,
                                side: const BorderSide(color: Color(0xFFC7CCD2)),
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              child: Text('+$hidden'),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
