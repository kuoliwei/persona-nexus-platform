import { getCurrentUserId } from './api.js';
import { attachIntroTooltip } from './character-tooltip.js';

export async function loadHomePage() {
  const contentArea = document.getElementById('content-area');
  const response = await fetch('/src/home.html');
  const html = await response.text();
  contentArea.innerHTML = html;

  // 初始化首頁
  await initHomePage();

  // 歷史狀態由呼叫端負責：從網址列還原時要 replaceState、點側邊欄 Logo 時要 pushState、
  // popstate 觸發時則完全不該寫。這裡原本無條件 replaceState('/')，
  // 導致側邊欄 Logo 那條路徑先 replace 再 push，留下兩筆都指向 / 的歷史。
}

async function initHomePage() {
  const userId = getCurrentUserId();

  const characterGrid = document.getElementById('character-grid');
  const emptyState = document.getElementById('empty-state');
  const template = document.getElementById('character-card-template');

  try {
    // 從 character-service 獲取所有 public 角色
    console.log('📡 [home.js] 正在獲取公開角色...');

    const response = await fetch('/api/characters?visibility=public', {
      headers: {
        'Authorization': `Bearer ${localStorage.getItem('token')}`,
      },
    });

    if (!response.ok) {
      throw new Error(`Failed to fetch characters: ${response.status}`);
    }

    const characters = await response.json();
    console.log('✅ [home.js] 獲取公開角色成功:', characters);

    if (characters.length === 0) {
      emptyState.style.display = 'block';
      characterGrid.innerHTML = '';
      return;
    }

    // 渲染角色卡片
    characterGrid.innerHTML = '';
    characters.forEach((character) => {
      const card = template.content.cloneNode(true);

      const cardElement = card.querySelector('.character-card');
      cardElement.href = '#';
      cardElement.addEventListener('click', async (e) => {
        e.preventDefault();
        const { loadChatPage } = await import('./chat-page.js');
        await loadChatPage(character.id);
      });

      // 頭像維持空白，套用共用 CSS 的深色底 +「尚無頭像」提示，
      // 與「我的角色」頁的角色卡風格一致
      const nameElement = card.querySelector('.character-name');
      nameElement.textContent = character.name;

      const introElement = card.querySelector('.character-intro');
      introElement.textContent = character.introduction ?? '';

      // 滑鼠移入卡片時，於右側（空間不足改左側）浮出完整簡介
      attachIntroTooltip(cardElement, character.introduction);

      characterGrid.appendChild(card);
    });

    console.log('✅ [home.js] 首頁初始化完成');
  } catch (error) {
    console.error('❌ [home.js] 獲取角色失敗:', error);
    showMessage('無法獲取角色列表', 'error');
  }
}

function showMessage(text, type = 'info') {
  const messageBox = document.getElementById('message-box');
  messageBox.textContent = text;
  messageBox.className = type;
  messageBox.style.display = 'block';

  setTimeout(() => {
    messageBox.style.display = 'none';
  }, 3000);
}
