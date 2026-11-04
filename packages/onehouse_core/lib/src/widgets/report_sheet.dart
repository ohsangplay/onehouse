import 'package:flutter/material.dart';

import '../app_services.dart';
import '../theme.dart';
import 'dialogs.dart';

/// 신고 사유 (서버에 그대로 저장)
const reportReasons = [
  '부적절하거나 불쾌한 내용',
  '괴롭힘·욕설',
  '스팸·광고',
  '허락 없이 들어온 사람',
  '기타',
];

/// 신고하기 시트. 공간(가계부·메모집)의 승인된 멤버 누구나 쓸 수 있다.
/// 보내면 운영자가 확인한다. 보냈으면 true.
///   targetType: space · member · transaction · memo
Future<bool> showReportSheet(
  BuildContext context, {
  required AppServices services,
  required String spaceId,
  required String targetLabel,
  String targetType = 'space',
  String? targetId,
  String? targetMemberId,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportSheet(
      services: services,
      spaceId: spaceId,
      targetLabel: targetLabel,
      targetType: targetType,
      targetId: targetId,
      targetMemberId: targetMemberId,
    ),
  );
  if (sent == true && context.mounted) {
    showMessage(context, '신고를 보냈어요. 운영자가 확인 후 조치할게요.');
  }
  return sent == true;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.services,
    required this.spaceId,
    required this.targetLabel,
    required this.targetType,
    this.targetId,
    this.targetMemberId,
  });

  final AppServices services;
  final String spaceId;
  final String targetLabel;
  final String targetType;
  final String? targetId;
  final String? targetMemberId;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;
  final _detail = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() => _busy = true);
    try {
      await widget.services.api.post('${widget.services.space.apiPath}/${widget.spaceId}/reports', {
        'target_type': widget.targetType,
        if (widget.targetId != null) 'target_id': widget.targetId,
        if (widget.targetMemberId != null) 'target_member_id': widget.targetMemberId,
        'reason': reason,
        if (_detail.text.trim().isNotEmpty) 'detail': _detail.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final noun = widget.services.space.noun;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('신고하기', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(widget.targetLabel, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v),
                child: Column(
                  children: [
                    for (final r in reportReasons)
                      RadioListTile<String>(
                        value: r,
                        title: Text(r, style: const TextStyle(fontSize: 15)),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _detail,
                maxLength: 500,
                maxLines: 3,
                minLines: 2,
                decoration: const InputDecoration(hintText: '자세한 내용 (선택)'),
              ),
              Text(
                '신고는 운영자에게 전달되고, 24시간 안에 확인해 내용 삭제·멤버 차단 등으로 조치해요. '
                '방장·부방장은 멤버 관리에서 바로 차단할 수 있고, 누구나 이 $noun에서 언제든 나갈 수 있어요.',
                style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _reason == null || _busy ? null : _send,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  child: Text(_busy ? '보내는 중…' : '신고 보내기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
