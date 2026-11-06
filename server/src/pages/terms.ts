// 한지붕 시리즈(가계부·메모) 이용약관. 스토어(Play 판매자 상태 선언 등)에 등록하는 주소: <서버>/terms
import { CONTACT_EMAIL } from './privacy';

export const TERMS_EFFECTIVE_DATE = '2026년 11월 6일';

/** base: 서버가 붙어 있는 경로 (예: /onehouse/budget). 정해진 값만 들어온다 */
export function renderTerms(base = ''): string {
  return `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>이용약관 · 한지붕</title>
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
<h1>이용약관</h1>
<p class="meta">한지붕 가계부 · 한지붕 메모 (이하 "서비스") · 시행일 ${TERMS_EFFECTIVE_DATE}</p>

<div class="summary">
<ul>
<li>서비스는 오상플레이(이하 "운영자")가 무료로 제공합니다. 회원가입·로그인 없이 초대코드로 가족·지인과 함께 씁니다.</li>
<li>이용자가 쓴 내역·메모는 이용자의 것이며, 같은 가계부·메모집의 승인된 멤버에게만 보입니다.</li>
<li>불법·유해한 내용을 올리거나 다른 사람을 괴롭히면 내용 삭제나 이용 제한을 할 수 있습니다.</li>
<li>가계부는 기록 도구일 뿐 금융 서비스가 아니며, 은행·카드와 연결하거나 돈을 옮기지 않습니다.</li>
</ul>
</div>

<h2>1. 목적</h2>
<p>이 약관은 운영자가 제공하는 한지붕 가계부·한지붕 메모 앱과 관련 서버(이하 "서비스")를 이용하는 조건과 절차, 운영자와 이용자의 권리·의무를 정합니다. 앱을 설치해 이용하면 이 약관에 동의한 것으로 봅니다.</p>

<h2>2. 서비스 내용</h2>
<ul>
<li><b>한지붕 가계부</b>: 가계부를 만들어 수입·지출을 기록하고, 초대코드로 참여한 멤버와 함께 보는 서비스</li>
<li><b>한지붕 메모</b>: 메모집을 만들어 메모를 쓰고, 초대코드로 참여한 멤버와 함께 보는 서비스</li>
<li>서비스는 무료이며, 화면 일부에 광고(Google AdMob)가 나옵니다. 인앱 결제는 없습니다.</li>
</ul>

<h2>3. 이용 방법</h2>
<ul>
<li>앱을 처음 실행하면 기기 계정이 자동으로 만들어지며, 회원가입·로그인은 없습니다.</li>
<li>가계부·메모집을 만든 사람은 방장이 되고, 초대코드로 참여를 요청한 사람을 승인하거나 거절·차단할 수 있습니다. 방장은 부방장을 정해 승인을 함께 맡길 수 있습니다.</li>
<li>초대코드, 방장 복구코드, 기기 이전 코드는 이용자가 직접 관리해야 합니다. 코드를 다른 사람에게 알려 생긴 문제는 운영자가 책임지지 않습니다.</li>
<li>기기를 잃어버리거나 앱을 지우면 기기 이전 코드·복구코드 없이는 이어서 쓰지 못할 수 있습니다.</li>
</ul>

<h2>4. 이용자의 의무</h2>
<p>이용자는 다음 행위를 해서는 안 됩니다.</p>
<ul>
<li>법령에 어긋나는 내용, 음란·폭력적인 내용, 다른 사람의 권리를 침해하는 내용을 올리는 행위</li>
<li>다른 멤버를 괴롭히거나 욕설·비방하는 행위, 스팸·광고를 올리는 행위</li>
<li>다른 사람의 초대코드·기기를 허락 없이 쓰거나, 서비스·서버에 비정상적으로 접근하거나 부담을 주는 행위</li>
<li>서비스를 운영자의 허락 없이 영리 목적으로 쓰는 행위</li>
</ul>

<h2>5. 이용자 콘텐츠와 신고</h2>
<ul>
<li>이용자가 쓴 내역·메모·닉네임(이하 "콘텐츠")의 권리는 이용자에게 있습니다. 운영자는 서비스 제공(저장·동기화·멤버에게 보여 주기)에 필요한 범위에서만 콘텐츠를 다룹니다.</li>
<li>콘텐츠는 같은 가계부·메모집의 승인된 멤버에게만 보이며, 공개 게시·검색 기능은 없습니다.</li>
<li>멤버는 앱의 <b>신고하기</b>(설정, 멤버 관리, 내역)로 부적절한 콘텐츠나 멤버를 신고할 수 있습니다. 운영자는 신고를 24시간 안에 확인하고, 4번을 어긴 경우 콘텐츠 삭제, 해당 기기의 이용 제한 등 조치를 할 수 있습니다.</li>
<li>방장·부방장은 언제든 멤버를 차단할 수 있고, 멤버는 언제든 가계부·메모집에서 나갈 수 있습니다.</li>
</ul>

<h2>6. 서비스 변경·중단</h2>
<p>운영자는 서비스 개선을 위해 기능을 바꾸거나 추가·종료할 수 있습니다. 서비스 전체를 종료할 때는 앱 안내 또는 이 페이지로 30일 전에 알리고, 그 기간 동안 이용자가 자신의 데이터를 확인할 수 있게 합니다. 서버 점검·장애 등으로 서비스가 잠시 중단될 수 있습니다.</p>

<h2>7. 책임의 제한</h2>
<ul>
<li>가계부는 이용자가 직접 입력한 내용을 보여 주는 기록 도구이며 금융 서비스가 아닙니다. 금융기관과 연결하지 않고, 결제·송금·금융 자문을 하지 않습니다. 기록 내용의 정확성과 그에 따른 판단은 이용자에게 있습니다.</li>
<li>운영자는 고의 또는 중대한 과실이 없는 한, 무료로 제공되는 서비스의 이용·중단·데이터 손실로 생긴 손해에 대해 책임지지 않습니다. 중요한 내용은 이용자가 따로 보관해 주세요.</li>
<li>이용자끼리 생긴 분쟁은 당사자끼리 해결해야 하며, 운영자는 신고 처리 등 필요한 범위에서 돕습니다.</li>
</ul>

<h2>8. 데이터 삭제와 개인정보</h2>
<p>개인정보 처리와 데이터 삭제 방법은 <a href="${base}/privacy">개인정보처리방침</a>(<a href="${base}/privacy#delete">데이터 삭제 요청 방법</a>)을 따릅니다.</p>

<h2>9. 약관 변경</h2>
<p>운영자는 관련 법령을 어기지 않는 범위에서 약관을 바꿀 수 있습니다. 바꿀 때는 시행 7일 전(이용자에게 불리한 경우 30일 전)부터 이 페이지에 바뀐 내용과 시행일을 알립니다. 시행일 이후에도 서비스를 이용하면 바뀐 약관에 동의한 것으로 봅니다.</p>

<h2>10. 준거법과 관할</h2>
<p>이 약관은 대한민국 법률을 따르며, 서비스와 관련한 분쟁은 민사소송법에 따른 관할 법원에서 해결합니다.</p>

<h2>11. 문의</h2>
<p>운영자: 오상플레이 · 이메일: <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a></p>

<footer>시행일: ${TERMS_EFFECTIVE_DATE} · <a href="${base}/privacy">개인정보처리방침</a> · <a href="${base}/">한지붕</a></footer>
</main>
</body>
</html>`;
}
