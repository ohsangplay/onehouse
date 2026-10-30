// 브라우저로 접속했을 때 보여주는 앱 설치 안내 페이지.
// 한지붕은 앱 전용이라 웹에서는 가계부를 쓸 수 없다.

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

const appleIcon = `<svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M16.4 12.6c0-2.6 2.1-3.8 2.2-3.9-1.2-1.8-3.1-2-3.7-2-1.6-.2-3.1.9-3.9.9-.8 0-2-.9-3.4-.9-1.7 0-3.3 1-4.2 2.6-1.8 3.1-.5 7.7 1.3 10.2.9 1.2 1.9 2.6 3.2 2.6 1.3-.1 1.8-.8 3.3-.8 1.6 0 2 .8 3.4.8 1.4 0 2.3-1.3 3.1-2.5 1-1.4 1.4-2.8 1.4-2.9 0 0-2.7-1-2.7-4.1ZM13.9 4.9c.7-.9 1.2-2 1-3.2-1 0-2.3.7-3 1.5-.7.8-1.2 2-1.1 3.1 1.2.1 2.3-.6 3.1-1.4Z"/></svg>`;

const playIcon = `<svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M4.2 2.3c-.3.3-.4.7-.4 1.2v17c0 .5.1.9.4 1.2l9.5-9.7-9.5-9.7Zm10.9 8.3 2.7-2.8-11-6.3c-.4-.2-.8-.3-1.1-.2l9.4 9.3Zm0 2.8-9.4 9.3c.3.1.7 0 1.1-.2l11-6.3-2.7-2.8Zm4.1-4.8-3 1.7 3 3.1 3-1.7c.9-.5.9-1.9 0-2.4l-3-.7Z"/></svg>`;

function storeButton(label: string, icon: string, url: string | null): string {
  if (url) {
    return `<a class="store" href="${escapeHtml(url)}" rel="noopener">${icon}<span><small>다운로드</small>${label}</span></a>`;
  }
  return `<span class="store store-soon" aria-disabled="true">${icon}<span><small>출시 준비 중</small>${label}</span></span>`;
}

export function renderLanding(opts: { appStoreUrl?: string; playStoreUrl?: string }): string {
  const appStore = safeUrl(opts.appStoreUrl);
  const playStore = safeUrl(opts.playStoreUrl);
  const year = new Date().getUTCFullYear();

  return `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>한지붕 - 우리가족 공유 가계부</title>
<meta name="description" content="초대코드 하나로 가족과 함께 쓰는 가계부. 한지붕은 앱에서만 쓸 수 있어요.">
<meta name="robots" content="index, follow">
<meta property="og:title" content="한지붕 - 우리가족 공유 가계부">
<meta property="og:description" content="초대코드 하나로 가족과 함께 쓰는 가계부. 앱을 설치하고 바로 시작하세요.">
<meta name="theme-color" content="#1F6F5C">
<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='16' fill='%231F6F5C'/%3E%3Cpath d='M16 30 32 18l16 12M20 28v18h24V28' fill='none' stroke='white' stroke-width='4' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap" rel="stylesheet">
<style>
:root{--primary:#1F6F5C;--primary-dark:#164F41;--primary-soft:#E3F0EB;--bg:#F5F6F8;--surface:#FFFFFF;--text:#191C1F;--muted:#5F6670;--border:#D5D9DE;color-scheme:light}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font-family:'Noto Sans KR',-apple-system,BlinkMacSystemFont,'Apple SD Gothic Neo','Malgun Gothic',sans-serif;line-height:1.6;-webkit-font-smoothing:antialiased;word-break:keep-all;overflow-wrap:break-word}
.wrap{max-width:440px;margin:0 auto;padding:40px 20px 32px}
.brand{display:flex;align-items:center;gap:12px}
.logo{width:48px;height:48px;border-radius:14px;background:var(--primary);display:flex;align-items:center;justify-content:center;flex-shrink:0}
.brand-name{font-size:20px;font-weight:700}
.brand-sub{font-size:13px;color:var(--muted)}
.hero{margin-top:40px}
h1{margin:0;font-size:28px;line-height:1.35;font-weight:700;letter-spacing:-.01em}
.lead{margin:14px 0 0;font-size:16px;color:var(--muted)}
.stores{display:flex;flex-direction:column;gap:10px;margin-top:28px}
.store{display:flex;align-items:center;gap:14px;height:60px;padding:0 20px;border-radius:14px;background:var(--text);color:#fff;text-decoration:none;font-size:17px;font-weight:700}
.store small{display:block;font-size:12px;font-weight:500;opacity:.75;line-height:1.2}
.store span{line-height:1.25}
.store:hover{background:#000}
.store:focus-visible{outline:3px solid var(--primary);outline-offset:2px}
.store-soon{background:var(--surface);color:var(--muted);border:1px solid var(--border);cursor:default}
.store-soon:hover{background:var(--surface)}
.notice{margin-top:12px;font-size:13px;color:var(--muted)}
.card{margin-top:32px;background:var(--surface);border-radius:18px;padding:22px 20px}
.card h2{margin:0 0 14px;font-size:17px;font-weight:700}
.steps{margin:0;padding:0;list-style:none;display:flex;flex-direction:column;gap:14px}
.steps li{display:flex;gap:12px;align-items:flex-start;font-size:15px}
.num{width:26px;height:26px;border-radius:13px;background:var(--primary-soft);color:var(--primary-dark);font-size:13px;font-weight:700;display:flex;align-items:center;justify-content:center;flex-shrink:0;margin-top:1px}
.features{margin-top:12px;display:flex;flex-direction:column;gap:12px}
.feature{background:var(--surface);border-radius:18px;padding:18px 20px;display:flex;gap:14px;align-items:flex-start}
.ficon{width:40px;height:40px;border-radius:12px;background:var(--primary-soft);color:var(--primary);display:flex;align-items:center;justify-content:center;flex-shrink:0}
.feature b{display:block;font-size:15px}
.feature p{margin:2px 0 0;font-size:14px;color:var(--muted)}
footer{margin-top:40px;font-size:12px;color:var(--muted);text-align:center}
</style>
</head>
<body>
<main class="wrap">
  <div class="brand">
    <div class="logo"><svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 10.5 12 4l9 6.5"/><path d="M5 9.5V20h14V9.5"/></svg></div>
    <div><div class="brand-name">한지붕</div><div class="brand-sub">우리가족 공유 가계부</div></div>
  </div>

  <section class="hero">
    <h1>한지붕은<br>앱에서만 쓸 수 있어요</h1>
    <p class="lead">초대코드 하나로 가족과 함께 쓰는 가계부예요. 회원가입 없이 앱을 설치하고 바로 시작하세요.</p>
    <div class="stores">
      ${storeButton('App Store', appleIcon, appStore)}
      ${storeButton('Google Play', playIcon, playStore)}
    </div>
    ${appStore || playStore ? '' : '<p class="notice">지금 스토어 출시를 준비하고 있어요. 조금만 기다려 주세요.</p>'}
  </section>

  <section class="card" aria-labelledby="invite-title">
    <h2 id="invite-title">초대코드를 받으셨나요?</h2>
    <ol class="steps">
      <li><span class="num">1</span><span>한지붕 앱을 설치해요</span></li>
      <li><span class="num">2</span><span>첫 화면에서 <b>초대코드로 참여하기</b>를 눌러요</span></li>
      <li><span class="num">3</span><span>받은 코드와 닉네임을 넣으면 방장에게 참여 요청이 가요</span></li>
    </ol>
  </section>

  <section class="features" aria-label="한지붕 특징">
    <div class="feature">
      <div class="ficon"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="9" cy="8" r="3"/><path d="M3 19c0-3 2.7-5 6-5s6 2 6 5"/><circle cx="17" cy="9" r="2.5"/><path d="M16 14c2.8 0 5 1.6 5 4.5"/></svg></div>
      <div><b>가족이 같이 쓰는 가계부</b><p>누가 쓴 내역인지 닉네임으로 바로 보여요.</p></div>
    </div>
    <div class="feature">
      <div class="ficon"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3 5 6v5c0 4.5 3 8 7 10 4-2 7-5.5 7-10V6l-7-3Z"/><path d="m9 12 2 2 4-4"/></svg></div>
      <div><b>방장이 승인해야 들어올 수 있어요</b><p>초대코드가 퍼져도 방장이 허락한 사람만 볼 수 있어요.</p></div>
    </div>
    <div class="feature">
      <div class="ficon"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18"/><path d="M8 3v4"/><path d="M16 3v4"/></svg></div>
      <div><b>목록과 달력으로 한눈에</b><p>공통·지출·수입 카테고리로 나눠서 필터로 모아봐요.</p></div>
    </div>
  </section>

  <footer>© ${year} 오상플레이</footer>
</main>
</body>
</html>`;
}

export const LANDING_HEADERS: Record<string, string> = {
  'Content-Security-Policy':
    "default-src 'none'; style-src 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; img-src data:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
  'X-Content-Type-Options': 'nosniff',
  'Referrer-Policy': 'no-referrer',
  'Cache-Control': 'public, max-age=300',
};
