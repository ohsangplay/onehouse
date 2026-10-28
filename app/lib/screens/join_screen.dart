import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../services/app_services.dart';
import '../theme.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _code = TextEditingController();
  final _nickname = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    _nickname.dispose();
    super.dispose();
  }

  bool get _valid => _code.text.replaceAll(RegExp(r'[\s-]'), '').length == 8 && _nickname.text.trim().isNotEmpty;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final res = await widget.services.api.post('/ledgers/join', {
        'code': _code.text,
        'nickname': _nickname.text.trim(),
      });
      if (!mounted) return;
      final approved = res['status'] == 'approved';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved ? '이미 참여 중인 가계부예요.' : '${res['ledger_name']}에 참여 요청을 보냈어요.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
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
      appBar: AppBar(backgroundColor: AppColors.surface),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '초대코드로 참여하기',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.35),
              ),
              const SizedBox(height: 10),
              const Text(
                '가족에게 받은 코드를 입력하면 방장에게 참여 요청이 가요.',
                style: TextStyle(fontSize: 15, height: 1.6, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 36),
              const Text('초대코드', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                maxLength: 9,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 2),
                decoration: const InputDecoration(hintText: 'XXXX-XXXX', counterText: ''),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              const Text('이 가계부에서 쓸 닉네임', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _nickname,
                maxLength: 20,
                decoration: const InputDecoration(hintText: '예) 엄마', counterText: ''),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              const Text(
                '내역마다 누가 썼는지 이 이름으로 표시돼요',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _valid && !_busy ? _submit : null,
                child: Text(_busy ? '보내는 중…' : '참여 요청 보내기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
