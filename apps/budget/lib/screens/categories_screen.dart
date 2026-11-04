import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

import '../api/budget_api.dart';
import '../models/category.dart';
import '../widgets/category_widgets.dart';

/// 카테고리 관리 (방장·부방장). 바뀐 게 있으면 true를 돌려준다.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key, required this.api});

  final BudgetApi api;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Category>? _all;
  String? _error;
  CategoryType _tab = CategoryType.common;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.api.categories();
      if (!mounted) return;
      setState(() {
        _all = list;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  List<Category> get _current => (_all ?? const []).where((c) => c.type == _tab).toList();

  Future<void> _add() async {
    final created = await showAddCategorySheet(context, api: widget.api, initialType: _tab);
    if (created == null) return;
    _changed = true;
    setState(() => _tab = created.type);
    await _load();
  }

  Future<void> _rename(Category c) async {
    final name = await promptText(context, title: '카테고리 이름', initial: c.name, maxLength: 10);
    if (name == null || name == c.name) return;
    try {
      await widget.api.renameCategory(c.id, name);
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete(Category c) async {
    final ok = await confirmDialog(
      context,
      title: '"${c.name}" 카테고리를 지울까요?',
      message: '이 카테고리로 쓴 내역은 지워지지 않고 미분류로 남아요.',
      action: '지우기',
      danger: true,
    );
    if (!ok) return;
    try {
      await widget.api.deleteCategory(c.id);
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final list = _current;
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    // 화면부터 바로 바꾸고, 순서가 바뀐 것만 서버에 저장
    final others = (_all ?? const <Category>[]).where((c) => c.type != _tab).toList();
    final reordered = [
      for (var i = 0; i < list.length; i++)
        Category(
          id: list[i].id,
          type: list[i].type,
          name: list[i].name,
          sortOrder: i,
          createdByNickname: list[i].createdByNickname,
        ),
    ];
    final before = {for (final c in _current) c.id: c.sortOrder};
    setState(() => _all = [...others, ...reordered]..sort(_byTypeThenOrder));
    try {
      await Future.wait([
        for (final c in reordered)
          if (before[c.id] != c.sortOrder) widget.api.reorderCategory(c.id, c.sortOrder),
      ]);
      _changed = true;
    } catch (e) {
      if (mounted) showError(context, e);
      await _load();
    }
  }

  static int _byTypeThenOrder(Category a, Category b) {
    final t = a.type.index.compareTo(b.type.index);
    return t != 0 ? t : a.sortOrder.compareTo(b.sortOrder);
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final counts = {for (final t in CategoryType.values) t: (all ?? const []).where((c) => c.type == t).length};
    final items = _current;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('카테고리 관리')),
        body: all == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : TextButton(onPressed: _load, child: Text('$_error\n다시 시도', textAlign: TextAlign.center)),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: CategoryTypeSelector(
                      value: _tab,
                      counts: counts,
                      onChanged: (t) => setState(() => _tab = t),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 10),
                    child: Text(
                      '공통 카테고리는 지출·수입 어디서든 고를 수 있어요. 오른쪽 손잡이를 끌어 순서를 바꾸고, 지워도 기존 내역은 미분류로 남아요.',
                      style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Text('${_tab.label} 카테고리가 없어요',
                                style: const TextStyle(color: AppColors.textSecondary)),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: ReorderableListView.builder(
                                buildDefaultDragHandles: false,
                                padding: EdgeInsets.zero,
                                itemCount: items.length,
                                onReorder: _reorder,
                                itemBuilder: (context, i) {
                                  final c = items[i];
                                  return Material(
                                    key: ValueKey(c.id),
                                    color: AppColors.surface,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (i > 0) const Divider(height: 1, indent: 16, color: AppColors.divider),
                                        ListTile(
                                          contentPadding: const EdgeInsets.only(left: 16, right: 4),
                                          title: Row(
                                            children: [
                                              FilterLabel(label: c.name, type: c.type),
                                              if (c.createdByNickname != null) ...[
                                                const SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    '${c.createdByNickname} 추가',
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 12, color: AppColors.textSecondary),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              PopupMenuButton<String>(
                                                tooltip: '${c.name} 편집',
                                                icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
                                                onSelected: (v) => v == 'rename' ? _rename(c) : _delete(c),
                                                itemBuilder: (_) => const [
                                                  PopupMenuItem(value: 'rename', child: Text('이름 바꾸기')),
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    child: Text('지우기', style: TextStyle(color: AppColors.danger)),
                                                  ),
                                                ],
                                              ),
                                              ReorderableDragStartListener(
                                                index: i,
                                                child: Semantics(
                                                  label: '${c.name} 순서 바꾸기',
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(12),
                                                    child: Icon(Icons.drag_handle, color: Color(0xFF8A9099)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
                ],
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: FilledButton.icon(
              onPressed: all == null ? null : _add,
              icon: const Icon(Icons.add),
              label: const Text('카테고리 추가'),
            ),
          ),
        ),
      ),
    );
  }
}
