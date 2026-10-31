import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_services.dart';
import '../theme.dart';
import 'recovery_code_screen.dart';

/// 이전 폰 없이 방장 권한 되찾기: 복구코드 입력 → 새 복구코드 1회 표시
class RecoverOwnerScreen extends StatefulWidget {
  const RecoverOwnerScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<RecoverOwnerScreen> createState() => _RecoverOwnerScreenState();
}

class _RecoverOwnerScreenState extends State<RecoverOwnerScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final space = widget.services.space;
    try {
      final res = await widget.services.api.post('${space.apiPath}/recover', {'code': _code.text});
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<bool>(
          builder: (_) => RecoveryCodeScreen(
            space: space,
            spaceName: res['ledger_name'] as String,
            recoveryCode: res['recovery_code'] as String,
            reissued: true,
          ),
        ),
        result: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final space = widget.services.space;
    final valid = _code.text.replaceAll(RegExp(r'[\s-]'), '').length == 12;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(backgroundColor: AppColors.surface),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('방장 권한 되찾기', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.35)),
              const SizedBox(height: 10),
              Text(
                '${space.nounObj} 만들 때 저장한 복구코드를 입력하세요. 이 폰이 방장이 되고, 복구코드는 새로 바뀌어요.',
                style: const TextStyle(fontSize: 15, height: 1.6, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 36),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                maxLength: 14,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 2),
                decoration: const InputDecoration(hintText: 'XXXX-XXXX-XXXX', counterText: ''),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              const Text(
                '부방장·멤버는 초대코드로 다시 요청하면 방장이 기존 자리로 이어 줄 수 있어요.',
                style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
              ),
              const Spacer(),
              FilledButton(
                onPressed: valid && !_busy ? _submit : null,
                child: Text(_busy ? '확인하는 중…' : '되찾기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
