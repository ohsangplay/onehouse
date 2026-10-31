import 'package:flutter/material.dart';
import 'package:onehouse_core/onehouse_core.dart';

/// 화면 맨 위 "오프라인이에요" 띠. 온라인이면 아무것도 안 그린다.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.network, this.message = '오프라인이에요 · 읽기만 할 수 있어요'});

  final NetworkStatus network;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: network,
      builder: (context, _) {
        if (network.online) return const SizedBox.shrink();
        return Material(
          color: const Color(0xFF3D434A),
          child: InkWell(
            onTap: network.check,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  ),
                  const Text('다시 확인', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 온라인일 때만 누를 수 있는 버튼 등에 쓴다
class OnlineBuilder extends StatelessWidget {
  const OnlineBuilder({super.key, required this.network, required this.builder});

  final NetworkStatus network;
  final Widget Function(BuildContext context, bool online) builder;

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: network, builder: (context, _) => builder(context, network.online));
}

/// 오프라인이라 못 하는 동작을 눌렀을 때
void showOfflineNotice(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('오프라인이에요. 연결되면 할 수 있어요.')));
}

/// 쓰기 전에 확인: 오프라인이면 안내하고 false
bool requireOnline(BuildContext context, NetworkStatus network) {
  if (network.online) return true;
  showOfflineNotice(context);
  return false;
}

/// 오류 문구 + 오프라인이면 따로 안내
void showFailure(BuildContext context, Object error) {
  if (error is OfflineException) {
    showOfflineNotice(context);
  } else {
    showError(context, error);
  }
}
