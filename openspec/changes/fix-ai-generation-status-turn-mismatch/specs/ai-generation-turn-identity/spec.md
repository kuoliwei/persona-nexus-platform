## ADDED Requirements

### Requirement: 生成狀態必須在上鎖時即標記本回合身分

`chat-service` 的 `generationStatusRepository.tryAcquireLock()` 在成功取得生成鎖時，除了將 `generationStatus` 設為 `generating`，MUST 同時把本回合的 `tempUserId`（由 `POST /api/v1/conversations/:conversationId/messages` 的 request body 帶入）寫入 `generationTempUserId`，並將 `generationUserMessageId` 與 `generationAssistantMessageId` 清為 `null`。

搶鎖失敗（回傳 `false`）時 MUST NOT 修改任何生成狀態欄位。

本需求在 `config.persistence.enableGenerationStatus` 為 `true`（Prisma 持久化）與 `false`（進程內記憶體 Map）兩種模式下 MUST 表現一致。

#### Scenario: 上鎖時清除上一回合殘留的訊息 ID

- **GIVEN** 聊天室 `conv_1` 的生成狀態為上一回合完成後留下的
  ```json
  {
    "generationStatus": "completed",
    "generationTempUserId": "temp_A",
    "generationUserMessageId": "u_A",
    "generationAssistantMessageId": "a_A"
  }
  ```
- **WHEN** 使用者以 `tempUserId: "temp_B"` 送出新訊息，後端執行 `tryAcquireLock(conv_1, staleLimitMs, { tempUserId: 'temp_B' })` 並成功取得鎖
- **THEN** `conv_1` 的生成狀態 MUST 變為
  ```json
  {
    "generationStatus": "generating",
    "generationError": null,
    "generationTempUserId": "temp_B",
    "generationUserMessageId": null,
    "generationAssistantMessageId": null
  }
  ```

#### Scenario: 搶鎖失敗不得污染他人回合的狀態

- **GIVEN** 聊天室 `conv_1` 正處於 `generating`、`generationTempUserId` 為 `temp_B`，且未超過殭屍鎖時限
- **WHEN** 另一個請求以 `tempUserId: "temp_C"` 呼叫 `tryAcquireLock(conv_1, ...)`
- **THEN** 回傳值 MUST 為 `false`
- **AND** `conv_1` 的 `generationTempUserId` MUST 仍為 `temp_B`（不得被 `temp_C` 覆寫）
- **AND** 呼叫端 MUST 拋出 `AI_GENERATION_IN_PROGRESS`，controller 轉為 HTTP 409

#### Scenario: 兩種持久化模式行為一致

- **GIVEN** 同一組操作序列（上鎖 → 讀取 → 完成／失敗）
- **WHEN** 分別在 `config.persistence.enableGenerationStatus` 為 `true` 與 `false` 的環境執行
- **THEN** `generationStatusRepository.get()` 在每個步驟後回傳的 `status` / `tempUserId` / `userMessageId` / `assistantMessageId` 四個欄位 MUST 完全相同

#### Scenario: 未提供 tempUserId 時仍可上鎖

- **GIVEN** 呼叫端（例如未帶 `tempUserId` 的舊版前端或內部請求）送出訊息
- **WHEN** 執行 `tryAcquireLock(conv_1, staleLimitMs, { tempUserId: undefined })` 並成功取得鎖
- **THEN** `generationTempUserId` MUST 被寫為 `null`
- **AND** `generationUserMessageId` 與 `generationAssistantMessageId` MUST 仍被清為 `null`

---

### Requirement: 失敗狀態必須保留本回合身分

`generationStatusRepository.setFailed()` 在寫入 `generationStatus: 'failed'` 與 `generationError` 時，MUST NOT 清除或覆寫 `generationTempUserId`——該欄位已於上鎖時標記本回合，失敗狀態必須沿用它，否則前端無法判斷這個失敗屬於哪一回合。

#### Scenario: 生成失敗後狀態仍可歸屬到本回合

- **GIVEN** 聊天室 `conv_1` 已以 `tempUserId: "temp_B"` 上鎖，狀態為 `generating`
- **WHEN** `_generateAIResponseAsync` 呼叫 ai-service 失敗，執行 `setFailed(conv_1, "AI service timeout")`
- **THEN** `GET /api/v1/conversations/conv_1/ai-generation-status` MUST 回傳
  ```json
  {
    "status": "failed",
    "error": "AI service timeout",
    "tempUserId": "temp_B",
    "timestamp": 1785000000000
  }
  ```
- **AND** 回應 MUST NOT 包含 `userMessageId` 或 `assistantMessageId`（兩者為 `null`，序列化時省略）

---

### Requirement: 生成狀態查詢回應的回合歸屬保證

`GET /api/v1/conversations/:conversationId/ai-generation-status`（對外經 gateway 為 `GET /api/conversations/:conversationId/ai-generation-status`）的回應 MUST 滿足下列保證：

- 當 `status` 為 `generating`、`completed` 或 `failed` 時，`tempUserId` MUST 代表**當前這一回合**送出的臨時 ID（若該回合未提供則為 `undefined`），MUST NOT 是任何先前回合的值。
- 當 `status` 為 `generating` 時，`userMessageId` 與 `assistantMessageId` MUST 為 `undefined`。
- 當 `status` 為 `completed` 時，`userMessageId` 與 `assistantMessageId` MUST 指向本回合實際寫入 DB 的兩筆訊息。
- 當聊天室從未有過生成記錄時，回應 MUST 為 `{ "status": "unknown", "message": "No generation status record" }`。

#### Scenario: generating 期間不得挾帶上一回合的訊息 ID

- **GIVEN** 聊天室 `conv_1` 上一回合完成，`generationAssistantMessageId` 為 `a_A`
- **WHEN** 新回合（`tempUserId: "temp_B"`）已上鎖但 AI 尚未生成完成，前端查詢 `GET /api/conversations/conv_1/ai-generation-status`
- **THEN** 回應 MUST 為
  ```json
  { "status": "generating", "tempUserId": "temp_B", "timestamp": 1785000000000 }
  ```
- **AND** 回應 MUST NOT 包含 `assistantMessageId: "a_A"`

#### Scenario: 完成時回傳本回合的完整配對資訊

- **GIVEN** 聊天室 `conv_1` 的回合 `temp_B` 生成成功，使用者訊息寫入為 `u_B`、AI 回覆寫入為 `a_B`
- **WHEN** 前端查詢生成狀態
- **THEN** 回應 MUST 為
  ```json
  {
    "status": "completed",
    "tempUserId": "temp_B",
    "userMessageId": "u_B",
    "assistantMessageId": "a_B",
    "timestamp": 1785000000000
  }
  ```

---

### Requirement: 前端輪詢必須驗證狀態歸屬後才可採信

`persona-nexus-chat` 的 `pollForAIResponse()` 在依據 `completed` 或 `failed` 狀態變更畫面之前，MUST 先比對回應的 `tempUserId` 是否等於本回合送出的 `tempUserId`。

不相符時 MUST 全部滿足：

- MUST NOT 替換使用者訊息氣泡或佔位符氣泡
- MUST NOT 呼叫 `clearInterval` 停止輪詢
- MUST NOT 解除輸入框與送出鍵的禁用狀態
- MUST 照常累加 `attempts`，使超時保護維持絕對時間上限
- SHOULD 於 console 印出期望值與實際值，便於診斷

#### Scenario: 讀到上一回合的 completed 時不動畫面

- **GIVEN** 使用者送出訊息，本回合 `tempUserId` 為 `temp_B`，畫面上已有 `temp_B` 使用者氣泡與 `placeholder_*` 佔位氣泡
- **AND** 後端因 POST 尚未抵達，仍回傳上一回合的狀態 `{ "status": "completed", "tempUserId": "temp_A", "userMessageId": "u_A", "assistantMessageId": "a_A" }`
- **WHEN** 第一次輪詢取得該回應
- **THEN** `messages` 陣列 MUST 維持不變（`temp_B` 與佔位符皆保留原內容）
- **AND** 輪詢 MUST 繼續進行
- **AND** 輸入框與送出鍵 MUST 維持禁用

#### Scenario: 讀到本回合的 completed 時正常替換

- **GIVEN** 本回合 `tempUserId` 為 `temp_B`
- **WHEN** 輪詢取得 `{ "status": "completed", "tempUserId": "temp_B", "userMessageId": "u_B", "assistantMessageId": "a_B" }`
- **THEN** `temp_B` 臨時使用者訊息 MUST 被 `u_B` 的真實記錄取代
- **AND** 佔位符 MUST 被 `a_B` 的 AI 回覆取代
- **AND** 輪詢 MUST 停止，輸入框與送出鍵 MUST 解除禁用

#### Scenario: 讀到本回合的 failed 時顯示失敗氣泡

- **GIVEN** 本回合 `tempUserId` 為 `temp_B`
- **WHEN** 輪詢取得 `{ "status": "failed", "error": "AI service timeout", "tempUserId": "temp_B" }`
- **THEN** 使用者訊息氣泡 MUST 保留
- **AND** 佔位符 MUST 被失敗氣泡取代，內容包含後端回傳的 `error`
- **AND** 輪詢 MUST 停止，輸入框與送出鍵 MUST 解除禁用

#### Scenario: 守門不符但已達輪詢上限時仍須收尾

- **GIVEN** 本回合 `tempUserId` 為 `temp_B`，而後端始終未上鎖（POST 徹底遺失）
- **WHEN** 輪詢達到第 120 次，取得的狀態仍不屬於 `temp_B`
- **THEN** 佔位符 MUST 被逾時失敗氣泡取代
- **AND** 輪詢 MUST 停止，輸入框與送出鍵 MUST 解除禁用

---

### Requirement: 送出的訊息不得因輪詢時序而從畫面消失

在任何輪詢與後端上鎖的時序組合下，使用者送出訊息後樂觀渲染的兩個氣泡（使用者訊息、AI 佔位符）MUST 持續存在於畫面上，直到被**本回合**的真實資料或失敗訊息取代。

前端 `messages` 陣列在任何時刻 MUST NOT 含有重複的訊息 `id`——虛擬滾動以 `id` 為 key，重複 key 會導致同一 DOM 節點被搬移、氣泡從畫面消失。

#### Scenario: 後端上鎖延遲 3 秒仍不影響畫面

- **GIVEN** 在 `sendMessageToConversation` 的 `tryAcquireLock` 之前人為插入 3 秒延遲，使每次送訊息都必定落入舊的競態視窗
- **AND** 聊天室已有至少一回合完成的對話（`generationStatus` 為 `completed`）
- **WHEN** 使用者送出第二則訊息
- **THEN** 兩個氣泡 MUST 在整個延遲期間持續顯示，佔位符文字維持「正在思考中...」
- **AND** AI 生成完成後，佔位符 MUST 被本回合的 AI 回覆取代
- **AND** `messages` 陣列 MUST NOT 出現重複 id
