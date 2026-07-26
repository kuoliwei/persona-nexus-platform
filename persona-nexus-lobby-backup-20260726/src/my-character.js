import { listMyCharacters } from './api.js';
import { positionMenu } from './menuPosition.js';

export async function loadMyCharacterPage() {
  // 同源部署：character 前端固定掛在 /character（此值目前僅傳入 renderCharacters，未實際使用）
  const CHARACTER_APP_URL = '/character';

  const contentArea = document.getElementById('content-area');
  const response = await fetch('/src/my-character.html');
  const html = await response.text();
  contentArea.innerHTML = html;

  const messageBox = document.getElementById('message-box');
  const createCharacterBtn = document.getElementById('create-character-btn');
  const emptyCreateBtn = document.querySelector('.empty-create-btn');
  const token = localStorage.getItem('token');

  async function handleCreateClick() {
    const { loadCharacterCreatePage } = await import('./character-create.js');
    await loadCharacterCreatePage();
  }

  // 歷史問題修正：每次 loadMyCharacterPage() 執行時，都會新增事件監聽器到按鈕上。
  // 如果直接用 addEventListener，監聽器會累積，導致按一次按鈕會觸發多次，進而推送多次歷史狀態，
  // 造成瀏覽器歷史棧混亂，按上一頁時卡住或循環。
  // 解決方案：用 cloneNode() 克隆按鈕，替換舊按鈕，新克隆的按鈕自動丟掉所有舊監聽器。
  const newCreateBtn = createCharacterBtn.cloneNode(true);
  createCharacterBtn.parentNode.replaceChild(newCreateBtn, createCharacterBtn);
  newCreateBtn.addEventListener('click', handleCreateClick);

  const newEmptyCreateBtn = emptyCreateBtn.cloneNode(true);
  emptyCreateBtn.parentNode.replaceChild(newEmptyCreateBtn, emptyCreateBtn);
  newEmptyCreateBtn.addEventListener('click', handleCreateClick);

  showMessage('info', '載入角色清單中...');

  try {
    const characters = await listMyCharacters();

    clearMessage();
    renderCharacters(characters, CHARACTER_APP_URL);
  } catch (error) {
    showMessage('error', '❌ 載入失敗，請稍後重試。');
    console.error('[my-character.js] 角色清單載入失敗:', error);
  }
}

function showMessage(type, text) {
  const messageBox = document.getElementById('message-box');
  if (!messageBox) return;
  messageBox.className = type;
  messageBox.textContent = text;
}

function clearMessage() {
  const messageBox = document.getElementById('message-box');
  if (!messageBox) return;
  messageBox.className = '';
  messageBox.textContent = '';
}

// 🆕 顯示角色卡菜單
async function showCharacterCardMenu(event, character) {
  // 建立菜單
  const menu = document.createElement('div');
  menu.className = 'conversation-menu';

  // 關閉選單：移除節點的同時一定解除監聽器，避免監聽器殘留累積
  function dismissMenu() {
    menu.remove();
    document.removeEventListener('click', closeMenu);
  }

  // 編輯選項
  const editOption = document.createElement('div');
  editOption.className = 'conversation-menu-item';
  editOption.textContent = '✏️ 編輯';
  editOption.addEventListener('click', async () => {
    console.log('✏️ [my-character.js] 編輯角色，characterId:', character.id);
    dismissMenu();
    const { loadCharacterEditPage } = await import('./character-edit.js');
    await loadCharacterEditPage(character.id);
  });

  menu.appendChild(editOption);

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

function renderCharacters(characters, characterAppUrl) {
  const grid = document.getElementById('character-grid');
  const emptyState = document.getElementById('empty-state');
  const cardTemplate = document.getElementById('character-card-template');

  grid.innerHTML = '';

  if (characters.length === 0) {
    emptyState.classList.add('visible');
    return;
  }

  emptyState.classList.remove('visible');

  characters.forEach((character) => {
    const node = cardTemplate.content.cloneNode(true);
    const card = node.querySelector('.character-card');
    const badge = node.querySelector('.character-badge');
    const menuBtn = node.querySelector('.character-card-menu');

    card.href = '#';
    card.addEventListener('click', async (e) => {
      e.preventDefault();
      // 🆕 改成打開聊天室（原本是進入編輯頁面）
      const { loadChatPage } = await import('./chat-page.js');
      await loadChatPage(character.id);
      // 歷史管理由 chat-page.js 負責，這裡不需要 pushState
    });

    // 🆕 菜單按鈕事件
    menuBtn.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();  // 防止觸發卡片點擊
      showCharacterCardMenu(e, character);
    });

    node.querySelector('.character-name').textContent = character.name;
    node.querySelector('.character-intro').textContent = character.introduction ?? '';

    // 設定公開/私人 badge
    if (character.visibility === 'public') {
      badge.textContent = '公開';
      badge.classList.add('public');
    } else {
      badge.textContent = '私人';
      badge.classList.add('private');
    }

    grid.appendChild(node);
  });
}
