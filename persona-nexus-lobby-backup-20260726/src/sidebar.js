import { positionMenu } from './menuPosition.js';

// 手機抽屜關閉：收起側邊欄與遮罩。桌機（無 .open）呼叫也無副作用。
function closeDrawer() {
  const sidebar = document.getElementById('sidebar');
  const overlay = document.getElementById('sidebar-overlay');
  if (sidebar) sidebar.classList.remove('open');
  if (overlay) overlay.classList.remove('visible');
}

// 設定收合鈕（桌機 «/»）與漢堡鈕、遮罩（手機抽屜）的行為。
function setupSidebarToggle() {
  const sidebar = document.getElementById('sidebar');
  const toggleBtn = document.getElementById('sidebar-toggle');
  const hamburgerBtn = document.getElementById('hamburger-btn');
  const overlay = document.getElementById('sidebar-overlay');

  // 桌機：« 收合成 60px 圖示條，» 展開回 250px
  if (toggleBtn && sidebar) {
    toggleBtn.addEventListener('click', () => {
      const collapsed = sidebar.classList.toggle('collapsed');
      toggleBtn.textContent = collapsed ? '»' : '«';
    });
  }

  // 手機：漢堡鈕滑出抽屜、遮罩點擊收起
  if (hamburgerBtn && sidebar) {
    hamburgerBtn.addEventListener('click', () => {
      sidebar.classList.add('open');
      if (overlay) overlay.classList.add('visible');
    });
  }
  if (overlay) {
    overlay.addEventListener('click', closeDrawer);
  }
}

export async function initSidebar() {
  // 同源部署：gateway 一律走相對路徑 /api
  const GATEWAY_URL = '/api';

  const sidebarContainer = document.getElementById('sidebar-container');
  const response = await fetch('/src/sidebar.html');
  const html = await response.text();
  sidebarContainer.innerHTML = html;

  const logoBtn = document.getElementById('logo-btn');
  const createBtn = document.getElementById('create-btn');
  const logoutBtn = document.getElementById('logout-btn');
  const contentArea = document.getElementById('content-area');
  const sidebarMiddle = document.getElementById('sidebar-middle');

  // 側邊欄收合（桌機）/ 抽屜（手機）控制
  setupSidebarToggle();

  // 🆕 載入聊天過的角色按鈕
  await loadChatHistoryButtons(sidebarMiddle, GATEWAY_URL);

  // Logo 按鈕：回到首頁（清空右側內容）
  logoBtn.addEventListener('click', async () => {
    closeDrawer();  // 手機：點導覽項目後收起抽屜
    await loadHome();
    history.pushState({ page: 'home' }, '', '/');
  });

  // 創建角色按鈕：載入「我的角色」
  createBtn.addEventListener('click', async () => {
    closeDrawer();  // 手機：點導覽項目後收起抽屜
    await loadMyCharacter();
    history.pushState({ page: 'myCharacters' }, '', '/my-characters');
  });

  // 登出按鈕：清除 token，回到登入頁
  logoutBtn.addEventListener('click', () => {
    localStorage.removeItem('token');
    window.location.href = '/login';
  });
}

async function loadHome() {
  const { loadHomePage } = await import('./home.js');
  await loadHomePage();
}

async function loadMyCharacter() {
  const { loadMyCharacterPage } = await import('./my-character.js');
  await loadMyCharacterPage();
}

// 🆕 顯示對話菜單
function showConversationMenu(event, item) {
  const token = localStorage.getItem('token');
  const GATEWAY_URL = '/api';

  // 建立菜單
  const menu = document.createElement('div');
  menu.className = 'conversation-menu';

  // 關閉選單：移除節點的同時一定解除監聽器，避免監聽器殘留累積
  function dismissMenu() {
    menu.remove();
    document.removeEventListener('click', closeMenu);
  }

  // 刪除選項
  const deleteOption = document.createElement('div');
  deleteOption.className = 'conversation-menu-item';
  deleteOption.textContent = '🗑️ 刪除';
  deleteOption.addEventListener('click', async () => {
    dismissMenu();

    if (confirm(`確定要刪除與 ${item.characterName} 的所有對話嗎？`)) {
      try {
        console.log('🗑️ [sidebar.js] 刪除對話...');

        const res = await fetch(`${GATEWAY_URL}/conversations/character/${item.characterId}`, {
          method: 'DELETE',
          headers: { 'Authorization': `Bearer ${token}` },
        });

        if (!res.ok) {
          throw new Error(`刪除失敗: ${res.status}`);
        }

        console.log('✅ [sidebar.js] 對話已刪除，重新載入聊天歷史');

        // 重新載入聊天歷史
        const sidebarMiddle = document.getElementById('sidebar-middle');
        sidebarMiddle.innerHTML = '';
        await loadChatHistoryButtons(sidebarMiddle, GATEWAY_URL);
      } catch (error) {
        console.error('❌ [sidebar.js] 刪除失敗:', error);
        alert(`刪除失敗: ${error.message}`);
      }
    }
  });

  menu.appendChild(deleteOption);

  // 先掛上 DOM 才量得到選單尺寸，再依可用空間定位（避免飛出畫面）
  menu.style.position = 'fixed';
  menu.style.visibility = 'hidden';
  document.body.appendChild(menu);
  positionMenu(menu, event.target);
  menu.style.visibility = '';

  // 點擊外部關閉菜單
  setTimeout(() => {
    document.addEventListener('click', closeMenu);
  }, 0);

  function closeMenu(e) {
    if (!menu.contains(e.target) && e.target !== event.target) {
      dismissMenu();
    }
  }
}

// 🆕 載入聊天歷史的角色按鈕
async function loadChatHistoryButtons(container, gatewayUrl) {
  try {
    const token = localStorage.getItem('token');
    if (!token) return;

    console.log('📡 [sidebar.js] 載入聊天歷史...');

    // 🆕 調用 gateway 獲取對話摘要（輕量版）
    const res = await fetch(`${gatewayUrl}/conversations/summary`, {
      headers: { 'Authorization': `Bearer ${token}` },
    });

    if (!res.ok) {
      console.warn('⚠️ [sidebar.js] 無法載入聊天歷史');
      return;
    }

    const summary = await res.json();
    console.log('✅ [sidebar.js] 聊天歷史摘要載入成功，共', summary.length, '個對話');

    // 摘要已按 updatedAt 排序（後端已排序）

    // 為每個對話建立角色按鈕
    summary.forEach((item) => {
      // 🆕 建立容器（flex 布局）
      const btnContainer = document.createElement('div');
      btnContainer.className = 'sidebar-conversation-item';

      // 聊天按鈕（左邊，占滿空間）
      const chatBtn = document.createElement('button');
      chatBtn.className = 'sidebar-conversation-btn';
      chatBtn.textContent = item.characterName || `角色 ${item.characterId}`;
      chatBtn.dataset.conversationId = item.conversationId;
      chatBtn.dataset.characterId = item.characterId;

      // 點擊按鈕後載入聊天室
      chatBtn.addEventListener('click', async () => {
        console.log('💬 [sidebar.js] 點擊聊天按鈕，characterId:', item.characterId);
        closeDrawer();  // 手機：點聊天室後收起抽屜
        const { loadChatPage } = await import('./chat-page.js');
        // 歷史管理由 loadChatPage 負責。這裡原本又推了一次 `/chat/{id}`，
        // 一次點擊留下兩筆歷史、而且網址格式跟 chat-page.js 推的不一致，
        // 導致上一頁要按兩次才回得去。
        await loadChatPage(item.characterId);
      });

      // 🆕 菜單按鈕（右邊，三點）
      const menuBtn = document.createElement('button');
      menuBtn.className = 'sidebar-conversation-menu';
      menuBtn.textContent = '⋮';
      menuBtn.title = '更多選項';
      menuBtn.addEventListener('click', (e) => {
        e.stopPropagation();  // 防止觸發聊天按鈕
        console.log('📋 [sidebar.js] 點擊菜單按鈕，characterId:', item.characterId);
        showConversationMenu(e, item);
      });

      btnContainer.appendChild(chatBtn);
      btnContainer.appendChild(menuBtn);
      container.appendChild(btnContainer);
    });

    if (summary.length === 0) {
      console.log('📭 [sidebar.js] 沒有聊天歷史');
      const emptyMsg = document.createElement('div');
      emptyMsg.className = 'sidebar-empty-msg';
      emptyMsg.textContent = '暫無聊天記錄';
      container.appendChild(emptyMsg);
    }
  } catch (error) {
    console.error('❌ [sidebar.js] 載入聊天歷史失敗:', error);
  }
}
