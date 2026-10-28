import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../services/app_services.dart';
import '../theme.dart';
import 'recovery_code_screen.dart';

class CreateLedgerScreen extends StatefulWidget {
  const CreateLedgerScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<CreateLedgerScreen> createState() => _CreateLedgerScreenState();
}

class _CreateLedgerScreenState extends State<CreateLedgerScreen> {
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
      final res = await widget.services.api.post('/ledgers', {
        'name': _name.text.trim(),
        'nickname': _nickname.text.trim(),
      });
      if (!mounted) return;
      final ledger = res['ledger'] as Map<String, dynamic>;
      // 목록은 바로 새로고침되고, 사용자는 복구코드 화면을 본다
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<bool>(
          builder: (_) => RecoveryCodeScreen(
            ledgerName: ledger['name'] as String,
            recoveryCode: res['recovery_code'] as String,
          ),
        ),
        result: true,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(backgroundColor: AppColors.surface, title: const Text('새 가계부')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('가계부 이름', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                maxLength: 30,
                decoration: const InputDecoration(hintText: '예) 우리집 생활비', counterText: ''),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              const Text('이 가계부에서 쓸 닉네임', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _nickname,
                maxLength: 20,
                decoration: const InputDecoration(hintText: '예) 아빠', counterText: ''),
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
