// 초대 링크 페이지 (/join?code=XXXX-XXXX).
// 앱의 설정 화면에서 복사한 초대 문구에 들어가는 링크다. 메신저에서 누르면 이 페이지가 열리고
//   - 앱이 있으면 "앱에서 참여하기" → onehouse-<앱>://join?code=… 로 앱을 열어 참여 화면에 코드를 채운다
//   - 앱이 없으면 스토어 버튼으로 설치 → 앱에서 코드를 입력 (코드 복사 버튼)
// 메모집 이름 등은 보여주지 않는다 (코드만 알면 누구나 열 수 있는 주소라서).

export type InviteApp = {
  name: string;
  /** 앱을 여는 주소 이름: onehouse-memo */
  scheme: string;
  /** Android 패키지명 = iOS 번들 ID */
  packageName: string;
  color: string;
  colorDark: string;
  colorSoft: string;
  appStoreUrl?: string;
  playStoreUrl?: string;
};

function safeUrl(value: string | undefined): string | null {
  if (!value) return null;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' ? url.toString() : null;
  } catch {
    return null;
  }
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (ch) => `&#${ch.charCodeAt(0)};`);
}

/** 초대코드는 영문 대문자·숫자와 하이픈만 (앱이 만드는 모양: XXXX-XXXX) */
export function normalizeInviteCode(raw: string | undefined): string | null {
  const code = (raw ?? '').trim().toUpperCase();
  return /^[A-Z0-9]{2,12}(?:-[A-Z0-9]{2,12})?$/.test(code) ? code : null;
}

export function inviteHeaders(nonce: string): Record<string, string> {
  return {
    'Content-Security-Policy': `default-src 'none'; style-src 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; img-src data:; script-src 'nonce-${nonce}'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`,
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'no-referrer',
    // 코드가 주소에 들어 있어서 공유 캐시에 남기지 않는다
    'Cache-Control': 'private, no-store',
    'X-Robots-Tag': 'noindex, nofollow',
  };
}

/**
 * pageUrl: 이 페이지 주소. 링크를 열면 바로 앱을 열어 보고(iOS는 "앱에서 여시겠습니까?" 확인 창),
 * Android에서 앱이 없으면 이 페이지(auto=0)로 돌아와 설치·코드 복사를 안내한다.
 */
export function renderInvite(app: InviteApp, rawCode: string | undefined, nonce: string, pageUrl?: string): string {
  const code = normalizeInviteCode(rawCode);
  const appStore = safeUrl(app.appStoreUrl);
  const playStore = safeUrl(app.playStoreUrl) ?? `https://play.google.com/store/apps/details?id=${app.packageName}`;
  const schemeUrl = code ? `${app.scheme}://join?code=${encodeURIComponent(code)}` : `${app.scheme}://join`;
  // Android 크롬·인앱 브라우저: 앱이 없으면 Play 스토어로 바로 간다
  const intentUrl =
    `intent://join${code ? `?code=${encodeURIComponent(code)}` : ''}` +
    `#Intent;scheme=${app.scheme};package=${app.packageName};S.browser_fallback_url=${encodeURIComponent(playStore)};end`;
  // 페이지를 열자마자 자동으로 앱 열기 (한 번만: 돌아온 주소에는 auto=0)
  let backUrl: string | null = null;
  if (pageUrl && code) {
    const u = new URL(pageUrl);
    u.searchParams.set('auto', '0');
    backUrl = u.toString();
  }
  const autoOpen = Boolean(backUrl) && !(pageUrl ?? '').includes('auto=0');
  const autoIntentUrl = backUrl
    ? `intent://join?code=${encodeURIComponent(code!)}#Intent;scheme=${app.scheme};package=${app.packageName};S.browser_fallback_url=${encodeURIComponent(backUrl)};end`
    : intentUrl;
  const name = escapeHtml(app.name);
  const appStoreSearch = `https://apps.apple.com/kr/search?term=${encodeURIComponent(app.name)}`;

  return `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${name} 초대</title>
<meta name="robots" content="noindex, nofollow">
<meta property="og:title" content="${name}에 초대받았어요">
<meta property="og:description" content="링크를 눌러 앱에서 참여를 요청하세요. 방장이 승인하면 함께 쓸 수 있어요.">
<meta name="theme-color" content="${app.color}">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap" rel="stylesheet">
<style>
:root{--primary:${app.color};--primary-dark:${app.colorDark};--primary-soft:${app.colorSoft};--bg:#F5F6F8;--surface:#FFFFFF;--text:#191C1F;--muted:#5F6670;--border:#D5D9DE;color-scheme:light}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font-family:'Noto Sans KR',-apple-system,BlinkMacSystemFont,'Apple SD Gothic Neo','Malgun Gothic',sans-serif;line-height:1.6;-webkit-font-smoothing:antialiased;word-break:keep-all;overflow-wrap:break-word}
.wrap{max-width:440px;margin:0 auto;padding:40px 20px 32px}
h1{margin:0;font-size:26px;line-height:1.35;font-weight:700}
.lead{margin:10px 0 0;font-size:15px;color:var(--muted)}
.card{margin-top:28px;background:var(--surface);border:1px solid var(--border);border-radius:16px;padding:20px}
.label{font-size:13px;color:var(--muted)}
.code{display:flex;align-items:center;gap:10px;margin-top:4px}
.code b{flex:1;font-size:26px;letter-spacing:2px;font-family:ui-monospace,Menlo,monospace;color:var(--primary)}
button,.btn{font:inherit;cursor:pointer;border-radius:12px;text-decoration:none;display:flex;align-items:center;justify-content:center}
.copy{border:1px solid var(--border);background:var(--surface);color:var(--text);padding:8px 14px;font-size:14px}
.open{width:100%;margin-top:20px;border:0;background:var(--primary);color:#fff;padding:15px;font-size:17px;font-weight:700}
.open:active{background:var(--primary-dark)}
.hint{margin:12px 0 0;font-size:13px;color:var(--muted)}
.stores{display:flex;flex-direction:column;gap:10px;margin-top:14px}
.store{border:1px solid var(--border);background:var(--surface);color:var(--text);padding:12px;font-size:15px;font-weight:500}
.steps{margin:24px 0 0;padding-left:20px;font-size:14px;color:var(--muted)}
.toast{position:fixed;left:50%;bottom:28px;transform:translateX(-50%);background:#191C1F;color:#fff;padding:10px 16px;border-radius:10px;font-size:14px;opacity:0;transition:opacity .2s;pointer-events:none}
.toast.show{opacity:1}
[hidden]{display:none!important}
</style>
</head>
<body>
<main class="wrap">
  <h1>${name}에<br>초대받았어요</h1>
  <p class="lead">앱에서 참여를 요청하면, 방장이 승인한 뒤 함께 쓸 수 있어요.</p>
  <section class="card">
    ${
      code
        ? `<div class="label">초대코드</div>
    <div class="code"><b id="code">${escapeHtml(code)}</b><button class="copy" id="copy" type="button">복사</button></div>`
        : `<div class="label">초대코드가 없는 링크예요. 초대한 사람에게 코드를 다시 받아 주세요.</div>`
    }
    <a class="btn open" id="open" href="${escapeHtml(schemeUrl)}">앱에서 참여하기</a>
    <p class="hint" id="hint" hidden>앱이 열리지 않으면 아래에서 설치한 뒤, 이 링크를 다시 누르거나 앱의 "초대코드로 참여하기"에 코드를 넣어 주세요.</p>
    <div class="stores">
      <a class="btn store" href="${escapeHtml(appStore ?? appStoreSearch)}" rel="noopener">App Store에서 설치</a>
      <a class="btn store" href="${escapeHtml(playStore)}" rel="noopener">Google Play에서 설치</a>
    </div>
  </section>
  <ol class="steps">
    <li>${name} 앱을 설치해요</li>
    <li>"앱에서 참여하기"를 누르거나, 앱의 "초대코드로 참여하기"에 코드를 넣어요</li>
    <li>닉네임을 정하고 참여 요청을 보내면, 방장이 승인해요</li>
  </ol>
</main>
<div class="toast" id="toast" role="status"></div>
<script nonce="${nonce}">
(function () {
  var ua = navigator.userAgent || '';
  var android = /Android/i.test(ua);
  var open = document.getElementById('open');
  var hint = document.getElementById('hint');
  var toast = document.getElementById('toast');
  function show(msg) {
    toast.textContent = msg;
    toast.className = 'toast show';
    setTimeout(function () { toast.className = 'toast'; }, 1800);
  }
  open.addEventListener('click', function (e) {
    e.preventDefault();
    location.href = android ? ${JSON.stringify(intentUrl)} : ${JSON.stringify(schemeUrl)};
    setTimeout(function () { if (!document.hidden) hint.hidden = false; }, 1500);
  });
  // 링크를 열면 바로 앱 열기 시도 (앱이 있으면 참여 화면에 코드가 채워진 채로 열림)
  if (${JSON.stringify(autoOpen)}) {
    setTimeout(function () {
      location.href = android ? ${JSON.stringify(autoIntentUrl)} : ${JSON.stringify(schemeUrl)};
      setTimeout(function () { if (!document.hidden) hint.hidden = false; }, 2000);
    }, 400);
  }
  var copy = document.getElementById('copy');
  if (copy) copy.addEventListener('click', function () {
    var text = document.getElementById('code').textContent;
    function fallback() {
      var t = document.createElement('textarea');
      t.value = text; document.body.appendChild(t); t.select();
      try { document.execCommand('copy'); show('초대코드를 복사했어요'); } catch (_) { show('코드를 길게 눌러 복사해 주세요'); }
      document.body.removeChild(t);
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(function () { show('초대코드를 복사했어요'); }, fallback);
    } else fallback();
  });
})();
</script>
</body>
</html>`;
}
