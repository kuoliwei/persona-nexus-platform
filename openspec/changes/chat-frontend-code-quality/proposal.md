## Why

`persona-nexus-chat` 是四個前端應用中規模最大、結構最亂的一個：`src/chat.js` 單檔 655 行，混雜了 5 個修改理由互相獨立的職責（訊息狀態管理、發送訊息、AI 回覆輪詢、聊天室生命週期管理、文本格式化）。依《程式撰寫設計原則.md》A1（模組邊界）與 B1（函數職責單一性）稽核，這違反了「一個檔案對應一個清晰職責邊界」的準則——例如修改 AI 輪詢的重試策略時完全不需要碰發送邏輯，但兩者目前寫在同一個檔案的同一個閉包內，共享 `messages`、`vlist` 等變數，修改一處經常被迫連帶檢查另一處是否受影響。

拆分依據是「修改理由是否獨立」（職責邊界），不是行數門檻——這與本平台後端服務（如 chat-service）已完成的拆分方法論一致。

## What Changes

- 新增 `src/messageStore.js`：把 `messages` 陣列的讀寫收斂為單一入口（`getMessages()`/`setMessages()`/`replaceOrPushMessage()`/`removeByIds()`），取代目前分散在 `chat.js` 三處直接操作陣列的寫法
- 新增 `src/messageFormatter.js`：把 `escapeHtml()`／`formatMessageText()` 純文本轉換工具抽出，不依賴任何 DOM 狀態
- 新增 `src/messageSender.js`：把「發送訊息＋樂觀更新＋失敗氣泡」邏輯抽出（原 `sendMessage()`／`sendMessageToBackend()`）
- 新增 `src/aiResponsePoller.js`：把「輪詢 AI 回覆＋回合守門＋ID/時間雙軌配對替換」邏輯抽出（原 `pollForAIResponse()`，含既有的回合守門不變式注釋原樣保留）
- 新增 `src/conversationManager.js`：把「初始化聊天室＋輪詢聊天室建立狀態＋重啟聊天室」三個圍繞「聊天室生命週期」同一主題的職責收斂到一起（原 `initializeChat()`／`pollForConversation()`／重啟按鈕邏輯）
- 精簡 `src/chat.js` 為協調層：只保留 DOM 元素查詢、事件綁定、把使用者操作分派給上述模組，不再包含業務邏輯
- **不改變任何對外行為**：訊息收發、輪詢間隔與超時、樂觀更新時序、回合守門判斷、重啟流程、錯誤訊息文案全部維持原樣，純內部重構

## Capabilities

### New Capabilities
- `chat-frontend-module-boundaries`：定義 `persona-nexus-chat` 前端聊天邏輯的模組職責邊界與行為保留契約——每個新模組的職責範圍，以及拆分後對外行為必須與拆分前完全一致

### Modified Capabilities
（無 spec 層級行為變更——聊天室的對外行為、API 契約、UI 互動皆維持不變，僅內部模組邊界調整）

## Impact

- **受影響檔案**：`persona-nexus-chat/src/chat.js`（655 行 → 精簡為協調層），新增 5 個模組檔案
- **不受影響**：`virtualMessageList.js`、`toast.js`、`messageMenu.js`、`protagonistModal.js`、`session.js`、`api.js`、`index.html`、`style.css`
- **無 API 變更**：不涉及後端契約、無新增/修改端點
- **無依賴變更**：不新增套件
- **驗證方式**：`npm run build` 確認打包成功 + 瀏覽器手動走查（發送訊息、AI 回覆、刪除訊息、重啟聊天室、回合守門情境）
