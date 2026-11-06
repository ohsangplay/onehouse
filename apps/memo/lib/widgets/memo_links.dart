import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

/// 글 속의 링크(http://, https://, www.)를 찾는다. 한글이나 공백, 문장 끝 문장부호에서 끊는다.
final _linkPattern = RegExp(
  r"(?:https?://|www\.)[A-Za-z0-9\-._~:/?#\[\]@!$&'()*+,;=%]+",
  caseSensitive: false,
);
const _trailing = '.,;:!?)]}\'"';

List<Uri> findLinks(String text, {int max = 10}) {
  final found = <Uri>[];
  final seen = <String>{};
  for (final m in _linkPattern.allMatches(text)) {
    var raw = m.group(0)!;
    while (raw.isNotEmpty && _trailing.contains(raw[raw.length - 1])) {
      raw = raw.substring(0, raw.length - 1);
    }
    if (raw.toLowerCase().startsWith('www.')) raw = 'https://$raw';
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.host.contains('.') || uri.host.startsWith('.') || uri.host.endsWith('.')) continue;
    if (seen.add(uri.toString())) found.add(uri);
    if (found.length >= max) break;
  }
  return found;
}

/// 보여줄 짧은 이름: 도메인 + 경로 앞부분
String linkLabel(Uri uri) {
  final host = uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
  final path = uri.path == '/' ? '' : uri.path;
  final label = '$host$path';
  return label.length > 32 ? '${label.substring(0, 31)}…' : label;
}

/// 다른 멤버가 넣은 링크일 수 있어서, 주소를 보여주고 확인한 뒤 연다
Future<void> openMemoLink(BuildContext context, Uri uri) async {
  final ok = await confirmDialog(
    context,
    title: '이 링크를 열까요?',
    message: uri.toString(),
    action: '열기',
  );
  if (!ok || !context.mounted) return;
  await openExternal(context, uri.toString());
}

/// 링크가 여러 개면 고르게 한다
Future<void> openMemoLinks(BuildContext context, List<Uri> links) async {
  if (links.isEmpty) return;
  if (links.length == 1) return openMemoLink(context, links.first);
  final picked = await showModalBottomSheet<Uri>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final uri in links)
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(linkLabel(uri)),
              subtitle: Text(uri.toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.of(context).pop(uri),
            ),
        ],
      ),
    ),
  );
  if (picked != null && context.mounted) await openMemoLink(context, picked);
}

/// 글 메모 아래에 붙는 링크 줄 (가로로 넘겨 보기)
class MemoLinkBar extends StatelessWidget {
  const MemoLinkBar({super.key, required this.links});

  final List<Uri> links;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Text('링크 ${links.length}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                ),
              ),
              for (final uri in links)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: Icon(Icons.open_in_new, size: 16, color: primary),
                    label: Text(linkLabel(uri)),
                    onPressed: () => openMemoLink(context, uri),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 글 속 링크를 파란 밑줄로 보여주는 입력칸 컨트롤러 (누르면 아래 링크 줄에서 연다)
class LinkTextEditingController extends TextEditingController {
  LinkTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    // 한글 조합 중에는 기본 표시를 그대로 쓴다 (밑줄 표시가 겹치지 않게)
    if (withComposing && value.isComposingRangeValid) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    final matches = _linkPattern.allMatches(text).toList();
    if (matches.isEmpty) return TextSpan(style: style, text: text);
    final linkStyle = (style ?? const TextStyle()).copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    final children = <TextSpan>[];
    var pos = 0;
    for (final m in matches) {
      var end = m.end;
      while (end > m.start && _trailing.contains(text[end - 1])) {
        end--;
      }
      if (m.start > pos) children.add(TextSpan(text: text.substring(pos, m.start)));
      children.add(TextSpan(text: text.substring(m.start, end), style: linkStyle));
      pos = end;
    }
    if (pos < text.length) children.add(TextSpan(text: text.substring(pos)));
    return TextSpan(style: style, children: children);
  }
}
