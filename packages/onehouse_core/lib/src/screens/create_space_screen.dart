import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_services.dart';
import '../theme.dart';
import 'recovery_code_screen.dart';

/// 새 가계부·메모집 만들기 → 복구코드 화면
class CreateSpaceScreen extends StatefulWidget {
  const CreateSpaceScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<CreateSpaceScreen> createState() => _CreateSpaceScreenState();
}

class _CreateSpaceScreenState extends State<CreateSpaceScreen> {
  final _name = TextEditingController();
  final _nickname = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _nickname.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && _nickname.text.trim().isNotEmpty;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final space = widget.services.space;
      final res = await widget.services.api.post(space.apiPath, {
        'name': _name.text.trim(),
        'nickname': _nickname.text.trim(),
      });
      if (!mounted) return;
      final ledger = res['ledger'] as Map<String, dynamic>;
      // 목록은 바로 새로고침되고, 사용자는 복구코드 화면을 본다
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<bool>(
          builder: (_) => RecoveryCodeScreen(
            space: space,
            spaceName: ledger['name'] as String,
            recoveryCode: res['recovery_code'] as String,
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(backgroundColor: AppColors.surface, title: Text('새 ${space.noun}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${space.noun} 이름', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                maxLength: 30,
                decoration: InputDecoration(hintText: space.nameHint, counterText: ''),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              Text('이 ${space.noun}에서 쓸 닉네임', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _nickname,
                maxLength: 20,
                decoration: InputDecoration(hintText: space.ownerNicknameHint, counterText: ''),
                onChanged: (_) => setState(() {}),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _valid && !_busy ? _submit : null,
                child: Text(_busy ? '만드는 중…' : '만들기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
