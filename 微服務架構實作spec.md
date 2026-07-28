# 微服務架構實作 Spec

> 基於《微服務架構準則》的具體實作規範。定義 API 合約、授權規則、技術細節。

---

## 第一部分：Gateway 路由與轉發規則

### Gateway 路由掛載統一原則

為避免路由寫法混亂（前綴掛載 vs 精確掛載、pathRewrite 用 regex vs 函式），定義以下統一方式：

#### 公開路由（auth 相關）
- 使用**精確掛載**（`app.post('/api/auth/register')`）
- pathRewrite 用 **regex 形式**（`{ '^/api/auth': '/api/v1/auth' }`）
- 理由：這兩條路由特殊，不需要驗證，單獨處理

#### 受保護的外部路由（`/api/*`）
- 使用**前綴掛載**（`app.use('/api/users', authMiddleware, userProxy)`）
- pathRewrite 用**函式形式**（`(path) => '/users' + path`）
- 理由：Express 會 strip 掉前綴，函式形式可清楚看到補什麼

#### 內部路由（`/internal/*`）
- 使用**前綴掛載**（`app.use('/internal/users', internalAuthMiddleware, userProxy)`）
- pathRewrite 用**函式形式**
- 理由：同外部路由，保持一致

### 外部路由表

| 路由 | 方法 | 掛載方式 | pathRewrite 目標 | 認證 | 描述 |
|---|---|---|---|---|---|
| `/api/auth/register` | POST | 精確 | `/api/v1/auth/register` | 否 | 新帳號註冊 |
| `/api/auth/login` | POST | 精確 | `/api/v1/auth/login` | 否 | 帳號登入 |
| `/api/users/:id` | GET | 前綴 | `/users/:id` | 是 | 查詢使用者（自己） |
| `/api/users/:id` | DELETE | 前綴 | `/users/:id` | 是 | 刪除使用者（自己） |
| `/api/characters` | GET | 前綴 | `/api/v1/characters` | 是 | 查詢角色清單 |
| `/api/characters` | POST | 前綴 | `/api/v1/characters` | 是 | 建立角色 |
| `/api/characters/:id` | GET | 前綴 | `/api/v1/characters/:id` | 是 | 查詢單一角色 |
| `/api/characters/:id` | PUT | 前綴 | `/api/v1/characters/:id` | 是 | 編輯角色 |
| `/api/characters/:id` | DELETE | 前綴 | `/api/v1/characters/:id` | 是 | 刪除角色 |
| `/api/conversations` | GET | 前綴 | `/api/v1/conversations` | 是 | 查詢對話清單 |
| `/api/conversations` | POST | 前綴 | `/api/v1/conversations` | 是 | 建立對話 |
| `/api/conversations/:id` | GET | 前綴 | `/api/v1/conversations/:id` | 是 | 查詢對話詳情 |
| `/api/conversations/:id/messages` | POST | 前綴 | `/api/v1/conversations/:id/messages` | 是 | 發送訊息 |

### 內部路由表

| 路由 | 方法 | 掛載方式 | pathRewrite 目標 | 呼叫來源 | 描述 |
|---|---|---|---|---|---|
| `/internal/characters/:id` | GET | 前綴 | `/api/v1/characters/:id` | ai-service | 查詢角色詳情 |
| `/internal/conversations` | GET | 前綴 | `/api/v1/conversations` | ai-service | 查詢對話歷史 |
| `/internal/conversations/:id/messages` | POST | 前綴 | `/api/v1/conversations/:id/messages` | ai-service | 發送訊息 |
| `/internal/users/:id` | GET | 前綴 | `/users/:id` | （保留供未來服務間查詢使用者資訊時使用） | 查詢使用者資訊 |
| `/internal/users` | POST | 前綴 | `/users` | auth-service | 建立使用者帳號 |
| `/internal/rag/conversations/initialize` | POST | 前綴 | `/api/v1/rag/conversations/initialize` | chat-service | 初始化 RAG 索引 |
| `/internal/chat/generate` | POST | 前綴 | `/api/v1/chat/generate` | chat-service | 生成 AI 回應 |
| `/internal/health/ai` | GET | 前綴 | `/health` | chat-service | AI 服務健康檢查 |

---

## 第二部分：認證與授權

### Header 契約

#### Gateway 注入給下游服務的 header

| Header 名稱 | 來源 | 值 | 何時注入 | 說明 |
|---|---|---|---|---|
| `x-user-id` | JWT token payload | 字串（使用者 ID） | `/api/*` 路由（外部） | 登入者身份，由 Gateway 從合法 token 提取並注入 |
| `x-user-email` | JWT token payload | 字串（email） | `/api/*` 路由（外部） | 登入者信箱，同上 |
| `x-internal-request` | internalAuthMiddleware | `"true"` | `/internal/*` 路由（內部） | 標記此請求來自服務間呼叫（IP 驗證通過），下游服務據此判斷是否跳過所有權檢查 |

**重要**：
- `x-user-id` / `x-user-email` 由 Gateway authMiddleware 驗完 JWT 後才會注入，前端無法偽造
- `x-internal-request: true` 由 Gateway internalAuthMiddleware 注入（IP 檢查通過），**前端無法加**
- `/internal/*` 路由**不會**注入 `x-user-id`（內部呼叫無具體登入者身份）
- 若內部呼叫需要知道發起者是哪個服務，待未來擴展時補充新 header（目前不需要）
- **信任前提**：下游服務信任 `x-internal-request: true` 的前提是下游服務本身不對外直接開放（僅接受來自 Gateway 所在網路的連線）。若攻擊者能繞過 Gateway 直連下游服務，可自行偽造此 header——這不是本 spec 要解決的問題，而是部署層（網路隔離、防火牆規則）必須確保的前提

#### 前端發送給 Gateway 的 header

| Header 名稱 | 值 | 說明 |
|---|---|---|
| `Authorization` | `Bearer <JWT token>` | 登入時由 auth-service 簽發，存在 localStorage，前端每次都要帶 |

### 授權檢查統一模式

各服務的授權檢查統一採用以下模式：

1. **不設獨立的「授權」middleware**。所有服務都不用 `authorizeSelf` 這類專屬授權 middleware。
2. **Controller 只負責從 header 讀值**：讀出 `x-user-id`（可能為 undefined）、`x-internal-request`（可能為 undefined），連同其他參數一起傳給 service 層方法。
3. **Service 層統一處理授權邏輯**，判斷順序固定為：
   - 若 `x-internal-request === 'true'` → 放行，跳過所有權檢查
   - 否則檢查 `x-user-id` 是否存在、是否等於資源擁有者 ID → 不符則 throw `FORBIDDEN`（無 `x-user-id` 則視為 401 `UNAUTHORIZED`）
4. **Controller 用共用 `ERROR_MAP` 把 service 丟出的錯誤碼轉成 HTTP 狀態碼**。

此模式維持「controller 處理 HTTP、service 處理商業邏輯與規則驗證」的分層原則，授權邏輯和其他業務規則驗證放在同一層，不另外維護一層 middleware。

### 授權決策表

#### auth-service

| 路由 | 需要檢查所有權 | 邏輯 | 實作位置 |
|---|---|---|---|
| `POST /api/auth/register` | 否 | 公開端點；建帳號時呼叫 Gateway 的 `POST /internal/users` 而非直連 user-service | controller |
| `POST /api/auth/login` | 否 | 公開端點，任何人都能登入 | controller |

#### user-service

| 路由 | 需要檢查所有權 | 邏輯 | 實作位置 |
|---|---|---|---|
| `POST /users` | 否（內部） | auth-service 呼叫（透過 Gateway `/internal/users`）建立帳號，檢查 `x-internal-request: true` | service 層 |
| `GET /api/users/:id` | 是 | 只能查自己（`x-user-id === :id`），外部請求必帶 `x-user-id` | service 層 |
| `DELETE /api/users/:id` | 是 | 只能刪自己（`x-user-id === :id`），外部請求必帶 `x-user-id` | service 層 |
| `GET /internal/users/:id` | 是（例外） | 內部呼叫帶 `x-internal-request: true` 時放行，否則檢查所有權 | service 層 |
| `POST /internal/users` | 否（內部） | auth-service 呼叫建立帳號，檢查 `x-internal-request: true` | service 層 |

#### character-service

| 路由 | 需要檢查所有權 | 邏輯 | 實作位置 |
|---|---|---|---|
| `POST /api/characters` | 是 | 建立者必須是 `x-user-id`，之後無法更改 | service 層 |
| `GET /api/characters` | 部分 | 不帶 query 時，回傳「登入者自己的所有角色（含 private）」聯集「所有 public 角色（不限作者，含自己的 public 角色，兩集合重疊部分去重）」；另支援 `?visibility=public`（查全部公開角色）、`?authorId=xxx`（查某作者角色，本人可看私有、他人只看公開）兩種既有查詢模式 | service 層 |
| `GET /api/characters/:id` | 部分 | 擁有者可查自己的；public 角色任何登入者都可查 | service 層 |
| `PUT /api/characters/:id` | 是 | 只有擁有者（`x-user-id === ownerId`）可編輯，檢查 `x-internal-request` 例外放行 | service 層 |
| `DELETE /api/characters/:id` | 是 | 只有擁有者可刪除，檢查 `x-internal-request` 例外放行 | service 層 |
| `GET /internal/characters/:id` | 否 | 內部呼叫（帶 `x-internal-request: true`）無所有權限制 | service 層放行 |

#### chat-service

| 路由 | 需要檢查所有權 | 邏輯 | 實作位置 |
|---|---|---|---|
| `POST /api/conversations` | 是 | 建立者 = `x-user-id` | service 層 |
| `GET /api/conversations` | 是 | 只返回登入者自己的對話 | service 層 |
| `GET /api/conversations/:id` | 是 | 只有對話參與者（建立者）可查，`x-internal-request` 例外放行 | service 層（`assertConversationOwnership`） |
| `POST /api/conversations/:id/messages` | 是 | 只有對話參與者可發送訊息，`x-internal-request` 例外放行 | service 層（`assertConversationOwnership`） |
| `GET /internal/conversations` | 否 | 內部呼叫（帶 `x-internal-request: true`）無所有權限制 | service 層放行 |
| `POST /internal/conversations/:id/messages` | 否 | 內部呼叫無所有權限制 | service 層放行 |

#### ai-service

| 路由 | 需要檢查所有權 | 邏輯 |
|---|---|---|
| `POST /internal/rag/conversations/initialize` | 否 | 內部呼叫，chat-service 直接呼叫 |
| `POST /internal/chat/generate` | 否 | 內部呼叫，chat-service 直接呼叫 |
| `GET /internal/health/ai` | 否 | 健康檢查，無需驗證 |

---

## 第三部分：API 回應格式與錯誤碼

### HTTP Status Code 統一定義

| 狀態碼 | 含義 | 何時使用 |
|---|---|---|
| 200 | OK | 請求成功 |
| 400 | Bad Request | 請求格式錯誤（缺必要欄位、格式不合法） |
| 401 | Unauthorized | token 無效、過期、或缺 Authorization header（只在 Gateway） |
| 403 | Forbidden | 驗證通過但無權限（例如：查詢他人的私有資訊、編輯他人的角色） |
| 404 | Not Found | 資源不存在 |
| 409 | Conflict | 衝突（例如：email 已被註冊） |
| 500 | Internal Server Error | 伺服器內部錯誤（未預期的例外） |
| 503 | Service Unavailable | 依賴的下游服務不可用，導致本次請求無法完成。兩種情境：<br>（1）**健康檢查回報不健康**（如 `GET /health` 探測到 Qdrant 連不上）<br>（2）**因下游失敗而主動中止操作，且資料未被修改**（如 RAG 清理失敗 → 聊天室不刪除、AI 服務不可用 → 訊息不寫入）。此情境的訊息應明確告知使用者「什麼沒有被執行」 |

### 錯誤回應格式

所有服務的錯誤回應都應該用以下格式：

```json
{
  "error": "<error code or HTTP status>",
  "message": "<human readable message>"
}
```

例如：
```json
{
  "error": "USER_NOT_FOUND",
  "message": "User with ID usr_123 does not exist"
}
```

### 成功回應格式

- **單一資源**：直接返回物件
  ```json
  {
    "id": "usr_123",
    "email": "user@example.com",
    "createdAt": "2026-07-25T10:00:00Z"
  }
  ```

- **資源清單**：返回陣列
  ```json
  [
    { "id": "char_1", "name": "Alice", ... },
    { "id": "char_2", "name": "Bob", ... }
  ]
  ```

- **操作成功（無回傳內容）**：
  ```json
  {
    "success": true,
    "message": "Resource deleted successfully"
  }
  ```

### 例外：健康檢查端點不受本節格式約束

`GET /health` 這類健康檢查端點**不適用**上述錯誤／成功回應格式，改用專屬形狀：

```json
{
  "status": "ok | degraded",
  "service": "<service name>",
  "dependencies": {
    "<dependency name>": { "status": "ok | error", "message": "<僅 error 時提供>" }
  }
}
```

- 健康時回 `200`，任一依賴不健康時回 `503`（狀態碼含義見上方表格）。
- 服務可視需要附加自身的資訊欄位（如所用模型、下游位址）。

**為什麼要豁免**：健康檢查回報的是「狀態」而非「錯誤」。若沿用 `{error, message}`
格式，「哪一個依賴壞了」這個結構化資訊會被壓成一句字串，呼叫端就無法逐項判讀——
而逐項判讀正是健康檢查唯一的用途。因此健康檢查端點應直接回傳結構化狀態，
不經過各服務的全域錯誤處理器轉換。

---

## 第四部分：非同步狀態管理

### 原則

非同步任務狀態**不得存在進程內記憶體（Map/dict）**，必須改為持久化儲存：狀態要能在服務重啟後保留、且能被同一服務的任意實例讀取。

### 統一做法

所有服務的非同步任務狀態必須採用同一種持久化方式，不得各服務各自選擇不同技術（例如一個用 DB 欄位、一個用 Redis）。技術選型（DB 欄位 vs Redis）、狀態欄位/資料結構設計（任務 ID、狀態值域、建立時間、逾時規則）留待後續決定，決定後套用到所有服務、所有非同步任務狀態。

---

## 更新紀錄

- **2026-07-25**：初稿，基於微服務架構準則定義實作細節
