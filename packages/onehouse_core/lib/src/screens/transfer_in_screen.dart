import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_services.dart';
import '../theme.dart';
import 'recover_owner_screen.dart';

/// 새 폰에서: 이전 폰의 설정 → 기기 이전에서 받은 코드를 입력
class TransferInScreen extends StatefulWidget {
  const TransferInScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<TransferInScreen> createState() => _TransferInScreenState();
}

class _TransferInScreenState extends State<TransferInScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await widget.services.session.transferFrom(_code.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이전이 끝났어요. ${widget.services.space.nounObj} 그대로 쓸 수 있어요.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _code.text.replaceAll(RegExp(r'[\s-]'), '').length == 8;
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
                '기존 기기에서 이전하기',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.35),
              ),
              const SizedBox(height: 10),
              const Text(
                '이전 폰의 설정 → 기기 이전에서 받은 코드를 입력하세요. 코드는 10분 동안만 쓸 수 있어요.',
                style: TextStyle(fontSize: 15, height: 1.6, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 36),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                maxLength: 9,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 2),
                decoration: const InputDecoration(hintText: 'XXXX-XXXX', counterText: ''),
                onChanged: (_) => setState(() {}),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final done = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => RecoverOwnerScreen(services: widget.services)),
                  );
                  if (done == true && context.mounted) Navigator.of(context).pop(true);
                },
                style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('이전 폰이 없나요? 방장은 복구코드로 되찾을 수 있어요', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: valid && !_busy ? _submit : null,
                child: Text(_busy ? '이전하는 중…' : '이전하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
