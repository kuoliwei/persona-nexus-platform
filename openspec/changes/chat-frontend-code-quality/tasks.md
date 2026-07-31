## 1. 抽取 messageFormatter.js（純函式，零依賴）

- [x] 1.1 建立 `src/messageFormatter.js`，搬移 `escapeHtml()` 與 `formatMessageText()`（原 chat.js 97-111 行），維持函式簽名與邏輯不變
- [x] 1.2 `chat.js` 改為 `import { escapeHtml, formatMessageText } from './messageFormatter.js'`，移除原本的函式定義
- [x] 1.3 `npm run build` 確認打包成功
- [x] 1.4 瀏覽器走查：訊息文字含括弧敘事樣式正常渲染，含特殊字元的訊息不產生 XSS

## 2. 抽取 messageStore.js（訊息陣列的唯一寫入點）

- [x] 2.1 建立 `src/messageStore.js`，實作 `createMessageStore(initialMessages)` 工廠函式，提供 `getAll()`／`setAll()`／`push()`／`replaceOrPush()`／`removeByIds()`／`findById()`
- [x] 2.2 `replaceOrPush()` 邏輯照搬原 `replaceOrPushMessage()`（chat.js 124-133 行），`makeFailureMessage()`（113-122 行）一併搬到此檔案作為輔助函式
- [x] 2.3 `chat.js` 的 `initChat()` 內建立 `const store = createMessageStore()` 取代原本的 `let messages = []`
- [x] 2.4 `deleteMessage()`（136-174 行）內直接操作 `messages` 陣列的地方改為呼叫 `store.removeByIds()`——**實作調整**：`deleteMessage()` 本身連同重啟/初始化一併歸入 `conversationManager.js`（而非留在 chat.js），理由見 spec.md「conversationManager 封裝聊天室生命週期與對話層級的訊息操作」需求
- [x] 2.5 `renderMessages()` 內的 `getItems: () => messages` 改為 `getItems: () => store.getAll()`
- [x] 2.6 `npm run build` 確認打包成功
- [x] 2.7 瀏覽器走查：發送訊息、刪除訊息（含回溯式刪除）後畫面正確更新

## 3. 抽取 aiResponsePoller.js（輪詢與回合守門）

- [x] 3.1 建立 `src/aiResponsePoller.js`，實作 `createAiResponsePoller(deps)` 工廠函式，`deps` 包含 `{ api, token, store, onRender, onInputLock, getCharacterName }`
- [x] 3.2 搬移 `pollForAIResponse()`（原 chat.js 424-577 行）完整邏輯，**原樣保留** 412-423 行的回合守門不變式注釋
- [x] 3.3 函式內所有直接操作 `messages` 陣列的地方改用注入的 `store` 方法；所有 `messageInput.disabled`/`sendBtn.disabled` 改用 `onInputLock(true/false)`；所有讀取 `characterNameEl.textContent` 改用 `getCharacterName()`
- [x] 3.4 `chat.js` 的 `initChat()` 內建立 poller 實例，綁定對應回呼
- [x] 3.5 `npm run build` 確認打包成功
- [x] 3.6 瀏覽器走查：AI 回覆正常顯示、生成失敗顯示失敗氣泡、輪詢超時顯示失敗氣泡
- [x] 3.7 瀏覽器走查（回合守門專項）：連續快速發送兩則訊息，確認兩則訊息與各自回覆都正確顯示、不互相覆蓋消失

## 4. 抽取 messageSender.js（發送與樂觀更新）

- [x] 4.1 建立 `src/messageSender.js`，實作 `createMessageSender(deps)` 工廠函式，`deps` 包含 `{ api, token, store, onRender, onInputLock, getCharacterName, getConversationId, startPolling }`（`startPolling` 綁定到 aiResponsePoller 實例的輪詢啟動函式）
- [x] 4.2 搬移 `sendMessage()` 與 `sendMessageToBackend()`（原 chat.js 284-409 行）邏輯，直接操作陣列的地方改用 `store`
- [x] 4.3 `chat.js` 的 `initChat()` 內建立 sender 實例，`sendBtn`／`messageInput` 的事件監聽改呼叫 `sender.sendMessage(text)`（讀取與清空 `messageInput.value` 留在 chat.js 的 `handleSend()`）
- [x] 4.4 `npm run build` 確認打包成功
- [x] 4.5 瀏覽器走查：發送訊息的樂觀更新時序（使用者訊息立即顯示 → 思考中佔位符 → AI 回覆替換）與拆分前一致

## 5. 抽取 conversationManager.js（聊天室生命週期 + 對話層級訊息操作）

- [x] 5.1 建立 `src/conversationManager.js`，實作 `createConversationManager(deps)` 工廠函式，`deps` 包含 `{ api, token, store, onRender, showInitializing, hideInitializing, setCharacterName, setCharacterStatus, setConversationId, getConversationId }`
- [x] 5.2 搬移 `initializeChat()`、`pollForConversation()`、`sleep()`（原 chat.js 176-281 行）
- [x] 5.3 搬移重啟聊天室邏輯（原 chat.js 593-640 行的按鈕事件處理內容，事件綁定留在 chat.js，業務邏輯搬到 `conversationManager.restartConversation()`，回傳成功/失敗結果供 chat.js 決定是否清空輸入框）；連同 `deleteMessage()`（原 136-174 行）一併搬入本檔案
- [x] 5.4 `chat.js` 的 `initChat()` 內建立 manager 實例並呼叫 `manager.initializeChat(characterId)` 取代原本的直接呼叫
- [x] 5.5 `restartBtn` 事件監聽改為呼叫 `manager.restartConversation(characterId)`；`messagesList` 的訊息選單委派改呼叫 `manager.deleteMessage`
- [x] 5.6 `npm run build` 確認打包成功
- [x] 5.7 瀏覽器走查：開啟聊天室時的輪詢就緒流程、聊天室建立失敗時的錯誤顯示、重啟聊天室完整流程

## 6. 精簡 chat.js 為協調層

- [x] 6.1 確認 `chat.js` 只保留：DOM 元素查詢、五個模組實例的建立與依賴接線（wiring）、事件監聽器綁定（`sendBtn`、`messageInput` 的 keydown、`messagesList` 的訊息選單委派、`restartBtn`、`refreshBtn`）、`initProtagonistModal()` 呼叫
- [x] 6.2 確認 `renderMessages()`／`renderMessageItemHTML()` 仍留在 chat.js（因為需要存取 `messagesList`／`vlist` 這兩個與虛擬滾動整合的 DOM 相關狀態）
- [x] 6.3 移除所有已搬移到子模組、chat.js 內不再使用的函式定義與變數
- [x] 6.4 `npm run build` 確認打包成功，檢查產物無明顯體積異常（chat.js 655 行 → 183 行；`dist/assets/index-*.js` 21.45 kB，屬合理範圍）

## 7. 全流程回歸驗證

- [x] 7.1 完整走查：開啟聊天室（含輪詢就緒）→ 發送訊息 → 等待 AI 回覆 → 刪除一則訊息（含回溯式刪除驗證）→ 重啟聊天室 → 快速連續發送兩則訊息（回合守門）——透過 Playwright 自動化腳本對真實後端（auth/user/character/chat-service/ai-service/gateway 全部啟動）完整走查，全數通過，全程零 console error
- [x] 7.2 對照 `openspec/changes/chat-frontend-code-quality/specs/chat-frontend-module-boundaries/spec.md` 逐條確認每個 Scenario 皆通過
- [x] 7.3 `git diff` 檢查 `index.html`／`style.css`／`api.js`／`session.js`／`toast.js`／`messageMenu.js`／`protagonistModal.js`／`virtualMessageList.js` 無非預期改動
- [x] 7.4 更新 `persona-nexus-chat/CLAUDE.md` 的檔案結構清單，反映新增的 5 個模組檔案
