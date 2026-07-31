## ADDED Requirements

### Requirement: router.js 是路由表的唯一權威來源
`persona-nexus-lobby` 的 `src/router.js` SHALL 持有唯一一份「路徑 ↔ 頁面 ↔ 渲染函式」的路由表。任何其他模組不得自行維護路徑與頁面渲染函式的對照關係（例如用字串比對或正則獨立判斷應該渲染哪個頁面）。

#### Scenario: 新增路由只需修改一處
- **WHEN** 開發者需要新增一個路由
- **THEN** 只需在 `router.js` 的路由表新增一筆項目，不需要修改 `main.js`、`sidebar.js`、任何頁面渲染模組

### Requirement: 頁面渲染函式不得自行管理瀏覽器 history
`home.js` 的 `loadHomePage`、`my-character.js` 的 `loadMyCharacterPage`、`chat-page.js` 的 `loadChatPage`、`character-create.js` 的 `loadCharacterCreatePage`、`character-edit.js` 的 `loadCharacterEditPage` 五個渲染函式 SHALL 只負責把內容渲染進 `#content-area`（或對應 iframe），不得呼叫 `history.pushState`/`history.replaceState`。History 讀寫 MUST 只發生在 `router.js` 內。

#### Scenario: 渲染函式被 popstate 觸發時不產生額外的 history 紀錄
- **WHEN** 使用者按瀏覽器上一頁/下一頁觸發 `popstate` 事件
- **THEN** `router.js` 呼叫對應頁面的渲染函式渲染畫面，過程中不呼叫任何 `history.pushState`/`replaceState`，瀏覽器原生的 history 堆疊不受影響

### Requirement: navigateTo 是主動導航的唯一入口
`router.js` SHALL 提供 `navigateTo(path)` 函式，作為使用者主動觸發導航（側邊欄按鈕、角色卡點擊、選單項目等）的唯一入口。呼叫方 MUST NOT 自行動態 `import()` 頁面渲染模組並手動呼叫其函式來達成導航效果。

#### Scenario: 呼叫 navigateTo 完成渲染與 history 推送
- **WHEN** 使用者點擊觸發導航的 UI 元素（如側邊欄 Logo、角色卡）
- **THEN** 呼叫方呼叫 `router.navigateTo(path)`，`router.js` 內部完成比對路由、渲染頁面、`pushState` 三個步驟

#### Scenario: 重複導航到同一狀態不重複渲染
- **WHEN** `navigateTo(path)` 被呼叫，且目前 `history.state` 已經對應同一個頁面與參數
- **THEN** `router.js` 不重複渲染、不重複 `pushState`

### Requirement: restoreFromUrl 處理頁面載入與重新整理時的路徑還原
`router.js` SHALL 提供 `restoreFromUrl()` 函式，在應用初始化時呼叫一次，依目前 `window.location` 比對路由表並渲染對應頁面，使用 `replaceState` 正規化 history 狀態物件的結構。

#### Scenario: 重新整理任一已知路徑都正確還原對應頁面
- **WHEN** 使用者在 `/`、`/my-characters`、`/my-characters/create`、`/my-characters/edit?id=X`、`/rooms/X` 任一路徑按 F5 重新整理
- **THEN** `restoreFromUrl()` 渲染出與該路徑對應的頁面，行為與重構前一致

#### Scenario: 已知路徑但缺少必要參數時顯示錯誤並回首頁
- **WHEN** 使用者直接造訪 `/my-characters/edit`（缺少 `id` query 參數）
- **THEN** `router.js` 渲染首頁、將網址正規化為 `/`，並顯示「缺少角色 ID」的錯誤訊息，與重構前行為一致

### Requirement: 拆分後不改變對外可觀察的導航行為
路由邏輯聚合完成後，`persona-nexus-lobby` 的使用者可觀察行為（路徑格式、F5 重新整理還原頁面、瀏覽器上一頁/下一頁、側邊欄導航、角色卡進入聊天室、創建/編輯角色的導航流程）SHALL 與聚合前完全一致。

#### Scenario: 完整導航流程回歸驗證
- **WHEN** 對聚合後的 `persona-nexus-lobby` 執行手動或自動化走查（首頁 → 我的角色 → 創建角色 → 返回 → 編輯角色 → 返回 → 進入聊天室 → 瀏覽器上一頁/下一頁 → 各路徑 F5 重新整理）
- **THEN** 所有情境的畫面表現與網址列狀態與聚合前一致，`npm run build` 成功產出無錯誤
