## 1. 建立 router.js 核心（路由表 + restoreFromUrl）

- [x] 1.1 建立 `src/router.js`，實作路由表 `routes`（home / myCharacters / create / edit / chat 共 5 條），每條含 `page`、`match(pathname, searchParams)`、`render(params)`
- [x] 1.2 `edit` 路由的 `match()` 對齊原 `main.js` 行為：缺少 `id` 參數時回傳 `undefined`（特殊值，非 `null`）
- [x] 1.3 `chat` 路由的 `match()` 用正則 `/^\/rooms\/(.+)$/` 並 `decodeURIComponent`，對齊原邏輯
- [x] 1.4 實作內部共用函式 `renderForLocation(pathname, searchParams)`：走訪路由表，`undefined` 分支渲染首頁並回傳 `missingParamError` 旗標，完全不比對分支渲染首頁（無錯誤訊息），比對成功呼叫對應 `render(params)`
- [x] 1.5 實作並匯出 `restoreFromUrl()`：呼叫 `renderForLocation()`，成功後用 `history.replaceState({page, params}, '', 目前路徑)` 正規化 state；`undefined` 分支額外呼叫 `showMessage('error', '❌ 缺少角色 ID，請從「我的角色」清單進入編輯頁。', 3000)` 並將網址正規化為 `/`
- [x] 1.6 `main.js` 的 `restoreRouteFromUrl()` 呼叫改為 `import { restoreFromUrl } from './router.js'` + `await restoreFromUrl()`，移除原本 62-109 行的函式定義
- [x] 1.7 `npm run build` 確認打包成功
- [x] 1.8 瀏覽器走查：F5 重新整理 `/`、`/my-characters`、`/my-characters/create`、`/my-characters/edit?id=<有效id>`、`/rooms/<有效id>` 五個路徑，各自正確還原對應頁面
- [x] 1.9 瀏覽器走查：F5 重新整理 `/my-characters/edit`（缺 id），正確回首頁並顯示錯誤訊息

## 2. router.js 加上 popstate 監聽

- [x] 2.1 `router.js` 內部監聽 `window.addEventListener('popstate', ...)`，呼叫 `renderForLocation(location.pathname, new URLSearchParams(location.search))`，**不**呼叫任何 `history.pushState`/`replaceState`
- [x] 2.2 移除 `main.js` 原本 131-149 行的 `popstate` if/else 鏈
- [x] 2.3 移除 `main.js` 原本 113-128 行的 debug 代碼（`window.historyLog`、`pushState`/`replaceState` monkey-patch）
- [x] 2.4 `npm run build` 確認打包成功
- [x] 2.5 瀏覽器走查：從首頁進入「我的角色」→ 按瀏覽器上一頁 → 確認回到首頁；再按下一頁 → 確認回到「我的角色」

## 3. router.js 加上 navigateTo，並改造 7 個觸發點

- [x] 3.1 `router.js` 實作並匯出 `navigateTo(path)`：解析 path 比對路由表、與 `history.state` 做去重檢查（`page` 與 `params` 皆相同則不動作）、呼叫 `render(params)`、`history.pushState({page, params}, '', path)`
- [x] 3.2 `sidebar.js`：Logo 按鈕改為 `navigateTo('/')`，移除手動 `loadHome()` + `pushState`
- [x] 3.3 `sidebar.js`：創建角色按鈕改為 `navigateTo('/my-characters')`，移除手動 `loadMyCharacter()` + `pushState`
- [x] 3.4 `sidebar.js`：`loadChatHistoryButtons` 的 callback 改為 `navigateTo(`/rooms/${characterId}`)`，移除直接 `import('./chat-page.js')`
- [x] 3.5 `home.js`：角色卡點擊改為 `navigateTo(`/rooms/${character.id}`)`
- [x] 3.6 `my-character.js`：`handleCreateClick` 改為 `navigateTo('/my-characters/create')`
- [x] 3.7 `my-character.js`：角色卡點擊進聊天室改為 `navigateTo(`/rooms/${character.id}`)`
- [x] 3.8 `my-character.js`：編輯選單項目 `activateEditOption` 改為 `navigateTo(`/my-characters/edit?id=${encodeURIComponent(character.id)}`)`
- [x] 3.9 `npm run build` 確認打包成功
- [x] 3.10 瀏覽器走查：側邊欄 Logo、創建角色；首頁角色卡點擊進聊天室；我的角色頁的創建按鈕、角色卡進聊天室、編輯選單，皆正常導航且網址列正確更新

## 4. 移除三個 loader 內部的 history 管理程式碼

- [x] 4.1 `chat-page.js`：移除 history 管理程式碼（`options.replace` 參數、`pushState`/`replaceState` 判斷），函式簽名簡化為 `loadChatPage(characterId)`
- [x] 4.2 `character-create.js`：移除 history 管理程式碼，函式簽名簡化為 `loadCharacterCreatePage()`
- [x] 4.3 `character-edit.js`：移除 history 管理程式碼，函式簽名簡化為 `loadCharacterEditPage(characterId)`
- [x] 4.4 確認 `router.js` 路由表內對這三個函式的呼叫已同步不帶 `{ replace: true }` 參數（一開始撰寫 router.js 時就以簡化後的簽名設計，未曾傳入該參數）
- [x] 4.5 `npm run build` 確認打包成功
- [x] 4.6 瀏覽器走查：重複本輪 1.8/1.9/2.5/3.10 所有情境，確認移除 loader 內部 history 邏輯後行為仍然一致

## 5. 全流程回歸驗證

- [x] 5.1 完整走查（透過 Playwright 對真實後端自動化執行）：首頁 → 我的角色 → 創建角色（實際建立一個測試角色）→ 瀏覽器上一頁/下一頁 → F5 重新整理 → 編輯剛建立的角色（選單→編輯，含 F5、上一頁、下一頁）→ 缺 id 的編輯頁回退 → 首頁角色卡進聊天室（含 F5、上一頁）；全部通過，全程零 console error
- [x] 5.2 對照 `openspec/changes/lobby-router-consolidation/specs/lobby-router-module-boundaries/spec.md` 逐條確認每個 Scenario 皆通過
- [x] 5.3 `git diff` 檢查 `index.html`／`style.css`／`api.js`／`message-utils.js`／`iframe-loader.js`／`config-loader.js`／`character-tooltip.js`／`menuPosition.js`／`conversation-history.js` 無非預期改動（確認為空 diff）
- [x] 5.4 更新 `persona-nexus-lobby/CLAUDE.md` 的檔案結構清單與路由相關說明，反映新增的 `router.js` 與五個 loader 的簽名簡化
