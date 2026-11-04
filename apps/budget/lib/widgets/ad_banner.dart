import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob 설정. 광고 단위 ID는 빌드할 때 넣는다 (넣지 않으면 Google 테스트 광고).
///   flutter build ios --dart-define=ADMOB_BANNER_IOS=ca-app-pub-xxxx/yyyy
///   flutter build appbundle --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-xxxx/yyyy
/// 앱 ID(ca-app-pub-xxxx~zzzz)는 scripts/flutter_platforms.sh가 AndroidManifest·Info.plist에 넣는다.
class Ads {
  static const _bannerAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/9214589741', // Google 테스트용 적응형 배너
  );
  static const _bannerIos = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/2435281174', // Google 테스트용 적응형 배너
  );

  /// 웹(스크린샷·e2e)·테스트에서는 광고를 띄우지 않는다
  static final bool enabled = !kIsWeb &&
      !const bool.fromEnvironment('E2E') &&
      !const bool.fromEnvironment('NO_ADS') &&
      (Platform.isAndroid || Platform.isIOS);

  /// 확인용 빌드(--dart-define=AD_DEBUG=true): 광고를 못 받아와도 배너 자리에 상태·오류 코드를 보여 준다
  static const debug = bool.fromEnvironment('AD_DEBUG');

  static String get bannerUnitId => Platform.isIOS ? _bannerIos : _bannerAndroid;

  static Future<void> init() async {
    if (!enabled) return;
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('광고 초기화 실패: $e');
    }
  }
}

/// 화면 맨 아래 고정 배너 (적응형). 광고가 없거나 실패하면 자리를 차지하지 않는다.
/// 아래 안전 영역(홈 인디케이터)도 여기서 챙긴다.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _requested = false;
  String _status = '광고 준비 중';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested || !Ads.enabled) return;
    _requested = true;
    _load(MediaQuery.sizeOf(context).width.truncate()).catchError((Object e) {
      debugPrint('배너 광고 오류: $e');
      if (mounted) setState(() => _status = '광고 오류: $e');
    });
  }

  Future<void> _load(int width) async {
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted) return;
    if (size == null) {
      setState(() => _status = '광고 크기를 못 구함 (width $width)');
      return;
    }
    setState(() => _status = '광고 요청 중… ${Ads.bannerUnitId}');
    final ad = BannerAd(
      adUnitId: Ads.bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('배너 광고 실패: ${error.code} ${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _status = '광고 실패 code ${error.code} (${error.domain})\n${error.message}';
            });
          }
        },
      ),
    );
    setState(() => _ad = ad);
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) {
      if (!Ads.debug) return const SafeArea(top: false, child: SizedBox.shrink());
      return ColoredBox(
        color: const Color(0xFFFFF4E0),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              Ads.enabled ? _status : '광고 꺼짐 (웹·E2E·NO_ADS)',
              style: const TextStyle(fontSize: 11, color: Color(0xFF7A4B00)),
            ),
          ),
        ),
      );
    }
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: ad.size.height.toDouble(),
          child: Center(
            child: SizedBox(
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
          ),
        ),
      ),
    );
  }
}
