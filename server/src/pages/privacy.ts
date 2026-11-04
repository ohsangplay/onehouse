// 한지붕 시리즈(가계부·메모) 개인정보처리방침. 스토어에 등록하는 주소: <서버>/privacy
// 서버·앱이 실제로 저장하는 내용과 맞춰야 한다 (migrations/, src/lib/purge.ts, apps/*/lib/services).

export const PRIVACY_EFFECTIVE_DATE = '2026년 11월 4일';
export const CONTACT_EMAIL = 'dkwkehd2@gmail.com';

/** base: 서버가 붙어 있는 경로 (예: /onehouse/budget). 안내 페이지 링크에 쓴다. 정해진 값만 들어온다 */
export function renderPrivacy(base = ''): string {
  return `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>개인정보처리방침 · 한지붕</title>
<meta name="robots" content="index, follow">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap" rel="stylesheet">
<style>
:root{--primary:#1F6F5C;--bg:#F5F6F8;--surface:#FFFFFF;--text:#191C1F;--muted:#5F6670;--border:#D5D9DE;color-scheme:light}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font-family:'Noto Sans KR',-apple-system,BlinkMacSystemFont,'Apple SD Gothic Neo','Malgun Gothic',sans-serif;line-height:1.7;-webkit-font-smoothing:antialiased;word-break:keep-all;overflow-wrap:break-word}
.wrap{max-width:720px;margin:0 auto;padding:40px 20px 48px}
h1{font-size:28px;margin:0 0 6px}
.meta{color:var(--muted);font-size:14px;margin:0 0 24px}
.summary{background:var(--surface);border-radius:16px;padding:18px 20px;margin-bottom:28px;border:1px solid var(--border)}
h2{font-size:18px;margin:32px 0 10px}
p,li{font-size:15px}
ul{padding-left:20px;margin:8px 0}
table{width:100%;border-collapse:collapse;background:var(--surface);border-radius:12px;overflow:hidden;font-size:14px}
th,td{text-align:left;padding:10px 12px;border-bottom:1px solid #ECEEF1;vertical-align:top}
th{background:#EEF0F3;font-weight:700}
a{color:var(--primary)}
footer{margin-top:40px;font-size:13px;color:var(--muted)}
</style>
</head>
<body>
<main class="wrap">
<h1>개인정보처리방침</h1>
<p class="meta">한지붕 가계부 · 한지붕 메모 (이하 "서비스") · 시행일 ${PRIVACY_EFFECTIVE_DATE}</p>

<div class="summary">
<b>요약</b>
<ul>
<li>회원가입·로그인이 없고 운영자는 이름, 전화번호, 이메일, 위치, 광고 ID를 수집하지 않습니다.</li>
<li>함께 쓰기 위해 이용자가 직접 입력한 <b>닉네임과 가계부 내역·메모</b>를 서버에 저장합니다.</li>
<li><b>한지붕 가계부</b>는 화면 아래에 Google AdMob 배너 광고를 보여 줍니다. 광고를 위해 Google이 기기에서 광고 식별자 등을 직접 수집할 수 있습니다(4번 참고). 한지붕 메모에는 광고가 없습니다.</li>
<li>분석 도구를 쓰지 않고, 개인정보를 판매하지 않습니다.</li>
<li>삭제한 가계부·메모집·메모는 30일 뒤 서버에서 완전히 지워집니다.</li>
</ul>
</div>

<p>오상플레이(이하 "운영자")는 「개인정보 보호법」 등 관련 법령을 지키며, 서비스를 이용하는 분의 정보를 다음과 같이 다룹니다.</p>

<h2>1. 처리하는 정보와 목적</h2>
<table>
<tr><th>항목</th><th>내용</th><th>목적</th></tr>
<tr><td>기기 계정</td><td>앱이 처음 실행될 때 만드는 무작위 값(설치 키)과 서버가 발급하는 접속 토큰. 서버에는 되돌릴 수 없는 해시값으로만 저장하며, 기기 고유번호·광고 ID와 관계없습니다.</td><td>로그인 없이 같은 기기를 알아보기, 재설치·기기 변경 시 이어 쓰기</td></tr>
<tr><td>닉네임·역할</td><td>가계부·메모집마다 이용자가 정한 닉네임, 방장·부방장·멤버 역할, 참여 요청·승인·차단 기록</td><td>함께 쓰는 사람 표시, 참여 승인과 권한 관리</td></tr>
<tr><td>이용자가 쓴 내용</td><td>가계부: 금액, 날짜, 카테고리, 메모 / 메모: 제목, 본문, 체크리스트 항목과 체크 여부, 최근 50번의 수정 기록, 작성·수정한 닉네임과 시각</td><td>서비스 제공(같은 공간 멤버와 공유, 동시 수정 병합)</td></tr>
<tr><td>보는 중 기록</td><td>메모를 열어 둔 동안의 닉네임과 시각 (하루 안에 지워짐)</td><td>"지금 ○○님이 보고 있어요" 표시</td></tr>
<tr><td>초대·복구·이전 코드</td><td>초대코드(공간마다 하나), 방장 복구코드와 기기 이전 코드(해시값으로만 저장)</td><td>참여, 방장 권한 복구, 기기 이전</td></tr>
<tr><td>접속 정보</td><td>코드 입력 시도 횟수를 세기 위한 IP 주소의 해시값 (하루 안에 지워짐)</td><td>코드 무작위 대입 방지</td></tr>
</table>
<p>초대코드·가계부 이름·메모 내용은 이용자가 입력하는 대로 저장되므로, 다른 사람의 개인정보나 민감한 정보(계좌 비밀번호 등)는 적지 않도록 주의해 주세요.</p>

<h2>2. 기기에 저장하는 정보</h2>
<ul>
<li>설치 키와 접속 토큰: 기기의 보안 저장소(iOS 키체인, Android Keystore)</li>
<li>한지붕 메모: 오프라인에서 볼 수 있도록 마지막으로 받은 메모 목록·내용, 아직 저장하지 못한 초안, 오프라인에서 누른 체크를 앱 저장 공간에 보관합니다. 앱을 지우면 함께 지워집니다.</li>
</ul>

<h2>3. 공유 범위</h2>
<p>이용자가 쓴 내용과 닉네임은 <b>같은 가계부·메모집에서 승인된 멤버</b>에게만 보입니다. 방장·부방장은 참여 요청자의 닉네임을 볼 수 있습니다. 차단되거나 나간 멤버는 즉시 볼 수 없게 됩니다.</p>

<h2>4. 처리 위탁·국외 이전과 광고</h2>
<p>운영자는 서버와 데이터베이스를 Cloudflare, Inc.(미국)의 Cloudflare Workers·D1에 두고 운영합니다. 위 1번의 정보가 서비스 이용 시점에 암호화된 통신(HTTPS)으로 Cloudflare의 데이터센터(국외 포함)에 저장·처리되며, 보관 기간은 아래 5번과 같습니다. Cloudflare는 서비스 운영을 위해 접속 IP 등을 자체 정책에 따라 처리할 수 있습니다
(<a href="https://www.cloudflare.com/privacypolicy/" rel="noopener">Cloudflare 개인정보 처리방침</a>).
</p>

<p><b>광고 (한지붕 가계부)</b><br>
한지붕 가계부는 광고를 보여 주기 위해 Google LLC(미국)의 Google 모바일 광고 SDK(AdMob)를 씁니다. 이 SDK는 앱 안에서 광고를 고르고 보여 주며 부정 클릭을 막기 위해 다음 정보를 <b>Google에 직접</b> 보냅니다: 광고 식별자(Android 광고 ID), IP 주소와 대략적인 위치, 기기·운영체제·앱 정보, 광고 노출·클릭 기록, 오류·성능 정보. 운영자는 이 정보를 받거나 저장하지 않으며, 가계부 내역·메모·닉네임은 광고에 쓰이지 않습니다.</p>
<ul>
<li>iOS: 앱 추적 허용을 요청하지 않으므로 IDFA(광고 식별자)를 쓰지 않고, 맞춤형이 아닌 광고가 나올 수 있습니다.</li>
<li>Android: 기기 설정 → Google → 광고(또는 개인 정보 보호 → 광고)에서 광고 ID를 재설정·삭제하거나 맞춤 광고를 끌 수 있습니다.</li>
<li>Google이 정보를 처리하는 방식: <a href="https://policies.google.com/technologies/partner-sites?hl=ko" rel="noopener">Google 파트너 사이트·앱의 데이터 사용</a>, <a href="https://policies.google.com/privacy?hl=ko" rel="noopener">Google 개인정보처리방침</a></li>
</ul>
<p>이 밖에 제3자에게 개인정보를 제공하거나 처리를 위탁하지 않습니다.</p>

<h2>5. 보유 기간과 파기</h2>
<ul>
<li>메모를 휴지통으로 옮기면 30일 동안 되살릴 수 있고, 30일이 지나면 서버에서 완전히 지웁니다.</li>
<li>방장이 가계부·메모집을 삭제하면 바로 아무도 볼 수 없게 되고, 30일 뒤 그 안의 모든 내용·멤버 기록과 함께 완전히 지웁니다.</li>
<li>나가기를 하면 더 이상 볼 수 없지만, 함께 쓰던 기록이 깨지지 않도록 내가 쓴 내용과 닉네임은 그 공간에 남습니다. 지우고 싶으면 나가기 전에 직접 지우거나 아래 문의처로 요청해 주세요.</li>
<li>그 밖의 정보는 서비스를 이용하는 동안 보관하며, 아래 문의처로 삭제를 요청하면 지체 없이 지웁니다.</li>
</ul>

<h2>6. 이용자의 권리</h2>
<p>이용자는 언제든지 자신의 정보 열람, 정정, 삭제, 처리 정지를 요청할 수 있습니다. 닉네임은 각 설정 화면에서 바로 바꿀 수 있고, 메모·내역은 앱에서 바로 지울 수 있습니다. 로그인이 없어 본인 확인이 어려우므로, 요청하실 때 앱 설정의 가계부·메모집 이름과 닉네임을 함께 알려 주세요.</p>

<h2>7. 아동의 개인정보</h2>
<p>서비스는 연령 정보를 받지 않으며, 만 14세 미만 아동을 대상으로 하지 않습니다. 만 14세 미만 아동의 정보가 저장된 사실을 알게 되면 지체 없이 지웁니다.</p>

<h2>8. 안전성 확보 조치</h2>
<ul>
<li>모든 통신은 HTTPS로 암호화합니다.</li>
<li>설치 키·토큰·복구코드·이전 코드·IP 주소는 해시값으로만 저장합니다.</li>
<li>모든 요청마다 서버에서 멤버 승인 여부와 권한을 확인합니다.</li>
</ul>

<h2 id="contact">9. 개인정보 보호책임자 및 문의처</h2>
<table>
<tr><th>운영자</th><td>오상플레이 (Google Play 개발자명 "오상")</td></tr>
<tr><th>개인정보 보호책임자</th><td>오상원 (대표)</td></tr>
<tr><th>이메일</th><td><a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a></td></tr>
</table>
<p>개인정보 침해에 관한 상담이 필요하시면 개인정보침해신고센터(privacy.kisa.or.kr, 국번 없이 118), 개인정보분쟁조정위원회(www.kopico.go.kr, 1833-6972)에 문의하실 수 있습니다.</p>

<h2>10. 방침의 변경</h2>
<p>이 방침이 바뀌면 이 페이지에 시행일과 함께 알립니다. 광고·분석 도구를 새로 넣는 등 처리 방식이 달라지면 시행 7일 전까지 먼저 공지합니다.</p>

<footer>시행일: ${PRIVACY_EFFECTIVE_DATE} · <a href="${base}/">한지붕</a></footer>
</main>
</body>
</html>`;
}
