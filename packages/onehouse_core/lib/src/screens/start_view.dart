import 'package:flutter/material.dart';

import '../space_config.dart';
import '../theme.dart';

/// 가계부·메모집이 하나도 없을 때 보이는 시작 화면
class StartView extends StatelessWidget {
  const StartView({
    super.key,
    required this.space,
    required this.onCreate,
    required this.onJoin,
    required this.onTransfer,
  });

  final SpaceConfig space;
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(18)),
                      child: Icon(space.icon, color: Colors.white, size: 34),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      space.appName,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${space.tagline}\n회원가입 없이 바로 시작해요.',
                      style: const TextStyle(fontSize: 16, height: 1.6, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              FilledButton(onPressed: onCreate, child: Text('새 ${space.noun} 만들기')),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onJoin, child: const Text('초대코드로 참여하기')),
              const SizedBox(height: 4),
              TextButton(
                onPressed: onTransfer,
                style: TextButton.styleFrom(foregroundColor: primary, minimumSize: const Size.fromHeight(48)),
                child: const Text('기존 기기에서 이전하기', style: TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
