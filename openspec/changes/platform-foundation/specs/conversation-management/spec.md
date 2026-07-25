## 新增需求

> ⚠️ 2026-07-25 部分更新：本檔案原本描述的是簡化過的同步訊息模型，與 `chat-service` 現況（非同步 AI 生成、摘要機制、回溯式刪除、主角人設、`x-internal-request` 內部呼叫）落差已經很大，這次只補上跟《微服務架構準則.md》《微服務架構實作spec.md》直接相關的部分（回應格式、`x-internal-request`、非同步狀態持久化），**其餘章節（尤其「訊息不可變性」——現況已支援 `DELETE /conversations/:id/messages/:messageId` 回溯式刪除，跟本文件矛盾）仍是舊版描述，不可視為現況**。完整反映 chat-service 現況需要另外一輪全面重寫，不在這次範圍內。

### 需求：對話建立
系統應允許使用者與 AI 角色開始新對話。每個對話屬於一個使用者，並與一個角色配對。

#### 情境：成功建立對話
- **當** 使用者發送 `POST /conversations`，包含 `{ characterId, title? }`
- **則** 系統建立對話記錄，回傳對話資料，HTTP 201

#### 情境：缺少角色 ID
- **當** 請求缺少必填欄位 `characterId`
- **則** 系統回傳錯誤碼 `MISSING_REQUIRED_FIELDS`，HTTP 400

#### 情境：不存在的角色
- **當** 請求參照不存在的角色
- **則** 系統回傳錯誤碼 `CHARACTER_NOT_FOUND`，HTTP 404

### 需求：對話檢索
系統應允許使用者檢索自己的對話。使用者只能看到自己的對話。

#### 情境：檢索所有使用者對話
- **當** 使用者發送 `GET /conversations`
- **則** 系統回傳使用者的對話陣列（按 `x-user-id` 篩選），HTTP 200

#### 情境：對話包含最新訊息
- **當** 檢索對話時
- **則** 每個對話記錄包含最新訊息（用於預覽）

#### 情境：找不到對話
- **當** 請求指向不存在的對話
- **則** 系統回傳錯誤碼 `CONVERSATION_NOT_FOUND`，HTTP 404

### 需求：訊息發送
系統應允許使用者和助手在對話中交換訊息。訊息儲存時包含角色（使用者或助手）、文本內容和時間戳。

#### 情境：使用者發送訊息
- **當** 使用者發送 `POST /conversations/:conversationId/messages`，包含 `{ role: "user", text: "Hello!" }`
- **則** 系統儲存訊息，回傳訊息資料，HTTP 201

#### 情境：助手發送訊息
- **當** ai-service 呼叫 `/conversations/:conversationId/messages`，包含 `{ role: "assistant", text: "..." }`
- **則** 系統儲存助手的回覆，回傳訊息資料，HTTP 201

#### 情境：缺少必填欄位
- **當** 請求缺少 `role` 或 `text`
- **則** 系統回傳錯誤碼 `MISSING_REQUIRED_FIELDS`，HTTP 400

#### 情境：無效的角色
- **當** 請求發送 `role` 值不是「user」或「assistant」
- **則** 系統回傳錯誤碼 `INVALID_ROLE`，HTTP 400

### 需求：訊息檢索
系統應允許檢索對話中的訊息，支援分頁。

#### 情境：檢索對話訊息
- **當** 使用者發送 `GET /conversations/:conversationId/messages`
- **則** 系統回傳訊息陣列，HTTP 200

#### 情境：訊息分頁
- **當** 請求包含查詢參數 `limit=50&offset=0`
- **則** 系統回傳最多 50 條訊息，從偏移位置開始，按建立時間排序

#### 情境：訊息排序
- **當** 檢索訊息時
- **則** 訊息按時間順序回傳（始終一致的順序）

#### 情境：未授權的訊息存取
- **當** 使用者嘗試檢索另一個使用者的對話訊息
- **則** 系統回傳錯誤碼 `FORBIDDEN`，HTTP 403

### 需求：訊息不可變性
訊息一旦建立，應不能編輯。這保留了對話歷史的完整性。

#### 情境：訊息建立是永久的
- **當** 使用者建立訊息
- **則** 該訊息無法編輯或刪除；僅能新增訊息

### 需求：對話後設資料
每個對話應跟蹤使用者 ID、角色 ID、標題（可選）、建立時間和最後更新時間。

#### 情境：對話後設資料捕捉
- **當** 對話被建立
- **則** 系統捕捉 `userId`、`characterId`、`title`（如果提供）、`createdAt`、`updatedAt`

## 資料模型

### Conversation 表
- `id` (String, PK, CUID)：唯一對話識別碼
- `userId` (String, FK → User.id)：對話擁有者
- `characterId` (String, FK → Character.id)：相關的 AI 角色
- `title` (String, nullable)：可選的對話標題（例如「與 Luna 的對話」）
- `createdAt` (DateTime)：對話建立時間戳
- `updatedAt` (DateTime)：最後活動時間戳

**索引：**
- `userId`（檢索使用者的對話）
- `characterId`（尋找與特定角色的對話）
- `(userId, characterId)`（複合索引，用於常見查詢模式）

**關係：**
- 一對多：Conversation → Message（一個對話有許多訊息）
- 外鍵：userId → User.id
- 外鍵：characterId → Character.id

### Message 表
- `id` (String, PK, CUID)：唯一訊息識別碼
- `conversationId` (String, FK → Conversation.id)：父對話
- `role` (String, enum: "user" | "assistant")：訊息發送者角色
- `text` (String)：訊息內容
- `createdAt` (DateTime)：訊息建立時間戳
- `updatedAt` (DateTime)：最後更新時間戳（通常等於 createdAt，因為不可變）

**索引：**
- `conversationId`（檢索對話訊息）
- `createdAt`（時間排序和查詢）
- 複合：`(conversationId, createdAt)`（用於分頁查詢）

**關係：**
- 外鍵：conversationId → Conversation.id，CASCADE DELETE（刪除對話時自動刪除訊息）

**遷移：**
- `init` — 初始 Conversation 和 Message 表建立

## API 端點

### POST /conversations
**Header：**
- `x-user-id` (string)：由 gateway 注入，成為對話的 `userId`

**請求主體：**
```json
{
  "characterId": "char_1720000000000",
  "title": "與 Luna 的對話"
}
```

**回應 201：**
```json
{
  "id": "conv_abc123xyz",
  "userId": "usr_1720000000000",
  "characterId": "char_1720000000000",
  "title": "與 Luna 的對話",
  "createdAt": "2026-01-20T10:00:00Z",
  "updatedAt": "2026-01-20T10:00:00Z"
}
```

**回應 400 (MISSING_REQUIRED_FIELDS)：**
```json
{
  "error": "MISSING_REQUIRED_FIELDS",
  "message": "缺少必填欄位：characterId"
}
```

### GET /conversations
**Header：**
- `x-user-id` (string)：篩選至該使用者的對話

**回應 200：**
```json
[
  {
    "id": "conv_abc123xyz",
    "userId": "usr_1720000000000",
    "characterId": "char_1720000000000",
    "title": "與 Luna 的對話",
    "createdAt": "2026-01-20T10:00:00Z",
    "updatedAt": "2026-01-20T10:00:00Z",
    "latestMessage": {
      "id": "msg_xyz789",
      "role": "assistant",
      "text": "今天我能幫你什麼？",
      "createdAt": "2026-01-20T10:05:00Z"
    }
  },
  ...
]
```

### POST /conversations/:conversationId/messages
**Header：**
- `x-user-id` (string)：必須擁有對話

**請求主體：**
```json
{
  "role": "user",
  "text": "你好！你今天過得怎麼樣？"
}
```

**回應 201：**
```json
{
  "id": "msg_xyz789",
  "conversationId": "conv_abc123xyz",
  "role": "user",
  "text": "你好！你今天過得怎麼樣？",
  "createdAt": "2026-01-20T10:05:00Z",
  "updatedAt": "2026-01-20T10:05:00Z"
}
```

**回應 400 (INVALID_ROLE)：**
```json
{
  "error": "INVALID_ROLE",
  "message": "無效的角色。必須是 'user' 或 'assistant'"
}
```

### GET /conversations/:conversationId/messages
**Header：**
- `x-user-id` (string)：必須擁有對話

**查詢參數：**
- `limit` (integer, optional, default: 50)：要回傳的最大訊息數
- `offset` (integer, optional, default: 0)：要跳過的訊息數

**回應 200：**
```json
[
  {
    "id": "msg_abc123",
    "conversationId": "conv_abc123xyz",
    "role": "user",
    "text": "你好！",
    "createdAt": "2026-01-20T10:00:00Z"
  },
  {
    "id": "msg_xyz789",
    "conversationId": "conv_abc123xyz",
    "role": "assistant",
    "text": "你好！有什麼我能幫助的嗎？",
    "createdAt": "2026-01-20T10:01:00Z"
  },
  ...
]
```

**回應 404 (CONVERSATION_NOT_FOUND)：**
```json
{
  "error": "CONVERSATION_NOT_FOUND",
  "message": "找不到對話"
}
```

**回應 403 (FORBIDDEN)：**
```json
{
  "error": "FORBIDDEN",
  "message": "你沒有權限存取此對話"
}
```

### 需求：內部服務呼叫繞過所有權檢查（2026-07-25 新增）
ai-service 需要經 Gateway 的 `/internal/conversations` 路由查詢對話歷史、發送訊息，這類請求帶 `x-internal-request: true`，不帶 `x-user-id`（內部呼叫無具體登入者身份）。

#### 情境：內部呼叫查詢訊息
- **當** 請求帶 `x-internal-request: true` 查詢 `GET /conversations/:conversationId/messages`
- **則** 系統跳過對話擁有權比對，直接回傳訊息

#### 情境：內部呼叫發送訊息
- **當** 請求帶 `x-internal-request: true` 呼叫 `POST /conversations/:conversationId/messages`
- **則** 系統跳過擁有權比對

#### 情境：外部請求仍需擁有權
- **當** 請求不帶 `x-internal-request: true`
- **則** 系統依 `x-user-id` 是否等於對話的 `userId` 判斷放行

### 需求：非同步任務狀態持久化（2026-07-25 新增）
建立聊天室的背景流程狀態、AI 生成狀態，原本存在進程內記憶體（Map），現已改為 `Conversation` 表本身的欄位與獨立的 `ConversationCreationJob` 表，服務重啟後狀態不遺失。

#### 情境：聊天室建立中的狀態持久化
- **當** 建立聊天室的背景流程（RAG 初始化）正在進行
- **則** 狀態記錄在 `ConversationCreationJob` 表（複合主鍵 `userId + characterId`），而非進程內 Map
- **並且** 服務重啟後，`GET /conversations/character/:characterId` 仍能正確回報 `preparing` 或讀到已完成的 `Conversation` 記錄

#### 情境：AI 生成狀態持久化
- **當** AI 正在生成回覆，或生成已完成/失敗
- **則** 狀態記錄在 `Conversation` 表的 `generationStatus`、`generationError`、`generationTempUserId`、`generationUserMessageId`、`generationAssistantMessageId`、`generationUpdatedAt` 欄位
- **並且** 服務重啟後，`GET /conversations/:conversationId/ai-generation-status` 仍能讀到重啟前的狀態

#### 情境：並行生成鎖改為資料庫層級的條件更新
- **當** 同一聊天室已有生成任務進行中（`generationStatus === 'generating'` 且未超過殭屍鎖時限）
- **則** 新的發送訊息請求被拒絕（`AI_GENERATION_IN_PROGRESS`，HTTP 409）
- **並且** 這個「拒絕並行」的判斷透過資料庫的條件式 `updateMany`（`WHERE` 涵蓋「非 generating」「從未生成過」「殭屍鎖已過期」三種情況）達成原子性，取代原本依賴進程內記憶體同步區塊的作法

## 回應格式（2026-07-25 更新）

錯誤回應統一為 `{ error: "<CODE>", message: "..." }`（本文件其餘章節的 JSON 範例已於 2026-07-26 同步更新為此格式）。成功回應：
- 單一資源／訊息：直接回傳物件本身
- 資源清單：直接回傳陣列
- 操作成功、無實質資源（例如刪除對話、清除生成狀態）：`{ success: true, message: "..." }`
- **業務語意欄位不受此格式規則約束**：例如 `getOrCreateConversation` 回傳的 `status: "preparing"/"ready"/"failed"`、AI 生成狀態的 `status: "generating"/"completed"/"failed"/"unknown"`，這些 `status` 是給前端輪詢判斷用的業務語意值，不是「操作成功/失敗」的格式包裹，維持原樣不受影響。

## 錯誤碼參考

| 錯誤碼 | HTTP 狀態碼 | 含義 |
|---|---|---|
| CONVERSATION_NOT_FOUND | 404 | 對話 ID 不存在 |
| CHARACTER_NOT_FOUND | 404 | 參照的角色 ID 不存在 |
| MISSING_CONVERSATION_ID / MISSING_CHARACTER_ID / MISSING_TEXT / MISSING_PARAMS | 400 | 缺少必填欄位 |
| INVALID_ROLE | 400 | 角色必須是「user」或「assistant」 |
| FORBIDDEN | 403 | 使用者沒有權限（不擁有對話，且非內部呼叫） |
| UNAUTHORIZED | 401 | 缺少 `x-user-id`，且非內部呼叫 |
| AI_GENERATION_IN_PROGRESS | 409 | 同一聊天室已有生成任務進行中 |
| INTERNAL_SERVER_ERROR | 500 | 非預期的伺服器錯誤 |

## 架構說明

**三層設計：**
- **Controller**：HTTP 處理，驗證，授權檢查
- **Service**：業務邏輯，訊息排序，對話後設資料管理
- **Repository**：Prisma CRUD，附帶最新訊息的預先載入

**授權：**
- 對話擁有權透過 `x-user-id` header 驗證（由 gateway 注入）
- 使用者只能存取自己的對話和訊息

**訊息不可變性：**
- 訊息建立後永遠不能編輯或刪除
- 只能將新訊息追加到對話

## 環境變數

- `DATABASE_URL` — SQLite 資料庫路徑
- `PORT` — Chat-service 監聽的連接埠（預設：6000）

## 依賴

- **express** ^5
- **@prisma/client** ^7
- **@prisma/adapter-libsql**
- **@libsql/client**

## 已知限制

- 沒有訊息刪除功能（對話是永久的）
- 沒有對話刪除功能（部分實現）
- 沒有訊息搜尋或按內容篩選
- 沒有實時訊息更新（僅限輪詢）
- 沒有檔案附件或多媒體支援
- 沒有對話歸檔或軟刪除
