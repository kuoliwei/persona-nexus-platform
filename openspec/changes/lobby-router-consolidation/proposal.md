## Why

`persona-nexus-lobby` 的「路徑 ↔ 頁面狀態 ↔ 渲染函式」這張路由對照表目前重複維護在至少 5 個地方：`main.js` 的 `restoreRouteFromUrl()`（正則比對 pathname）與 `popstate` 監聽器（if/else 比對 `event.state.page`，兩者是同一份對照關係的兩份實作）、`sidebar.js`（Logo／創建角色按鈕各自寫死 `{page, url}` 手動呼叫 `pushState`）、以及 `chat-page.js`／`character-create.js`／`character-edit.js` 三個檔案各自管理自己的 `pushState`/`replaceState` 判斷邏輯。依《程式撰寫設計原則.md》A3（獨立可修改性）與《前端系統設計原則.md》A節單一真相（SSOT）判斷準則，這是明確違反：新增或修改一個路由目前要同步改 3-6 個檔案，改壞一處就會產生「F5 重新整理跳回大廳」這類 bug——`main.js` 既有註解已記錄過這個踩坑歷史。此外 `home.js` 的註解明確承認「歷史狀態由呼叫端負責」，暴露出五個頁面 loader 對 history 管理的呼叫慣例本身就不一致（`chat-page`/`character-create`/`character-edit` 自己管，`home`/`my-character` 不自己管）。

## What Changes

- 新增 `src/router.js`：收斂為單一權威路由表，提供 `navigateTo(path)`（主動導航，統一處理 pushState）、`restoreFromUrl()`（頁面載入/重新整理時比對現有網址並渲染，取代 `main.js` 的 `restoreRouteFromUrl()`）、內部統一監聽 `popstate`（取代 `main.js` 現有的 if/else 鏈）
- 五個頁面渲染函式（`home.js` `loadHomePage`、`my-character.js` `loadMyCharacterPage`、`chat-page.js` `loadChatPage`、`character-create.js` `loadCharacterCreatePage`、`character-edit.js` `loadCharacterEditPage`）統一收斂為「純渲染函式」：只負責把內容載入 `#content-area`，不再管理 `history.pushState`/`replaceState`，history 管理全部收斂到 `router.js`
- `sidebar.js` 的 Logo／創建角色按鈕改呼叫 `router.navigateTo('/')` / `router.navigateTo('/my-characters')`，移除自己手動 `pushState` 的程式碼
- 角色卡（`home.js`）、聊天歷史清單（`conversation-history.js`）等觸發導航的地方統一改呼叫 `router.navigateTo(...)`
- **移除**：`main.js` 113-128 行一段疑似遺留的 debug 代碼（monkey-patch `window.history.pushState`/`replaceState` 印 console.log，並維護一個 `window.historyLog` 陣列）——不屬於任何現有職責，YAGNI，使用者已確認直接移除
- **不改變任何對外行為**：路徑格式、F5 重新整理還原頁面、瀏覽器上一頁/下一頁、側邊欄導航、角色卡進入聊天室的使用者可見行為全部維持不變，純內部重構

## Capabilities

### New Capabilities
- `lobby-router-module-boundaries`：定義 `persona-nexus-lobby` 前端路由邏輯的單一權威來源契約——路由表只能存在於 `router.js`，頁面渲染函式不得自行管理 history，以及拆分後對外導航行為必須與拆分前完全一致

### Modified Capabilities
（無 spec 層級行為變更——路徑格式、頁面還原邏輯、導航使用者體驗皆維持不變，僅內部模組邊界調整）

## Impact

- **受影響檔案**：`persona-nexus-lobby/src/main.js`（移除 `restoreRouteFromUrl()`、popstate 鏈、debug 代碼）、`sidebar.js`、`chat-page.js`、`character-create.js`、`character-edit.js`、`home.js`（移除 loader 內的 history 管理，改呼叫 router）；新增 `router.js`
- **不受影響**：`my-character.js`（本來就不自行管理 history，介面不變）、`api.js`、`message-utils.js`、`conversation-history.js`（除了導航呼叫方式改用 router，內部邏輯不變）、`iframe-loader.js`、`config-loader.js`、`character-tooltip.js`、`menuPosition.js`、`index.html`、`style.css`
- **無 API 變更**：不涉及後端契約
- **無依賴變更**：不新增套件
- **驗證方式**：`npm run build` 確認打包成功 + 瀏覽器手動/自動化走查（F5 重新整理各路徑、瀏覽器上一頁/下一頁、側邊欄導航、角色卡進聊天室）
