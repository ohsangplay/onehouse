import 'package:flutter/material.dart';

import '../api_client.dart';
import '../theme.dart';

/// 확인 창. 누르면 true
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String action,
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      content: message == null ? null : Text(message, style: const TextStyle(height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: danger ? TextButton.styleFrom(foregroundColor: AppColors.danger) : null,
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 한 줄 입력 창. 확인하면 입력값(앞뒤 공백 제거)
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String? message,
  int maxLength = 30,
  String action = '저장',
  bool danger = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _PromptDialog(
      title: title,
      initial: initial,
      hint: hint,
      message: message,
      maxLength: maxLength,
      action: action,
      danger: danger,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.message,
    required this.maxLength,
    required this.action,
    required this.danger,
  });

  final String title;
  final String initial;
  final String? hint;
  final String? message;
  final int maxLength;
  final String action;
  final bool danger;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.text.trim();
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message != null) ...[
            Text(widget.message!, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: widget.maxLength,
            decoration: InputDecoration(hintText: widget.hint, counterText: ''),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => value.isEmpty ? null : Navigator.of(context).pop(value),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
        TextButton(
          onPressed: value.isEmpty ? null : () => Navigator.of(context).pop(value),
          style: widget.danger ? TextButton.styleFrom(foregroundColor: AppColors.danger) : null,
          child: Text(widget.action),
        ),
      ],
    );
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void showError(BuildContext context, Object error) => showMessage(context, errorMessage(error));
