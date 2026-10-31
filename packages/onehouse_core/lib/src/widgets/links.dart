import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_client.dart';
import 'dialogs.dart';

/// 문의 이메일 (개인정보처리방침과 같은 값)
const supportEmail = 'dkwkehd2@gmail.com';

/// 서버의 개인정보처리방침 주소
String privacyUrl(ApiClient api) => '${api.baseUrl}/privacy';

/// 앱 밖 브라우저·메일 앱으로 열기
Future<void> openExternal(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showMessage(context, '열지 못했어요: $url');
}
