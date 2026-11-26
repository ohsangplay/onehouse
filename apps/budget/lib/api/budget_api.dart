import 'package:onehouse_core/onehouse_core.dart';

import '../models/category.dart';
import '../models/recurring.dart';
import '../models/transaction.dart';

/// 가계부 전용 API (카테고리·내역). 가계부 만들기·참여·멤버는 onehouse_core가 맡는다.
class BudgetApi {
  BudgetApi(this._api, this.ledgerId);

  final ApiClient _api;
  final String ledgerId;

  String get _base => '/ledgers/$ledgerId';

  Future<Map<String, dynamic>> detail() => _api.get(_base);

  Future<List<Category>> categories() async {
    final res = await _api.get('$_base/categories');
    return (res['categories'] as List<dynamic>).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Category> addCategory(CategoryType type, String name) async {
    final res = await _api.post('$_base/categories', {'type': type.api, 'name': name});
    return Category.fromJson(res);
  }

  Future<void> renameCategory(String id, String name) => _api.patch('$_base/categories/$id', {'name': name});

  Future<void> reorderCategory(String id, int sortOrder) =>
      _api.patch('$_base/categories/$id', {'sort_order': sortOrder});

  Future<void> deleteCategory(String id) => _api.delete('$_base/categories/$id');

  /// 월별 내역. categoryIds를 주면 그 카테고리만, uncategorized면 미분류도 포함 (OR)
  Future<MonthData> month(String month, {Set<String> categoryIds = const {}, bool uncategorized = false}) async {
    final query = StringBuffer('month=$month');
    if (categoryIds.isNotEmpty) query.write('&category_ids=${categoryIds.map(Uri.encodeComponent).join(',')}');
    if (uncategorized) query.write('&uncategorized=1');
    return MonthData.fromJson(await _api.get('$_base/transactions?$query'));
  }

  Future<void> createTxn(Map<String, dynamic> body) => _api.post('$_base/transactions', body);

  Future<void> updateTxn(String id, Map<String, dynamic> body) => _api.patch('$_base/transactions/$id', body);

  Future<void> deleteTxn(String id) => _api.delete('$_base/transactions/$id');

  /// 고정 지출·수입, 할부 목록
  Future<List<RecurringRule>> recurring() async {
    final res = await _api.get('$_base/recurring');
    return (res['rules'] as List<dynamic>).map((e) => RecurringRule.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 만들기. 반환: (규칙, 바로 기록된 내역 수)
  Future<(RecurringRule, int)> createRecurring(Map<String, dynamic> body) async {
    final res = await _api.post('$_base/recurring', body);
    return (RecurringRule.fromJson(res['rule'] as Map<String, dynamic>), (res['created'] as num?)?.toInt() ?? 0);
  }

  Future<void> updateRecurring(String id, Map<String, dynamic> body) => _api.patch('$_base/recurring/$id', body);

  Future<void> deleteRecurring(String id) => _api.delete('$_base/recurring/$id');

  /// 가족이 쓴 내역 알림 켜기·끄기
  Future<void> setNotifyRecords(bool on) => _api.patch('$_base/me', {'notify_records': on});
}
