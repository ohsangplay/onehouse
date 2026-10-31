enum MemoKind { text, checklist }

MemoKind parseMemoKind(String? value) => value == 'checklist' ? MemoKind.checklist : MemoKind.text;

String memoKindValue(MemoKind kind) => kind == MemoKind.checklist ? 'checklist' : 'text';

/// 누가 했는지 (id + 닉네임)
class Person {
  const Person(this.id, this.nickname);

  factory Person.fromJson(Object? json) {
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    return Person(map['id'] as String? ?? '', map['nickname'] as String? ?? '알 수 없음');
  }

  final String id;
  final String nickname;

  Map<String, dynamic> toJson() => {'id': id, 'nickname': nickname};
}

class MemoItem {
  const MemoItem({
    required this.id,
    required this.text,
    required this.checked,
    required this.sortOrder,
    required this.version,
    required this.updatedAt,
    required this.updatedBy,
    this.checkedBy,
  });

  factory MemoItem.fromJson(Map<String, dynamic> json) => MemoItem(
        id: json['id'] as String,
        text: json['text'] as String,
        checked: json['checked'] == true,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        version: (json['version'] as num?)?.toInt() ?? 1,
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
        updatedBy: Person.fromJson(json['updated_by']),
        checkedBy: json['checked_by'] as String?,
      );

  final String id;
  final String text;
  final bool checked;
  final int sortOrder;

  /// 글자를 고칠 때만 오른다 (체크는 버전과 상관없음)
  final int version;
  final DateTime updatedAt;
  final Person updatedBy;
  final String? checkedBy;

  MemoItem copyWith({String? text, bool? checked, int? version, String? checkedBy, bool clearCheckedBy = false}) =>
      MemoItem(
        id: id,
        text: text ?? this.text,
        checked: checked ?? this.checked,
        sortOrder: sortOrder,
        version: version ?? this.version,
        updatedAt: updatedAt,
        updatedBy: updatedBy,
        checkedBy: clearCheckedBy ? null : (checkedBy ?? this.checkedBy),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'checked': checked,
        'sort_order': sortOrder,
        'version': version,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'updated_by': updatedBy.toJson(),
        'checked_by': checkedBy,
      };
}

/// 지금 이 메모를 보고 있는 다른 멤버
class Viewer {
  const Viewer(this.nickname, this.editing);

  factory Viewer.fromJson(Map<String, dynamic> json) =>
      Viewer(json['nickname'] as String? ?? '', json['editing'] == true);

  final String nickname;
  final bool editing;
}

class Memo {
  const Memo({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.version,
    required this.pinned,
    required this.createdBy,
    required this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
    this.items = const [],
    this.viewers = const [],
  });

  factory Memo.fromJson(Map<String, dynamic> json) => Memo(
        id: json['id'] as String,
        kind: parseMemoKind(json['kind'] as String?),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        version: (json['version'] as num?)?.toInt() ?? 1,
        pinned: json['pinned'] == true,
        createdBy: Person.fromJson(json['created_by']),
        updatedBy: Person.fromJson(json['updated_by']),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((e) => MemoItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        viewers: (json['viewers'] as List<dynamic>? ?? const [])
            .map((e) => Viewer.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final MemoKind kind;
  final String title;
  final String body;

  /// 제목·본문을 저장할 때마다 오른다. 고치기 시작한 버전을 서버에 함께 보내 충돌을 판단한다.
  final int version;
  final bool pinned;
  final Person createdBy;
  final Person updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<MemoItem> items;
  final List<Viewer> viewers;

  bool get isChecklist => kind == MemoKind.checklist;

  /// 제목이 없으면 본문 첫 줄
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final first = body.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    return first.trim().isEmpty ? '제목 없음' : first.trim();
  }

  Memo copyWith({List<MemoItem>? items, String? title, int? version, bool? pinned}) => Memo(
        id: id,
        kind: kind,
        title: title ?? this.title,
        body: body,
        version: version ?? this.version,
        pinned: pinned ?? this.pinned,
        createdBy: createdBy,
        updatedBy: updatedBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
        items: items ?? this.items,
        viewers: viewers,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': memoKindValue(kind),
        'title': title,
        'body': body,
        'version': version,
        'pinned': pinned,
        'created_by': createdBy.toJson(),
        'updated_by': updatedBy.toJson(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'items': items.map((i) => i.toJson()).toList(),
      };
}

/// 메모 목록의 한 줄
class MemoSummary {
  const MemoSummary({
    required this.id,
    required this.kind,
    required this.title,
    required this.preview,
    required this.pinned,
    required this.itemCount,
    required this.checkedCount,
    required this.createdBy,
    required this.updatedBy,
    required this.updatedAt,
  });

  factory MemoSummary.fromJson(Map<String, dynamic> json) => MemoSummary(
        id: json['id'] as String,
        kind: parseMemoKind(json['kind'] as String?),
        title: json['title'] as String? ?? '',
        preview: json['preview'] as String? ?? '',
        pinned: json['pinned'] == true,
        itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
        checkedCount: (json['checked_count'] as num?)?.toInt() ?? 0,
        createdBy: Person.fromJson(json['created_by']),
        updatedBy: Person.fromJson(json['updated_by']),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
      );

  final String id;
  final MemoKind kind;
  final String title;
  final String preview;
  final bool pinned;
  final int itemCount;
  final int checkedCount;
  final Person createdBy;
  final Person updatedBy;
  final DateTime updatedAt;

  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    if (kind == MemoKind.checklist) return '체크리스트';
    final first = preview.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    return first.trim().isEmpty ? '제목 없음' : first.trim();
  }
}
