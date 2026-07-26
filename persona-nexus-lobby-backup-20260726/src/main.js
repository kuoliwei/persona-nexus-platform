import './style.css';
import { getCurrentUserId } from './api.js';
import { initSidebar } from './sidebar.js';
import { loadHomePage } from './home.js';
import { loadConfig } from './config-loader.js';

// 探測後端可達性。同源部署後不需要從設定取得任何網址，
// 這裡只是為了在後端連不上時顯示錯誤畫面。
let configLoadError = false;

try {
  await loadConfig();
} catch (error) {
  console.error('❌ [初始化失敗] 無法載入設定：', error);
  configLoadError = true;
}

// 同源部署：登入前端固定在 /login，不再從 config 讀取跨源網址
const LOGIN_APP_URL = '/login';

if (configLoadError) {
  document.body.innerHTML = '<div style="text-align:center; margin-top:50px; color:#ff4444; font-size:18px;">❌ 無法連線至服務器，請稍後重試。</div>';
}

// 檢查登入狀態
const urlParams = new URLSearchParams(window.location.search);
const tokenFromUrl = urlParams.get('token');

if (tokenFromUrl) {
  localStorage.setItem('token', tokenFromUrl);
  // 只拿掉 token，其餘 query 必須留著——下面的路由還原會讀它（例如 ?id=）。
  urlParams.delete('token');
  const remaining = urlParams.toString();
  window.history.replaceState({}, '', window.location.pathname + (remaining ? `?${remaining}` : ''));
}

const userId = getCurrentUserId();

if (!userId) {
  window.location.href = `${LOGIN_APP_URL}/`;
} else {
  // 初始化：載入側邊欄
  await initSidebar();

  // 依網址列還原頁面。
  //
  // 重新整理、貼網址、開新分頁時，瀏覽器只給我們一個 URL，history.state 是 null，
  // 所有 SPA 狀態都得從 pathname 重建——這裡是那些情況下唯一的入口。
  // 過去這裡只認得 /my-characters 一條，其餘全部落到 else 而靜靜回到首頁，
  // 所以在編輯頁或聊天室按 F5 都會跳回大廳。
  //
  // ⚠️ 新增路由時務必避開 /login、/character、/chat 這三個前綴：deploy/Caddyfile
  // 把它們整段轉給各自的微前端（5173／5174／5176），這個檔案永遠收不到那些請求。
  // 聊天室的網址用 /rooms/ 而不是 /chat/，正是為了繞開這個衝突。
  async function restoreRouteFromUrl() {
    const pathname = window.location.pathname;
    const params = new URLSearchParams(window.location.search);

    // /rooms/{characterId} — 聊天室
    const roomMatch = pathname.match(/^\/rooms\/(.+)$/);
    if (roomMatch) {
      const { loadChatPage } = await import('./chat-page.js');
      await loadChatPage(decodeURIComponent(roomMatch[1]), { replace: true });
      return;
    }

    // /my-characters/edit?id={characterId} — 角色編輯
    if (pathname === '/my-characters/edit' && params.get('id')) {
      const { loadCharacterEditPage } = await import('./character-edit.js');
      await loadCharacterEditPage(params.get('id'), { replace: true });
      return;
    }

    // /my-characters/create — 角色創建
    if (pathname === '/my-characters/create') {
      const { loadCharacterCreatePage } = await import('./character-create.js');
      await loadCharacterCreatePage({ replace: true });
      return;
    }

    // /my-characters — 我的角色
    if (pathname === '/my-characters') {
      const { loadMyCharacterPage } = await import('./my-character.js');
      await loadMyCharacterPage();
      history.replaceState({ page: 'myCharacters' }, '', '/my-characters');
      return;
    }

    // 其餘（含 / 本身與任何無法辨識的路徑）一律回首頁
    await loadHomePage();
    history.replaceState({ page: 'home' }, '', '/');
  }

  await restoreRouteFromUrl();

  // Debug：追蹤所有 pushState/replaceState 操作
  window.historyLog = [{ page: 'home', type: 'replace (initial)', length: window.history.length }];
  const originalPush = window.history.pushState;
  const originalReplace = window.history.replaceState;

  window.history.pushState = function(...args) {
    originalPush.apply(window.history, args);
    window.historyLog.push({ state: args[0], type: 'push', length: window.history.length });
    console.log('📍 pushState:', args[0], '| Length:', window.history.length, '| Full log:', window.historyLog);
  };

  window.history.replaceState = function(...args) {
    originalReplace.apply(window.history, args);
    window.historyLog.push({ state: args[0], type: 'replace', length: window.history.length });
    console.log('📍 replaceState:', args[0], '| Length:', window.history.length, '| Full log:', window.historyLog);
  };

  // 監聽瀏覽器上一頁/下一頁
  window.addEventListener('popstate', async (event) => {
    console.log('⬅️ popstate triggered:', event.state, '| Current length:', window.history.length);
    if (event.state?.page === 'home') {
      const { loadHomePage } = await import('./home.js');
      await loadHomePage();
    } else if (event.state?.page === 'myCharacters') {
      const { loadMyCharacterPage } = await import('./my-character.js');
      await loadMyCharacterPage();
    } else if (event.state?.page === 'edit') {
      const { loadCharacterEditPage } = await import('./character-edit.js');
      await loadCharacterEditPage(event.state.characterId);
    } else if (event.state?.page === 'create') {
      const { loadCharacterCreatePage } = await import('./character-create.js');
      await loadCharacterCreatePage();
    } else if (event.state?.page === 'chat') {
      const { loadChatPage } = await import('./chat-page.js');
      await loadChatPage(event.state.characterId);
    }
  });
}
