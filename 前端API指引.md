# 前端 API 指引（完整版本）

> 本文檔列舉所有開放給前端（瀏覽器）的 API 端點。  
> 所有請求必須通過 `http://localhost:8000`（api-gateway）進行，不能直接訪問後端服務的裸 port。  
> 源頭：gateway `src/app.js` 的路由掛載 + 各後端服務的 app.js 路由定義。

---

## 快速導航

1. **認證相關** — register / login
2. **用戶相關** — 用戶信息查詢與操作
3. **角色相關** — 角色的建立、查詢、修改、刪除
4. **對話相關** — 聊天對話管理、訊息發送與查詢

---

## 1. 認證相關 API

### 1.1 用戶註冊

**端點**
```
POST /api/auth/register
```

**所屬服務** — auth-service（內部路由：`POST /api/v1/auth/register`）

**認證** — 不需要 token

**功能** — 建立新用戶帳號

**請求頭**
```
Content-Type: application/json
```

**請求 Body**
```json
{
  "email": "user@example.com",     // 必填，字符串，應符合 email 格式
  "password": "password123"        // 必填，字符串，至少 6 個字符
}
```

**源碼驗證**
- gateway：`src/proxies/authProxy.js` 中 `pathRewrite: { '^/api/auth': '/api/v1/auth' }`
- auth-service：`src/app.js` 行 12 `app.post('/api/v1/auth/register', ...)`
- 輸入驗證：`src/middlewares/validateMiddleware.js`（使用 Zod schema）
  - `email` 必填且必須是有效 email 格式
  - `password` 必填且長度 ≥ 6

**成功回應（201 Created）**
```json
{
  "id": "usr_1784985830488",
  "email": "user@example.com",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6InVzcl8xNzg0OTg1ODMwNDg4IiwiaWF0IjoxNzg0OTg1ODMwLCJleHAiOjE3ODU1OTA2MzB9.M5UCK0Wa9abQvnnbxPTOHpfbxTpsrWQeEkRPlS__c70"
}
```

**回應欄位說明**
- `id` — 新創建的用戶 ID（格式：`usr_${timestamp}`）
- `email` — 註冊的郵箱地址
- `token` — JWT token（效期 7 天），後續 API 請求需要在 `Authorization: Bearer {token}` 中使用

**錯誤回應**

**400 Bad Request**（輸入驗證失敗）
```json
{
  "error": "Validation error: email 格式不正確 / password 長度不足",
  "message": "Invalid input"
}
```

**409 Conflict**（郵箱已存在）
```json
{
  "error": "EMAIL_ALREADY_EXISTS",
  "message": "Email already registered"
}
```

**源碼參考**
- `auth-service/src/controllers/authController.js` 行 9（register 方法）
- `auth-service/src/services/authService.js` 行 15（register 邏輯，使用 bcrypt.hash）
- `auth-service/src/repositories/userRepository.js`（調用 user-service 建立用戶）

---

### 1.2 用戶登入

**端點**
```
POST /api/auth/login
```

**所屬服務** — auth-service（內部路由：`POST /api/v1/auth/login`）

**認證** — 不需要 token

**功能** — 使用郵箱與密碼登入，獲得 JWT token

**請求頭**
```
Content-Type: application/json
```

**請求 Body**
```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**源碼驗證**
- gateway：`src/proxies/authProxy.js` 中 `pathRewrite: { '^/api/auth': '/api/v1/auth' }`
- auth-service：`src/app.js` 行 14 `app.post('/api/auth/login', ...)`
- **特別注意**：login 端點**不做輸入格式驗證**（無 validateMiddleware）
  - 只要郵箱存在且密碼正確就返回 token
  - 密碼比對使用 `bcrypt.compare()`（`src/services/authService.js` 行 33）

**成功回應（200 OK）**
```json
{
  "id": "usr_1784985830488",
  "email": "user@example.com",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6InVzcl8xNzg0OTg1ODMwNDg4IiwiaWF0IjoxNzg0OTg1ODMwLCJleHAiOjE3ODU1OTA2MzB9.M5UCK0Wa9abQvnnbxPTOHpfbxTpsrWQeEkRPlS__c70"
}
```

**回應欄位說明** — 同 register

**錯誤回應**

**401 Unauthorized**（郵箱不存在或密碼錯誤）
```json
{
  "error": "INVALID_CREDENTIALS",
  "message": "Invalid email or password"
}
```

**源碼參考**
- `auth-service/src/controllers/authController.js` 行 28（login 方法）
- `auth-service/src/services/authService.js` 行 32（login 邏輯，使用 bcrypt.compare）

---

## 2. 用戶相關 API

**前置條件**：所有用戶相關 API 都需要 JWT token（由 `/api/auth/login` 或 `/api/auth/register` 返回）。

所有請求必須包含：
```
Authorization: Bearer {token}
```

### 2.1 根據 ID 查詢用戶信息

**端點**
```
GET /api/users/:id
```

**所屬服務** — user-service（內部路由：`GET /users/:id`）

**認證** — 需要 token

**功能** — 查詢指定用戶的信息（僅限查詢自己的信息）

**路徑參數**
- `id` — 用戶 ID（例：`usr_1784985830488`）

**源碼驗證**
- gateway：`src/proxies/userProxy.js` 中 `pathRewrite: (path) => '/users' + path`
- user-service：`src/app.js` 行 28 `app.get('/users/:id', ...)`
- 授權檢查：`src/middlewares/authorizeSelf.js`
  - 檢查 gateway 注入的 `x-user-id` 是否等於路徑參數 `:id`
  - 不符則返回 403 Forbidden

**成功回應（200 OK）**
```json
{
  "id": "usr_1784985830488",
  "email": "user@example.com"
}
```

**回應欄位說明**
- `id` — 用戶 ID
- `email` — 註冊的郵箱地址
- **注意**：密碼字段被過濾掉（只對外部請求隱藏，內部服務調用會返回密碼用於驗證）

**錯誤回應**

**401 Unauthorized**（無效或過期 token）
```json
{
  "error": "Unauthorized",
  "message": "Invalid or expired token"
}
```

**403 Forbidden**（試圖查詢他人信息）
```json
{
  "error": "FORBIDDEN",
  "message": "Access denied"
}
```

**404 Not Found**（用戶不存在）
```json
{
  "error": "USER_NOT_FOUND",
  "message": "User not found"
}
```

**源碼參考**
- `user-service/src/controllers/userController.js` 行 55（getUserById 方法）
- `user-service/src/middlewares/authorizeSelf.js` 行 12（授權檢查邏輯）

---

### 2.2 刪除用戶帳號

**端點**
```
DELETE /api/users/:id
```

**所屬服務** — user-service（內部路由：`DELETE /users/:id`）

**認證** — 需要 token

**功能** — 刪除指定用戶帳號（僅限刪除自己的帳號）

**路徑參數**
- `id` — 用戶 ID

**源碼驗證**
- gateway：`src/proxies/userProxy.js` 中 `pathRewrite: (path) => '/users' + path`
- user-service：`src/app.js` 行 42 `app.delete('/users/:id', ...)`
- 授權檢查：同 2.1，`authorizeSelf.js` 檢查 `x-user-id === :id`

**成功回應（200 OK）**
```json
{
  "success": true,
  "message": "User deleted successfully"
}
```

**錯誤回應** — 同 2.1（401 Unauthorized / 403 Forbidden / 404 Not Found）

**源碼參考**
- `user-service/src/controllers/userController.js` 行 73（deleteUser 方法）

---

## 3. 角色相關 API

**前置條件**：所有角色相關 API 都需要 JWT token。

### 3.1 建立角色

**端點**
```
POST /api/characters
```

**所屬服務** — character-service（內部路由：`POST /api/v1/characters`）

**認證** — 需要 token

**功能** — 建立新的 AI 角色

**請求頭**
```
Content-Type: application/json
Authorization: Bearer {token}
```

**請求 Body**
```json
{
  "name": "角色名稱",                    // 必填，字符串
  "background": "角色背景故事",          // 必填，字符串
  "opening": "角色開場台詞",             // 必填，字符串
  "introduction": "角色簡介",            // 必填，字符串
  "gender": "female",                    // 可選，字符串（"male" 或 "female"），默認 null
  "tags": ["tag1", "tag2"],              // 可選，字符串陣列，默認 []
  "fewShots": [
    { "user": "用戶說的話", "char": "角色回應" }
  ],                                     // 可選，對象陣列，每個含 user/char 字段，默認 []
  "visibility": "private"                // 可選，"private" 或 "public"，默認 "private"
}
```

**源碼驗證**
- gateway：`src/proxies/characterProxy.js` 中 `pathRewrite: (path) => '/api/v1/characters' + path`
- character-service：`src/app.js` 行 12 `app.post('/api/v1/characters', ...)`
- 必填欄位檢查：`src/services/characterService.js` 行 16-28
- 作者 ID：gateway 注入 `x-user-id` header，自動作為 `authorId`（`src/controllers/characterController.js` 行 12）

**成功回應（201 Created）**
```json
{
  "id": "char_1784985830594",
  "authorId": "usr_1784985830488",
  "name": "角色名稱",
  "background": "角色背景故事",
  "opening": "角色開場台詞",
  "introduction": "角色簡介",
  "gender": "female",
  "tags": ["tag1", "tag2"],
  "fewShots": [
    { "user": "用戶說的話", "char": "角色回應" }
  ],
  "visibility": "private",
  "createdAt": "2026-07-25T12:34:56.000Z",
  "updatedAt": "2026-07-25T12:34:56.000Z"
}
```

**錯誤回應**

**400 Bad Request**（缺少必填欄位或格式錯誤）
```json
{
  "error": "REQUIRED_FIELDS_MISSING",
  "message": "Missing required fields"
}
```

**401 Unauthorized**（無效或過期 token）

**源碼參考**
- `character-service/src/controllers/characterController.js` 行 1
- `character-service/src/services/characterService.js` 行 15（createCharacter 邏輯）

---

### 3.2 查詢角色列表

**端點**
```
GET /api/characters
```

**所屬服務** — character-service（內部路由：`GET /api/v1/characters`）

**認證** — 需要 token

**功能** — 查詢角色列表，支持多種過濾方式

**查詢參數**

| 參數 | 類型 | 說明 | 範例 |
|------|------|------|------|
| `authorId` | string | 過濾指定作者的角色（只看公開 + 自己的私有） | `usr_1784985830488` |
| `visibility` | string | 過濾公開角色 | `public` |
| 無參數 | — | 查詢當前用戶的全部角色（含私有） | 空 query |

**源碼驗證**
- gateway：`src/proxies/characterProxy.js` 中 `pathRewrite: (path) => '/api/v1/characters' + path`
- character-service：`src/app.js` 行 15 `app.get('/api/v1/characters', ...)`
- 邏輯：`src/services/characterService.js` 行 82-120（listCharacters）
  - 無參數 → 返回當前用戶的全部角色（由 `authorId = requesterId` 過濾）
  - `authorId=xxx` → 返回該用戶的公開角色 + 若 `xxx === requesterId` 則加上私有角色
  - `visibility=public` → 返回所有用戶的公開角色

**成功回應（200 OK）**
```json
[
  {
    "id": "char_1784985830594",
    "authorId": "usr_1784985830488",
    "name": "角色名稱",
    "background": "角色背景故事",
    "opening": "角色開場台詞",
    "introduction": "角色簡介",
    "gender": "female",
    "tags": ["tag1", "tag2"],
    "fewShots": [
      { "user": "用戶說的話", "char": "角色回應" }
    ],
    "visibility": "private",
    "createdAt": "2026-07-25T12:34:56.000Z",
    "updatedAt": "2026-07-25T12:34:56.000Z"
  }
]
```

**錯誤回應**

**401 Unauthorized**

**源碼參考**
- `character-service/src/services/characterService.js` 行 82（listCharacters 邏輯）

---

### 3.3 查詢單一角色

**端點**
```
GET /api/characters/:id
```

**所屬服務** — character-service（內部路由：`GET /api/v1/characters/:id`）

**認證** — 需要 token

**功能** — 查詢指定角色的詳細信息

**路徑參數**
- `id` — 角色 ID（例：`char_1784985830594`）

**源碼驗證**
- gateway：`src/proxies/characterProxy.js` 中 `pathRewrite: (path) => '/api/v1/characters' + path`
- character-service：`src/app.js` 行 18 `app.get('/api/v1/characters/:id', ...)`
- 授權邏輯：`src/services/characterService.js` 行 89-97
  - 若角色是 private 且作者不是當前用戶 → 403 Forbidden
  - public 角色任何人都可查詢

**成功回應（200 OK）** — 同 3.2 中的單一對象

**錯誤回應**

**403 Forbidden**（試圖查詢他人的私有角色）
```json
{
  "error": "FORBIDDEN",
  "message": "Access denied"
}
```

**404 Not Found**（角色不存在）
```json
{
  "error": "CHARACTER_NOT_FOUND",
  "message": "Character not found"
}
```

**401 Unauthorized**

**源碼參考**
- `character-service/src/services/characterService.js` 行 88（getCharacter 邏輯）

---

### 3.4 修改角色

**端點**
```
PUT /api/characters/:id
```

**所屬服務** — character-service（內部路由：`PUT /api/v1/characters/:id`）

**認證** — 需要 token

**功能** — 更新角色信息（僅限角色作者）

**路徑參數**
- `id` — 角色 ID

**請求頭**
```
Content-Type: application/json
Authorization: Bearer {token}
```

**請求 Body** — 同 3.1（全量更新，所有必填欄位都需要）

**源碼驗證**
- gateway：`src/proxies/characterProxy.js` 中 `pathRewrite: (path) => '/api/v1/characters' + path`
- character-service：`src/app.js` 行 21 `app.put('/api/v1/characters/:id', ...)`
- 授權檢查：`src/services/characterService.js` 行 121
  - 檢查 `existing.authorId === requesterId`
  - 不符返回 403 Forbidden

**成功回應（200 OK）** — 同 3.2 中的單一對象（返回更新後的角色信息）

**錯誤回應**

**403 Forbidden**（非角色作者）
```json
{
  "error": "FORBIDDEN",
  "message": "Access denied"
}
```

**404 Not Found**（角色不存在）

**400 Bad Request**（缺少必填欄位）

**401 Unauthorized**

**源碼參考**
- `character-service/src/services/characterService.js` 行 119（updateCharacter 邏輯）

---

### 3.5 刪除角色

**端點**
```
DELETE /api/characters/:id
```

**所屬服務** — character-service（內部路由：`DELETE /api/v1/characters/:id`）

**認證** — 需要 token

**功能** — 刪除指定角色（僅限角色作者）

**路徑參數**
- `id` — 角色 ID

**源碼驗證**
- gateway：`src/proxies/characterProxy.js` 中 `pathRewrite: (path) => '/api/v1/characters' + path`
- character-service：`src/app.js` 行 24 `app.delete('/api/v1/characters/:id', ...)`
- 授權檢查：同 3.4

**成功回應（200 OK）**
```json
{
  "success": true,
  "message": "Character deleted successfully"
}
```

**錯誤回應** — 同 3.4（403 Forbidden / 404 Not Found / 401 Unauthorized）

**源碼參考**
- `character-service/src/services/characterService.js` 行 132（deleteCharacter 邏輯）

---

## 4. 對話相關 API

**前置條件**：所有對話相關 API 都需要 JWT token。

詳見 [chat-service-api-guide.md](chat-service-api-guide.md)（已單獨詳細記錄）。

簡述：
- `GET /api/conversations/character/{characterId}` — 取得或建立對話
- `GET /api/conversations/{conversationId}/messages` — 查詢對話訊息
- `POST /api/conversations/{conversationId}/messages` — 發送訊息（異步 AI 生成）
- `GET /api/conversations/{conversationId}/ai-generation-status` — 查詢 AI 生成狀態（輪詢用）
- `DELETE /api/conversations/{conversationId}/messages/{messageId}` — 刪除訊息（回溯式）
- 等等（見 chat-service-api-guide.md 完整列表）

**源碼驗證**
- gateway：`src/proxies/chatProxy.js` 中 `pathRewrite: (path) => '/api/v1/conversations' + path`
- chat-service：`src/app.js` 行 24-69（所有對話路由）

---

## 5. 其他端點

### 5.1 Gateway 健康檢查

**端點**
```
GET /health
```

**認證** — 不需要 token

**功能** — 驗證 Gateway 是否正常運行

**成功回應（200 OK）**
```json
{
  "status": "ok",
  "service": "api-gateway"
}
```

**源碼參考**
- `api-gateway/src/app.js` 行 29

---

### 5.2 前端配置信息

**端點**
```
GET /api/config
```

**認證** — 不需要 token

**功能** — 獲取前端可使用的後端服務地址

**成功回應（200 OK）**
```json
{
  "services": {
    "gateway": "http://localhost:8080/api"
  },
  "frontends": {
    "web": "http://localhost:8080/login",
    "character": "http://localhost:8080/character",
    "lobby": "http://localhost:8080",
    "chat": "http://localhost:8080/chat"
  }
}
```

**源碼參考**
- `api-gateway/src/app.js` 行 42

---

## 附錄 A：Gateway 路由對照表

| 前端路徑 | HTTP 方法 | 後端服務 | 內部路徑 | 認證 |
|---------|---------|---------|---------|-----|
| `/api/health` | GET | Gateway 本機 | N/A | 否 |
| `/api/config` | GET | Gateway 本機 | N/A | 否 |
| `/api/auth/register` | POST | auth-service | `/api/v1/auth/register` | 否 |
| `/api/auth/login` | POST | auth-service | `/api/v1/auth/login` | 否 |
| `/api/users/:id` | GET | user-service | `/users/:id` | 是 |
| `/api/users/:id` | DELETE | user-service | `/users/:id` | 是 |
| `/api/characters` | GET | character-service | `/api/v1/characters` | 是 |
| `/api/characters` | POST | character-service | `/api/v1/characters` | 是 |
| `/api/characters/:id` | GET | character-service | `/api/v1/characters/:id` | 是 |
| `/api/characters/:id` | PUT | character-service | `/api/v1/characters/:id` | 是 |
| `/api/characters/:id` | DELETE | character-service | `/api/v1/characters/:id` | 是 |
| `/api/conversations/*` | GET/POST/DELETE | chat-service | `/api/v1/conversations/*` | 是 |

---

## 附錄 B：認證與 Header 規範

### JWT Token 使用

所有受保護端點（認證 = 「是」）都需要在 HTTP 請求頭中包含：

```
Authorization: Bearer {token}
```

其中 `{token}` 是從 `/api/auth/login` 或 `/api/auth/register` 返回的 JWT token 字符串。

### Gateway 自動注入的 Header

Gateway 驗證 JWT 後，會自動注入以下 header 轉發給後端服務（**前端無需提供**）：

| Header 名稱 | 說明 |
|-----------|-----|
| `x-user-id` | 當前登入用戶的 ID（從 JWT payload 的 `id` 欄位提取） |
| `x-user-email` | 當前登入用戶的郵箱（未來可能使用） |

**重要**：
- 後端服務信任 gateway 注入的 `x-user-id`，不再獨立驗證 JWT
- 前端無法偽造 `x-user-id`（gateway 會覆寫任何客戶端提供的值）
- 內部服務調用時可使用 `x-internal-request: true` header 繞過授權檢查（前端不應使用）

**源碼參考**
- `api-gateway/src/middlewares/authMiddleware.js`

---

## 附錄 C：錯誤處理慣例

### 常見 HTTP 狀態碼

| 狀態碼 | 含義 | 常見原因 |
|-------|------|--------|
| 200 | OK | 成功的 GET/PUT/DELETE |
| 201 | Created | 成功建立資源（POST） |
| 202 | Accepted | 非同步操作已接受（chat-service） |
| 400 | Bad Request | 輸入驗證失敗、缺必填欄位 |
| 401 | Unauthorized | 無效/過期 token、缺 Authorization header |
| 403 | Forbidden | 授權失敗、試圖訪問他人私有資源 |
| 404 | Not Found | 資源不存在 |
| 409 | Conflict | 並行操作衝突（chat-service AI 生成中） |
| 502 | Bad Gateway | 後端服務不可達 |
| 503 | Service Unavailable | 後端服務故障（如 AI Service 離線） |

### 錯誤回應格式

除了 HTTP 狀態碼，所有錯誤回應都遵循統一格式：

**已知的語意錯誤**（400/401/403/404）
```json
{
  "error": "ERROR_CODE",
  "message": "Human-readable error message"
}
```

**未預期的 500 錯誤**
```json
{
  "error": "INTERNAL_SERVER_ERROR",
  "message": "Internal server error"
}
```

**Gateway 無法連線到後端（502）**
```json
{
  "error": "Bad Gateway",
  "message": "無法連線到伺服器，請稍後重試。"
}
```

---

## 附錄 D：完整請求範例

### 範例 1：註冊新帳號

```bash
curl -X POST "http://localhost:8000/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

### 範例 2：登入

```bash
curl -X POST "http://localhost:8000/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

### 範例 3：使用 Token 查詢自己的用戶信息

```bash
curl -X GET "http://localhost:8000/api/users/usr_1784985830488" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

### 範例 4：建立角色

```bash
curl -X POST "http://localhost:8000/api/characters" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "name": "我的角色",
    "background": "這是一個角色",
    "opening": "你好！",
    "introduction": "歡迎",
    "gender": "female",
    "tags": ["有趣", "聰慧"],
    "visibility": "public"
  }'
```

### 範例 5：查詢公開角色列表（大廳）

```bash
curl -X GET "http://localhost:8000/api/characters?visibility=public" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

---

## 附錄 E：源碼查閱快速索引

| 功能 | 源碼位置 |
|------|--------|
| Gateway 路由配置 | `api-gateway/src/app.js` |
| Gateway 認證中間件 | `api-gateway/src/middlewares/authMiddleware.js` |
| 認證服務 | `auth-service/src/controllers/authController.js` / `src/services/authService.js` |
| 用戶服務 | `user-service/src/controllers/userController.js` / `src/services/userService.js` |
| 角色服務 | `character-service/src/controllers/characterController.js` / `src/services/characterService.js` |
| 對話服務 | `chat-service/src/controllers/conversationController.js` / `src/services/conversationService.js` |
| Proxy 轉發規則 | `api-gateway/src/proxies/*.js` |
