import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

/// 카테고리 종류. 공통은 지출·수입 어디서든 고를 수 있다.
enum CategoryType { common, expense, income }

CategoryType parseCategoryType(String? value) => switch (value) {
      'expense' => CategoryType.expense,
      'income' => CategoryType.income,
      _ => CategoryType.common,
    };

extension CategoryTypeX on CategoryType {
  String get api => name;

  String get label => switch (this) {
        CategoryType.common => '공통',
        CategoryType.expense => '지출',
        CategoryType.income => '수입',
      };

  /// 라벨 글자색
  Color get fg => switch (this) {
        CategoryType.common => AppColors.commonFg,
        CategoryType.expense => AppColors.expenseFg,
        CategoryType.income => AppColors.incomeFg,
      };

  /// 라벨 배경색
  Color get bg => switch (this) {
        CategoryType.common => AppColors.commonBg,
        CategoryType.expense => AppColors.expenseBg,
        CategoryType.income => AppColors.incomeBg,
      };

  /// 점·테두리 등 진한 색
  Color get dot => switch (this) {
        CategoryType.common => const Color(0xFF6B7280),
        CategoryType.expense => const Color(0xFFC2610C),
        CategoryType.income => const Color(0xFF1C5FB8),
      };

  String get usage => switch (this) {
        CategoryType.common => '지출·수입 어디서든 고를 수 있어요',
        CategoryType.expense => '지출 내역을 쓸 때만 보여요',
        CategoryType.income => '수입 내역을 쓸 때만 보여요',
      };
}

class Category {
  const Category({
    required this.id,
    required this.type,
    required this.name,
    required this.sortOrder,
    this.createdByNickname,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        type: parseCategoryType(json['type'] as String?),
        name: json['name'] as String,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        createdByNickname: json['created_by_nickname'] as String?,
      );

  final String id;
  final CategoryType type;
  final String name;
  final int sortOrder;

  /// 기본 카테고리는 null
  final String? createdByNickname;

  /// 지출이면 공통+지출, 수입이면 공통+수입
  bool usableFor(bool income) =>
      type == CategoryType.common || type == (income ? CategoryType.income : CategoryType.expense);
}
