## Why

聊天室送出訊息後，偶發性地出現「使用者氣泡 + AI 佔位氣泡剛渲染完就一閃消失」，且該回合的 AI 回覆永遠不會出現（要重新整理才看得到）。

根因是 AI 生成狀態缺少「回合身分」：`chat-service` 的生成狀態欄位（`generationStatus` / `generationTempUserId` / `generationUserMessageId` / `generationAssistantMessageId`）持久化在 `Conversation` 表，且**只在下一次 `setCompleted` 才被整批覆寫**——`tryAcquireLock()` 上鎖時只寫 `generationStatus: 'generating'`，三個訊息 ID 欄位仍留著上一回合的值。

而前端 `pollForAIResponse()` 是在 POST 送出**之前**就啟動輪詢，第一次查詢在 t=1000ms。只要 POST 尚未在後端跑到 `tryAcquireLock()`（網路 + gateway JWT 驗證 + 擁有權查詢偶爾超過 1 秒），這次查詢讀到的就是**上一回合的 `completed` 與上一回合的訊息 ID**。前端無條件採信，於是把剛送出的使用者訊息換成上一回合的舊使用者訊息、把佔位符換成上一回合的舊 AI 回覆，並 `clearInterval` 停止輪詢。訊息陣列尾端出現與上方重複的 id，虛擬滾動以 id 為 key，重複 key 會取到同一個 DOM 節點並搬移它——視覺上兩個氣泡就這樣消失了。

因為第一則訊息時 `generationStatus` 為 null（回 `unknown`），此問題**只在第二則之後觸發**，且需要 POST 恰好慢過 1 秒，所以呈現機率性。

## What Changes

**chat-service（後端）**

- `generationStatusRepository.tryAcquireLock(conversationId, staleLimitMs, { tempUserId })` 新增第三個參數：上鎖成功時**同時**寫入本回合的 `generationTempUserId`，並把 `generationUserMessageId` / `generationAssistantMessageId` 清為 `null`。持久化分支與記憶體分支（`config.persistence.enableGenerationStatus` 兩種模式）行為一致。
- `generationStatusRepository.setFailed(conversationId, errorMessage)` 不再清掉上鎖時寫入的 `generationTempUserId`（維持本回合身分），讓失敗狀態也能被前端正確歸屬。
- 效果：`GET /ai-generation-status` 回傳的 `tempUserId` **從上鎖那一刻起**就代表「當前這一回合」，`generating` 期間不會再挾帶上一回合的訊息 ID。

**persona-nexus-chat（前端）**

- `pollForAIResponse()` 在採信 `completed` / `failed` 前先比對 `generationStatus.tempUserId === tempUserId`；不相符視為「本回合尚未在後端開始」，不動畫面、不停止輪詢、繼續下一次查詢（超時計數照舊累加）。
- **不是** BREAKING：`tempUserId` 欄位後端早已回傳，前端只是從忽略改為使用。

## Capabilities

### New Capabilities

- `ai-generation-turn-identity`: AI 生成狀態的「回合身分」契約——後端在上鎖時即標記本回合的 `tempUserId` 並清除上一回合殘留的訊息 ID；前端輪詢須以 `tempUserId` 驗證狀態歸屬後才可採信。

### Modified Capabilities

（無。平台層級 `openspec/specs/` 目前為空；`chat-service` 的 `conversations` 與 `persona-nexus-chat` 的 `chat-ui` 兩份既有 spec 屬各自 repo 的 store，本變更以新 capability 描述跨服務契約，實作完成後再由各 repo 自行同步。）

## Impact

**涉及的服務與前端**

- `chat-service` (6000)：`src/repositories/conversationRepository.js`（`tryAcquireLock` / `setFailed`）、`src/services/conversationService.js`（`sendMessageToConversation` 的呼叫點）
- `persona-nexus-chat` (5176)：`src/chat.js`（`pollForAIResponse`）

**API 契約變化**

- 無新增/移除端點，無新增/移除欄位。`GET /api/conversations/:id/ai-generation-status` 的回應**語意**收緊：`tempUserId` 在 `generating`/`completed`/`failed` 三種狀態下皆保證等於當前回合的值；`userMessageId` / `assistantMessageId` 在 `generating` 期間保證為 `undefined`（先前會殘留上一回合的值）。

**資料庫**

- 無 schema 變更、無 migration。既有欄位的寫入時機改變而已。
- 既有資料相容：DB 中殘留上一回合 ID 的資料列，會在下一次上鎖時被清除。

**向後相容性**

- 舊前端 + 新後端：舊前端不檢查 `tempUserId`，但後端已在上鎖時清掉舊 ID，`generating` 期間 `assistantMessageId` 為 `undefined` → 舊前端的 ID 配對找不到目標，退回時間篩選後備路徑（`createdAt > userMessageCreatedAt`），不會再誤用上一回合的訊息。
- 新前端 + 舊後端：新前端的 `tempUserId` 守門會擋掉不屬於本回合的狀態；代價是真實失敗時要等滿 120 秒輪詢超時才顯示失敗氣泡（因舊後端的 `setFailed` 帶著上一回合的 `tempUserId`）。兩端一起部署即無此問題。

**無自動化測試**

兩個 repo 皆無測試框架，驗證以手動瀏覽器走查 + `test.http` 為主；本變更需針對競態視窗設計可重現的驗證手段（見 design.md）。
