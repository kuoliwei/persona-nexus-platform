
// options.replace：從網址列還原頁面時傳 true，改用 replaceState，
// 免得重新整理後多出一筆指向同一個網址的歷史紀錄。
export async function loadChatPage(characterId, options = {}) {
  // 同源部署：chat 前端固定掛在 /chat
  const CHAT_APP_URL = '/chat';

  const contentArea = document.getElementById('content-area');
  const response = await fetch('/src/chat.html');
  const html = await response.text();
  contentArea.innerHTML = html;

  const token = localStorage.getItem('token');
  const iframe = document.getElementById('chat-frame');
  iframe.src = `${CHAT_APP_URL}/index.html?characterId=${encodeURIComponent(characterId)}&token=${encodeURIComponent(token)}`;

  // 歷史狀態管理
  //
  // ⚠️ 網址是 /rooms/ 而不是 /chat/：deploy/Caddyfile 的 `handle /chat*` 會把所有
  // /chat 開頭的請求轉給 chat 微前端（5176）。若在這裡推 /chat?characterId=...，
  // 平常沒事（pushState 不發請求），但使用者一按 F5，Caddy 就會把請求交給 chat 前端，
  // 而它是個只吃 query 參數的 iframe 子頁，拿不到 token 就會導向登入頁。
  const method = options.replace ? 'replaceState' : 'pushState';
  if (options.replace || history.state?.page !== 'chat' || history.state?.characterId !== characterId) {
    history[method]({ page: 'chat', characterId }, '', `/rooms/${encodeURIComponent(characterId)}`);
  }
}
