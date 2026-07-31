## ADDED Requirements

### Requirement: messageStore 是訊息陣列的唯一寫入點
`persona-nexus-chat` 的 `src/messageStore.js` SHALL 提供 `createMessageStore()` 工廠函式，回傳訊息陣列的讀寫方法（`getAll`、`setAll`、`push`、`replaceOrPush`、`removeByIds`、`findById`）。聊天室內任何需要新增、替換、刪除訊息的邏輯 MUST 透過這組方法操作，不得在其他模組內直接對訊息陣列做 `push`/索引賦值等原地變更。

#### Scenario: 透過 store 新增訊息
- **WHEN** 呼叫方需要新增一則訊息到目前對話
- **THEN** 呼叫方透過 `store.push(message)` 完成，訊息陣列本身不對外暴露可變參照

#### Scenario: 透過 store 依 id 替換或新增訊息
- **WHEN** 呼叫方需要用真實訊息替換佔位符（如 AI 回覆生成完成、樂觀更新的臨時訊息換成後端回傳的真實記錄）
- **THEN** 呼叫方透過 `store.replaceOrPush(id, newMessage)` 完成，若找不到對應 id 則退化為新增

### Requirement: messageFormatter 是無 DOM 依賴的純文本轉換模組
`src/messageFormatter.js` SHALL 提供 `escapeHtml(text)` 與 `formatMessageText(text)` 兩個純函式，僅依賴輸入參數與瀏覽器內建 DOM API 做逃逸轉換，不讀取任何聊天室狀態（訊息陣列、對話 ID、token）。

#### Scenario: HTML 特殊字元被逃逸
- **WHEN** 訊息文字包含 `<`、`>`、`&` 等 HTML 特殊字元
- **THEN** `escapeHtml()` 回傳逃逸後的字串，不產生可執行的 HTML 標籤

#### Scenario: 括弧內敘事文字轉換為斜體樣式
- **WHEN** 訊息文字包含全形（）或半形 () 括弧內容
- **THEN** `formatMessageText()` 回傳先逃逸再包裹 `<span class="narrative">` 的字串，括弧本身被移除

### Requirement: messageSender 封裝發送與樂觀更新，不直接操作 DOM
`src/messageSender.js` SHALL 提供 `createMessageSender(deps)` 工廠函式，封裝「發送訊息到後端＋建立樂觀更新的臨時訊息與佔位符＋啟動 AI 回覆輪詢」的完整流程。UI 副作用（渲染、輸入框禁用/啟用）MUST 透過建構時注入的回呼函式（`onRender`、`onInputLock`）觸發，不得直接查詢或操作 DOM 元素。

#### Scenario: 發送訊息時建立樂觀更新
- **WHEN** 使用者送出一則非空白訊息
- **THEN** `messageSender` 立即透過 `messageStore` 新增使用者訊息與「思考中」佔位符，並呼叫 `onRender()` 觸發畫面更新，之後才非同步呼叫後端 API

#### Scenario: 後端拒絕發送時顯示失敗氣泡
- **WHEN** 後端回傳非 2xx 狀態或請求異常
- **THEN** `messageSender` 停止對應的輪詢、將佔位符替換為失敗氣泡訊息，並呼叫 `onRender()`

### Requirement: aiResponsePoller 封裝輪詢與回合守門，維持既有不變式
`src/aiResponsePoller.js` SHALL 提供 `createAiResponsePoller(deps)` 工廠函式，封裝「輪詢 AI 生成狀態＋依 tempUserId 判斷狀態是否屬於本回合＋完成後配對真實訊息並替換佔位符」的完整流程。回合守門判斷（僅信任 `generationStatus.tempUserId` 等於本次呼叫的 `tempUserId` 才更新畫面）MUST 與拆分前的行為完全一致，不因搬移程式碼而改變判斷條件或輪詢間隔。

#### Scenario: 狀態不屬於本回合時不更新畫面
- **WHEN** 輪詢查詢到的生成狀態的 `tempUserId` 與呼叫時傳入的 `tempUserId` 不相符
- **THEN** `aiResponsePoller` 不修改訊息陣列、不停止輪詢，等待下一次查詢

#### Scenario: AI 回覆生成完成時替換佔位符
- **WHEN** 輪詢查詢到本回合的生成狀態為 `completed`
- **THEN** `aiResponsePoller` 優先用後端回傳的 ID 配對資訊尋找對應的真實訊息並替換佔位符與臨時使用者訊息，找不到配對資訊時退回時間篩選後備邏輯，替換後停止輪詢並呼叫 `onInputLock(false)`

### Requirement: conversationManager 封裝聊天室生命週期與對話層級的訊息操作
`src/conversationManager.js` SHALL 提供 `createConversationManager(deps)` 工廠函式，封裝「初始化聊天室（載入角色資訊＋輪詢對話建立狀態）」「重啟聊天室（刪除舊對話＋重新走初始化流程）」與「刪除訊息（回溯式：該訊息及其後所有訊息一併刪除）」三個職責。三者的共通點是都以「已知 conversationId」為前提去修改對話整體內容，且初始化與重啟共用同一套輪詢邏輯（`pollForConversation`）。

#### Scenario: 初始化時輪詢直到聊天室就緒或失敗
- **WHEN** 聊天室頁面載入且提供有效的 characterId
- **THEN** `conversationManager` 輪詢對話建立狀態直到收到 200（就緒）或 503（失敗）或達到最大嘗試次數，就緒時回傳對話資料，其餘情況回傳 null

#### Scenario: 重啟聊天室複用建立流程
- **WHEN** 使用者確認重啟聊天室
- **THEN** `conversationManager` 先刪除既有對話，成功後呼叫與初始化相同的輪詢邏輯建立新對話，成功時回傳新對話資料，失敗時顯示 toast 並回傳 null（供呼叫方判斷是否清空輸入框等後續 UI 動作）

#### Scenario: 刪除訊息採回溯式刪除
- **WHEN** 使用者透過訊息選單確認刪除一則訊息
- **THEN** `conversationManager` 呼叫刪除 API，成功後用後端回傳的 `deletedIds` 透過 `store.removeByIds()` 從本地狀態移除對應訊息（含該訊息之後的所有訊息），並呼叫 `onRender()`；AI 生成中時（409）顯示 toast 且不修改本地狀態

### Requirement: chat.js 拆分後不改變對外可觀察行為
拆分完成後，`persona-nexus-chat` 的使用者可觀察行為（訊息收發時序、AI 回覆輪詢間隔與超時、刪除訊息的回溯式行為、重啟聊天室流程、錯誤訊息文案、鍵盤快捷鍵）SHALL 與拆分前完全一致。

#### Scenario: 拆分前後行為一致性驗證
- **WHEN** 對拆分後的 `persona-nexus-chat` 執行手動走查（發送訊息、等待 AI 回覆、刪除訊息、重啟聊天室、快速連續發送兩則訊息觀察回合守門）
- **THEN** 所有情境的畫面表現與錯誤訊息與拆分前一致，`npm run build` 成功產出無錯誤
