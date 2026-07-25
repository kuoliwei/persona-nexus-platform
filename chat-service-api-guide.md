# Chat-Service API 完整指南

> 根據 chat-service 源碼 (`conversationController.js`, `conversationService.js`, `app.js`) 提取的權威文件。  
> 所有端點均已由 gateway 轉發，客戶端通過 gateway (`http://localhost:8000`) 訪問。

## 認證頭部

所有受保護端點都需要：
- **`Authorization: Bearer {token}`** — JWT token（由 auth-service 發行，gateway 負責驗證）
- **`x-user-id: {userId}`** — 用戶 ID（gateway 驗證 JWT 後注入，chat-service 信任此值）

> 注意：chat-service 不再獨立驗證 JWT，完全信任 gateway 注入的 `x-user-id`。  
> 內部請求則靠 `x-internal-request: true` header 繞過 userId 驗證。

---

## 端點清單

### 1. 取得或建立對話

**路徑**
```
GET /api/conversations/character/{characterId}
```

**認證**
- 需要：`Authorization: Bearer {token}` + `x-user-id: {userId}`

**功能**
- 查詢該用戶與該角色的最新對話
- 若無對話，創建新對話（非同步）

**請求**
```bash
curl -X GET "http://localhost:8000/api/conversations/character/char_xxx" \
  -H "Authorization: Bearer {token}" \
  -H "x-user-id: {userId}"
```

**回應**

**情況 1：對話已存在且已就緒（200 OK）**
```json
{
  "status": "ready",
  "conversationId": "conv_1784988846027",
  "characterName": "角色名稱",
  "createdAt": "2026-07-25T12:34:56.000Z"
}
```

**情況 2：對話建立中（202 Accepted）**
```json
{
  "status": "preparing",
  "message": "Conversation is being prepared"
}
```
> 前端應每 2 秒輪詢該端點，直到收到 `status: "ready"` 後取得 `conversationId`。

**情況 3：對話建立失敗（503 Service Unavailable）**
```json
{
  "status": "failed",
  "message": "RAG initialization failed",
  "error": "具體錯誤信息"
}
```

**錯誤碼**
- `401` — 無效或過期 token
- `404` — 角色不存在 (`CHARACTER_NOT_FOUND`)
- `503` — RAG 初始化失敗

---

### 2. 發送訊息到指定對話（推薦用法）

**路徑**
```
POST /api/conversations/{conversationId}/messages
```

**認證**
- 需要：`Authorization: Bearer {token}` + `x-user-id: {userId}`

**功能**
- 發送文本訊息到指定對話
- **非同步 AI 生成**：立即返回 201，後端異步調用 ai-service 生成回覆
- **原子性保存**：AI 生成成功才同時保存用戶訊息 + AI 訊息（避免孤立訊息）
- **自動摘要**：未摘要訊息超過 500 字自動觸發摘要機制
- **並行保護**：同一對話正在生成回覆時拒絕新訊息（409 Conflict）

**請求**
```bash
curl -X POST "http://localhost:8000/api/conversations/conv_1784988846027/messages" \
  -H "Authorization: Bearer {token}" \
  -H "x-user-id: {userId}" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "訊息內容（必須，非空字符串）",
    "tempUserId": "temp_msg_id"  # 可選，前端樂觀更新用的臨時 ID
  }'
```

**參數說明**

| 名稱 | 型別 | 必須 | 說明 |
|------|------|------|------|
| `text` | string | ✓ | 訊息內容，不能為空 |
| `tempUserId` | string | ✗ | 前端臨時訊息 ID，用於樂觀更新。生成完成後可在 AI 生成狀態中配對到真實 ID |

**回應**

**成功（201 Created）**
```json
{
  "status": "accepted",
  "message": "Message received, AI generation in progress"
}
```
> AI 生成是異步的，前端應輪詢 `/ai-generation-status` 確認完成。

**錯誤回應**

**訊息為空（400 Bad Request）**
```json
{
  "error": "MISSING_TEXT",
  "message": "Invalid request"
}
```

**上一條訊息仍在生成中（409 Conflict）— 並行保護**
```json
{
  "error": "AI_GENERATION_IN_PROGRESS",
  "message": "上一條訊息仍在處理中，請等待回覆完成後再發送"
}
```

**AI Service 不可用（503 Service Unavailable）**
```json
{
  "error": "AI_SERVICE_UNAVAILABLE",
  "message": "具體錯誤信息（例：連線逾時、模型載入失敗等）",
  "aiGenerationStatus": {
    "status": "failed",
    "error": "具體錯誤信息"
  }
}
```

**其他錯誤**
- `401` — 無效或過期 token
- `403` — 無權存取該對話 (`FORBIDDEN`)
- `404` — 對話不存在 (`CONVERSATION_NOT_FOUND`)

---

### 3. 查詢 AI 生成狀態（前端輪詢用）

**路徑**
```
GET /api/conversations/{conversationId}/ai-generation-status
```

**認證**
- 需要：`Authorization: Bearer {token}` + `x-user-id: {userId}`

**功能**
- 查詢上一條訊息的 AI 生成狀態
- **非阻塞**：立即返回，不等待 AI 完成

**請求**
```bash
curl -X GET "http://localhost:8000/api/conversations/conv_1784988846027/ai-generation-status" \
  -H "Authorization: Bearer {token}" \
  -H "x-user-id: {userId}"
```

**回應**

**未生成或已完成清除（200 OK）**
```json
{
  "status": "idle"
}
```

**生成中（200 OK）**
```json
{
  "status": "generating"
}
```

**生成完成（200 OK）— 包含訊息 ID 配對**
```json
{
  "status": "completed",
  "generationTempUserId": "temp_msg_id",  # 對應的前端臨時 ID（若有）
  "generationUserMessageId": "msg_xxx",   # 用戶訊息的真實 ID
  "generationAssistantMessageId": "msg_yyy",  # AI 回覆的真實 ID
  "generationUpdatedAt": "2026-07-25T12:35:00.000Z"
}
```
> 前端可用 `generationTempUserId` 配對到樂觀更新的訊息，用真實 ID 更新。

**生成失敗（200 OK）**
```json
{
  "status": "failed",
  "generationError": "具體錯誤信息"
}
```

**輪詢建議**
```javascript
// 偽代碼：前端輪詢邏輯
async function waitForAIGeneration(conversationId, maxAttempts = 120) {
  for (let i = 0; i < maxAttempts; i++) {
    const status = await fetch(
      `/api/conversations/${conversationId}/ai-generation-status`,
      { headers: { Authorization, 'x-user-id' } }
    ).then(r => r.json());

    if (status.status === 'completed') {
      console.log('✅ AI 生成完成', status);
      return status;
    }
    if (status.status === 'failed') {
      console.error('❌ AI 生成失敗', status.generationError);
      throw new Error(status.generationError);
    }
    // status === 'idle' 或 'generating'
    await new Promise(r => setTimeout(r, 1000)); // 等待 1 秒
  }
  throw new Error('生成逾時（>2 分鐘）');
}
```

---

### 4. 獲取對話的所有訊息

**路徑**
```
GET /api/conversations/{conversationId}/messages
```

**認證**
- 需要：`Authorization: Bearer {token}` + `x-user-id: {userId}`

**功能**
- 分頁查詢對話的所有訊息（包含已摘要的歷史記錄）
- 支持分頁（`limit`、`offset`）

**請求**
```bash
curl -X GET "http://localhost:8000/api/conversations/conv_1784988846027/messages?limit=50&offset=0" \
  -H "Authorization: Bearer {token}" \
  -H "x-user-id: {userId}"
```

**查詢參數**

| 名稱 | 型別 | 預設 | 說明 |
|------|------|------|------|
| `limit` | number | 50 | 每頁訊息數 |
| `offset` | number | 0 | 跳過的訊息數（分頁用） |

**回應（200 OK）**
```json
[
  {
    "id": "msg_1784988900001",
    "conversationId": "conv_1784988846027",
    "role": "user",  # "user" 或 "assistant"
    "text": "訊息內容",
    "status": "completed",
    "summarized": false,  # 是否已被摘要覆蓋
    "summaryId": null,    # 如果被摘要，此為摘要的 ID（Qdrant point id）
    "createdAt": "2026-07-25T12:34:56.000Z",
    "updatedAt": "2026-07-25T12:34:56.000Z"
  },
  {
    "id": "msg_1784988900002",
    "conversationId": "conv_1784988846027",
    "role": "assistant",
    "text": "AI 回覆",
    "status": "completed",
    "summarized": true,
    "summaryId": "summary_abc123",  # 已被摘要
    "createdAt": "2026-07-25T12:34:58.000Z",
    "updatedAt": "2026-07-25T12:34:58.000Z"
  }
]
```

**訊息欄位說明**

| 欄位 | 說明 |
|------|------|
| `role` | 訊息角色：`"user"` 或 `"assistant"` |
| `summarized` | 是否已被摘要機制涵蓋（`true` 時訊息內容已被濃縮到 RAG 摘要） |
| `summaryId` | 涵蓋此訊息的摘要 ID（Qdrant collection 中的 point id），`null` 表示未被摘要 |
| `status` | 訊息狀態（通常為 `"completed"`） |

**錯誤碼**
- `401` — 無效 token
- `403` — 無權存取對話
- `404` — 對話不存在

---

### 5. 刪除訊息（回溯式刪除）

**路徑**
```
DELETE /api/conversations/{conversationId}/messages/{messageId}
```

**認證**
- 需要：`Authorization: Bearer {token}` + `x-user-id: {userId}`

**功能**
- 刪除指定用戶訊息及其後的所有訊息（回溯式）
- 若刪除範圍涉及已摘要訊息，會自動清理 Qdrant 對應摘要
- 支持「標回未摘要」：若刪除點前的訊息被同一摘要涵蓋，會檢查刪除範圍是否切中摘要中段，決定是否標回 `summarized: false`

**請求**
```bash
curl -X DELETE "http://localhost:8000/api/conversations/conv_1784988846027/messages/msg_1784988900010" \
  -H "Authorization: Bearer {token}" \
  -H "x-user-id: {userId}"
```

**回應（200 OK）**
```json
{
  "success": true,
  "message": "5 則訊息已刪除",
  "deletedCount": 5,
  "deletedIds": [
    "msg_1784988900010",
    "msg_1784988900011",
    "msg_1784988900012",
    "msg_1784988900013",
    "msg_1784988900014"
  ]
}
```

**錯誤回應**

**AI 正在生成中（409 Conflict）— 並行保護**
```json
{
  "error": "AI_GENERATION_IN_PROGRESS",
  "message": "AI 正在回覆中，請等待回覆完成後再刪除"
}
```

**摘要清理失敗（503 Service Unavailable）— RAG 異常**
```json
{
  "error": "SERVICE_ERROR",
  "message": "記憶清理失敗，訊息未刪除: 具體錯誤信息"
}
```

**其他錯誤**
- `401` — 無效 token
- `403` — 無權存取對話
- `404` — 對話或訊息不存在
- `400` — 非用戶訊息（如嘗試刪除 AI 訊息）

**刪除邏輯詳解**

1. **擁有權檢查**：確認 userId 與對話的 userId 一致
2. **並行防護**：若有 AI 生成中，拒絕刪除（409）
3. **回溯式刪除**：
   - 找到指定 messageId 的訊息（必須是 `role: user`）
   - 刪除該訊息及其後所有訊息
4. **摘要聯動**：
   - 若刪除範圍涵蓋已摘要訊息 → 自動刪除 Qdrant 中對應的摘要點
   - 若刪除點切在某摘要的中段 → 該摘要會被刪除，其前面的訊息標回 `summarized: false`（供後續新摘要重新涵蓋）
5. **DB 事務**：確保訊息和摘要狀態同步

---

### 6. 清除 AI 生成狀態

**路徑**
```
DELETE /api/conversations/{conversationId}/ai-generation-status
```

**認證**
- 需要：`Authorization: Bearer {token}` + `x-user-id: {userId}`

**功能**
- 清除對話的 AI 生成狀態
- 用於用戶重試或手動糾正失敗狀態

**請求**
```bash
curl -X DELETE "http://localhost:8000/api/conversations/conv_1784988846027/ai-generation-status" \
  -H "Authorization: Bearer {token}" \
  -H "x-user-id: {userId}"
```

**回應（200 OK）**
```json
{
  "success": true,
  "message": "生成狀態已清除"
}
```

**錯誤碼**
- `401` — 無效 token
- `403` — 無權存取對話
- `404` — 對話不存在

---

### 7. 取得對話摘要（輕量版）

**路徑**
```
GET /api/conversations/summary
```

**認證**
- 需要：`Authorization: Bearer {token}` + `x-user-id: {userId}`

**功能**
- 查詢當前用戶的所有對話摘要
- 僅包含對話 ID、角色名、更新時間（輕量版）

**請求**
```bash
curl -X GET "http://localhost:8000/api/conversations/summary" \
  -H "Authorization: Bearer {token}" \
  -H "x-user-id: {userId}"
```

**回應（200 OK）**
```json
[
  {
    "id": "conv_1784988846027",
    "characterName": "角色名稱",
    "updatedAt": "2026-07-25T12:35:00.000Z"
  },
  {
    "id": "conv_1784988846028",
    "characterName": "另一個角色",
    "updatedAt": "2026-07-25T12:36:00.000Z"
  }
]
```

**錯誤碼**
- `401` — 無效 token

---

### 8. 取得所有對話（完整版）

**路徑**
```
GET /api/conversations
```

**認証**
- 需要：`Authorization: Bearer {token}` + `x-user-id: {userId}`

**功能**
- 查詢當前用戶的所有對話
- 包含對話詳情 + 最新一則訊息

**請求**
```bash
curl -X GET "http://localhost:8000/api/conversations" \
  -H "Authorization: Bearer {token}" \
  -H "x-user-id: {userId}"
```

**回應（200 OK）**
```json
[
  {
    "id": "conv_1784988846027",
    "characterName": "角色名稱",
    "characterGender": "female",
    "createdAt": "2026-07-25T12:30:00.000Z",
    "latestMessage": {
      "id": "msg_xxx",
      "role": "assistant",
      "text": "最新訊息的內容",
      "createdAt": "2026-07-25T12:35:00.000Z"
    }
  }
]
```

---

### 9. 刪除單個對話

**路徑**
```
DELETE /api/conversations/{conversationId}
```

**認証**
- 需要：`Authorization: Bearer {token}` + `x-user-id: {userId}`

**功能**
- 刪除單個對話
- **順序**：先清理 RAG（Qdrant 摘要），再刪 DB（原子性）
- 若 RAG 清理失敗，整個操作失敗，DB 不被修改

**請求**
```bash
curl -X DELETE "http://localhost:8000/api/conversations/conv_1784988846027" \
  -H "Authorization: Bearer {token}" \
  -H "x-user-id: {userId}"
```

**回應（200 OK）**
```json
{
  "success": true,
  "message": "Conversation deleted successfully"
}
```

**錯誤回應**

**RAG 清理失敗（503 Service Unavailable）**
```json
{
  "error": "SERVICE_ERROR",
  "message": "RAG 清理失敗，聊天室未刪除: 具體錯誤信息"
}
```

**其他錯誤**
- `401` — 無效 token
- `403` — 無權刪除對話
- `404` — 對話不存在

---

### 10. 刪除某角色的所有對話

**路徑**
```
DELETE /api/conversations/character/{characterId}
```

**認証**
- 需要：`Authorization: Bearer {token}` + `x-user-id: {userId}`

**功能**
- 刪除當前用戶與指定角色的所有對話
- 同樣先清 RAG 再刪 DB

**請求**
```bash
curl -X DELETE "http://localhost:8000/api/conversations/character/char_xxx" \
  -H "Authorization: Bearer {token}" \
  -H "x-user-id: {userId}"
```

**回應（200 OK）**
```json
{
  "success": true,
  "message": "All conversations for this character deleted",
  "deletedCount": 3
}
```

**錯誤碼**
- `401` — 無效 token
- `404` — 角色不存在或無對話可刪

---

## 關鍵設計原則

### 1. 非同步 AI 生成（Section 5 測試的核心）

- **發送訊息**：返回 201 accepted，後端異步調用 AI
- **前端輪詢**：使用 `GET /ai-generation-status` 檢查完成狀態
- **原子性**：AI 成功後才同時存用戶訊息 + AI 訊息，失敗時不留孤立訊息
- **配對資訊**：生成完成時返回 `generationTempUserId` ↔ 真實 ID 的映射

### 2. 摘要機制

**觸發條件**（config.json）
```json
{
  "summary": {
    "threshold": 500,        // 觸發門檻（字數）
    "shortTermLimit": 2      // 保留的最新訊息數（不計入摘要）
  }
}
```

**邏輯**
1. 發送訊息後，計算未摘要訊息（排除最新 2 條）的總字數
2. 若 ≥ 500 字，自動調用 ai-service 生成摘要
3. 生成的摘要存入 Qdrant，訊息標記 `summarized: true`, `summaryId: xxx`
4. 短期記憶只保留最新 2 條未摘要訊息 + RAG 摘要

**查詢工具**
- `list-summaries.ps1 {conversationId}` — 列出所有摘要及涵蓋的訊息

### 3. 並行保護

- 同一對話不能同時進行多個 AI 生成任務
- 新訊息時檢查 `generationStatus`，若為 `generating` 且未逾時則拒絕（409）
- 刪除訊息時也檢查，若正在生成則拒絕（409）

### 4. 擁有權檢查

- 所有操作都先通過 `assertConversationOwnership()` 檢查
- userId 與對話的 userId 必須一致
- 內部請求（`x-internal-request: true`）可繞過該檢查

---

## 測試用例模板（Section 5 示例）

### Case 17-18：觸發第 1 次摘要

```bash
# 變數
CONVERSATION_ID="conv_1784988846027"
USER_ID="usr_1784986174926"
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
GATEWAY="http://localhost:8000"

# 發送訊息（重複 5-10 次以累積字數）
curl -X POST "$GATEWAY/api/conversations/$CONVERSATION_ID/messages" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-user-id: $USER_ID" \
  -H "Content-Type: application/json" \
  -d '{"text":"至少 100 字以上的訊息內容，重複發送多次累積..."}'

# 輪詢 AI 生成狀態（每秒查 1 次，直到 completed 或 failed）
curl -X GET "$GATEWAY/api/conversations/$CONVERSATION_ID/ai-generation-status" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-user-id: $USER_ID"

# 驗證摘要觸發（在 chat-service 目錄運行）
cd chat-service
powershell -File ../list-summaries.ps1 "$CONVERSATION_ID"
# 預期：摘要數從 0 變成 1
```

### Case 21-23：刪除與聯動

```bash
# 刪除第 2 份摘要的最早訊息
MESSAGE_ID="msg_1784988900010"
curl -X DELETE "$GATEWAY/api/conversations/$CONVERSATION_ID/messages/$MESSAGE_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-user-id: $USER_ID"

# 驗證摘要聯動
powershell -File ../list-summaries.ps1 "$CONVERSATION_ID"
# 預期：摘要數從 2 變回 1，第 2 份摘要被刪除，第 1 份保留

# 驗證訊息刪除
curl -X GET "$GATEWAY/api/conversations/$CONVERSATION_ID/messages" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-user-id: $USER_ID"
# 預期：刪除點之後的訊息全部消失
```

---

## 常見錯誤與解決方案

### 1. "Invalid or expired token"

**原因**：token 已過期（JWT exp 時間戳 < 當前時間）

**解決**：重新登入 `/api/auth/login` 獲取新 token

### 2. "Invalid request" 但無詳細信息

**原因**：可能是 `text` 欄位為空或不存在

**解決**：確認 POST body 包含非空的 `"text": "..."`

### 3. "上一條訊息仍在處理中"（409）

**原因**：對話正在生成 AI 回覆，並行保護拒絕了新訊息

**解決**：等待上一條訊息完成（輪詢 `ai-generation-status` 直到 `status !== "generating"`）

### 4. "記憶清理失敗"（503）刪除訊息時

**原因**：ai-service 或 Qdrant 不可用，RAG 清理失敗

**解決**：
- 檢查 Qdrant 服務狀態（`curl http://localhost:6333/health`）
- 檢查 ai-service 日誌
- 待服務恢復後重試

### 5. 發送訊息後沒收到 AI 回覆

**可能原因**
1. 前端未輪詢 `ai-generation-status`
2. AI Service 繁忙或超時（檢查 chat-service 日誌）
3. 對話建立不完整（status 仍為 preparing）

**排查步驟**
```bash
# 1. 確認對話已就緒
curl -X GET "$GATEWAY/api/conversations/character/{characterId}" ...
# → status 應為 "ready"，且有 conversationId

# 2. 檢查 AI 生成狀態
curl -X GET "$GATEWAY/api/conversations/$CONVERSATION_ID/ai-generation-status" ...
# → status 應為 completed 或 failed

# 3. 檢查訊息列表
curl -X GET "$GATEWAY/api/conversations/$CONVERSATION_ID/messages" ...
# → 應包含用戶訊息 + AI 回覆 2 條（或更多前序訊息）
```

---

## 相關文件

- **源碼**：`chat-service/src/controllers/conversationController.js`、`conversationService.js`
- **配置**：`chat-service/src/config/config.json`（摘要門檻等）
- **路由**：`chat-service/src/app.js`
- **數據庫模型**：`chat-service/prisma/schema.prisma`
