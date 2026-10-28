import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../theme.dart';
import 'ledger_list_screen.dart';

/// 앱 시작: 기기 토큰을 준비한 뒤 가계부 목록으로
class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    try {
      await widget.services.session.ensure();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => LedgerListScreen(services: widget.services),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '서버에 연결하지 못했어요.\n인터넷 연결을 확인해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(onPressed: _start, child: const Text('다시 시도')),
                  ],
                ),
              ),
      ),
    );
  }
}
