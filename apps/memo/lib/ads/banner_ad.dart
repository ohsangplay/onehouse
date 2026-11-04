/// 하단 배너 광고 (AdMob). 앱(Android/iOS)에서만 나오고, 웹·테스트에서는 아무것도 그리지 않는다.
///
/// 광고 ID는 config/ads.json (빌드 때 --dart-define-from-file=config/ads.json).
/// 값이 비어 있으면 Google 테스트 광고 ID를 쓴다. 4S 챌린지와 같은 방식.
library;

export 'banner_ad_stub.dart' if (dart.library.io) 'banner_ad_mobile.dart';
