import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../space_config.dart';
import '../theme.dart';

/// 가계부·메모집을 만든 직후 한 번만 보여주는 방장 복구코드
class RecoveryCodeScreen extends StatefulWidget {
  const RecoveryCodeScreen({
    super.key,
    required this.space,
    required this.spaceName,
    required this.recoveryCode,
    this.reissued = false,
  });

  final SpaceConfig space;

  /// 설정에서 다시 만든 경우 (버튼 문구만 다름)
  final bool reissued;
  final String spaceName;
  final String recoveryCode;

  @override
  State<RecoveryCodeScreen> createState() => _RecoveryCodeScreenState();
}

class _RecoveryCodeScreenState extends State<RecoveryCodeScreen> {
  bool _saved = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.recoveryCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('복구코드를 복사했어요')));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return PopScope(
      // "저장했어요"를 체크하기 전에는 뒤로 가기로 나갈 수 없다
      canPop: _saved,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${widget.spaceName} · ${widget.reissued ? '새 복구코드' : '생성 완료'}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primary),
                ),
                const SizedBox(height: 10),
                const Text(
                  '방장 복구코드를\n꼭 저장해 주세요',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.35),
                ),
                const SizedBox(height: 10),
                const Text(
                  '폰을 잃어버리거나 바꿨을 때 방장 권한을 되찾는 코드예요. 이 화면을 나가면 다시 볼 수 없어요.',
                  style: TextStyle(fontSize: 15, height: 1.6, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5F4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text('복구코드', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      SelectableText(
                        widget.recoveryCode,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _copy,
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('복사', style: TextStyle(fontSize: 15)),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                CheckboxListTile(
                  value: _saved,
                  onChanged: (v) => setState(() => _saved = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: primary,
                  title: const Text('안전한 곳에 저장했어요', style: TextStyle(fontSize: 15)),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saved ? () => Navigator.of(context).pop(true) : null,
                  child: Text(widget.reissued ? '확인' : '${widget.space.noun} 시작하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
