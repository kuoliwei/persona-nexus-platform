## 新增需求

> 2026-07-25 更新：本檔案已依《微服務架構準則.md》《微服務架構實作spec.md》與《執行日誌.md》記錄的 T1-T20 修正結果同步，反映當前真實行為，不再是初版草案。詳細規則以根目錄那兩份文件為準，本檔案是 openspec 格式的對應紀錄。

### 需求：統一 API 端點
系統應在 `http://localhost:8000` 提供單一 API 網關作為唯一的公開面向入口。所有前端請求、以及所有服務間通訊，都必須經過網關；不允許前端或其他服務直接呼叫下游服務。

#### 情境：前端使用網關
- **當** 前端發送請求到 `http://localhost:8000/api/auth/register`
- **則** 網關代理至 auth-service `http://localhost:3000/api/v1/auth/register`

#### 情境：服務間通訊也走網關
- **當** auth-service 需要建立使用者帳號
- **則** 它呼叫網關的 `http://localhost:8000/internal/users`，而不是直連 user-service `http://localhost:4000`

#### 情境：後端服務隔離
- **當** 前端嘗試直接呼叫 `http://localhost:3000/api/v1/auth/register`
- **則** 連線被拒絕（服務不暴露於網際網路，僅透過 localhost 對網關可用）

### 需求：CORS 管理
網關應處理所有 CORS（跨來源資源共用）協商。前端應用可能在不同連接埠；網關允許多個來源。

#### 情境：允許多個前端來源
- **當** 位於 `http://localhost:5173` 的前端發送包含 `Origin` header 的請求
- **則** 網關回應 `Access-Control-Allow-Origin: http://localhost:5173`
- **並且** 其他來源（5174、5175、5176）也在白名單中

#### 情境：來源不在白名單中
- **當** 請求來自 `http://attacker.com`
- **則** CORS preflight 失敗，瀏覽器阻止跨來源請求

#### 情境：環境驅動的白名單
- **當** 網關啟動
- **則** 它從 `FRONTEND_ORIGIN` 環境變數讀取（逗號分隔清單）
- **並且** 應用這些來源至 CORS 中介層
- **例如：** `FRONTEND_ORIGIN=http://localhost:5173,http://localhost:5174,http://localhost:5175,http://localhost:5176`

### 需求：JWT 驗證（外部路由）
網關應在代理 `/api/*` 路由請求之前驗證來自 `Authorization: Bearer <token>` header 的 JWT 令牌。驗證在網關上集中進行一次，下游服務不重驗。

#### 情境：有效的 JWT
- **當** 請求包含 `Authorization: Bearer eyJhbGc...`，包含有效令牌
- **則** 網關使用 `JWT_SECRET` 驗證簽名
- **並且** 令牌有效且未過期
- **並且** 網關從 payload 提取使用者 ID 並繼續

#### 情境：已過期的令牌
- **當** 令牌已過期（createdAt + 7 天 < 現在）
- **則** 網關拒絕請求，回傳 HTTP 401 未授權

#### 情境：無效的簽名
- **當** 令牌簽名與 `JWT_SECRET` 不符
- **則** 網關拒絕請求，回傳 HTTP 401 未授權

#### 情境：缺少令牌
- **當** 對受保護路由的請求缺少 `Authorization` header
- **則** 網關回傳 HTTP 401 未授權

### 需求：內部請求驗證（`/internal/*` 路由）
`/internal/*` 路由不驗證 JWT，改用 `internalAuthMiddleware` 依來源 IP 判斷（僅允許 `127.0.0.1`／內網 IP），通過後注入 `x-internal-request: true` header 轉發給下游服務。

#### 情境：內部呼叫來自允許的 IP
- **當** 請求來自 `127.0.0.1` 或內網 IP，打 `/internal/characters/:id`
- **則** 網關放行，並注入 `x-internal-request: true` header 後轉發

#### 情境：內部呼叫來自非允許的 IP
- **當** 請求來自非白名單 IP
- **則** 網關回傳 HTTP 403，不轉發

#### 情境：信任前提
- 下游服務信任 `x-internal-request: true` 這個 header，前提是下游服務本身不對外直接開放（僅接受來自網關所在網路的連線）。若攻擊者能繞過網關直連下游服務，可自行偽造此 header——這是部署層（網路隔離、防火牆規則）必須確保的前提，不是網關程式碼能單獨解決的問題。

### 需求：Header 注入
JWT 驗證成功後（`/api/*` 路由），網關應在將使用者資訊注入至請求 header 後才代理至後端服務。這消除了後端服務重新驗證 JWT 的必要。

#### 情境：x-user-id 注入
- **當** JWT 驗證成功，payload 為 `{ id: "usr_123" }`
- **則** 網關新增 header `x-user-id: usr_123` 至傳出請求
- **並且** 後端收到此 header 並信任它（後端不重新驗證 JWT）

#### 情境：x-user-email 注入
- **當** JWT 驗證成功，payload 包含 `{ id: "usr_123", email: "user@example.com" }`（如果 email 存在於 payload）
- **則** 網關新增 header `x-user-email: user@example.com`

#### 情境：對受保護路由的未認證請求
- **當** 對受保護路由的請求缺少有效 JWT
- **則** header `x-user-id` 和 `x-user-email` 不被新增
- **並且** 網關在代理前使用 HTTP 401 拒絕

#### 情境：`/internal/*` 路由不注入 `x-user-id`
- **當** 請求打 `/internal/*` 路由
- **則** 網關**不會**注入 `x-user-id`／`x-user-email`（內部呼叫無具體登入者身份），只注入 `x-internal-request: true`

### 需求：路徑重寫
網關應重寫傳入路徑以符合後端服務的內部路由結構。這向客戶端隱藏內部路徑前綴，讓下游服務可以獨立演進內部路由而不影響前端呼叫方式。掛載方式與 pathRewrite 形式統一規則：公開路由（`/api/auth/*`）用精確掛載 + regex pathRewrite；其餘外部路由（`/api/*`）與內部路由（`/internal/*`）一律用前綴掛載 + 函式式 pathRewrite。

#### 情境：Auth 路由重寫（精確掛載 + regex）
- **當** 客戶端請求 `POST /api/auth/register`
- **則** 網關重寫為 `POST /api/v1/auth/register` 並代理至 auth-service

#### 情境：User 路由重寫（前綴掛載 + 函式式）
- **當** 客戶端請求 `GET /api/users/:id`
- **則** 網關把前綴補回 `/users`，重寫為 `GET /users/:id` 並代理至 user-service
- **並且** 這是 2026-07-25 修復的既有 bug：Express 前綴掛載會 strip 掉 `/api/users` 這段路徑，若沒有 pathRewrite 補回，轉發給 user-service 的路徑會缺失前綴（例如 `/api/users/usr_123` 轉發後變成 `/usr_123`），導致 404

#### 情境：Character 路由重寫
- **當** 客戶端請求 `PUT /api/characters/:id`
- **則** 網關重寫為 `PUT /api/v1/characters/:id` 並代理至 character-service

#### 情境：Conversation 路由重寫
- **當** 客戶端請求 `POST /api/conversations/:id/messages`
- **則** 網關重寫為 `POST /api/v1/conversations/:id/messages` 並代理至 chat-service

#### 情境：內部路由重寫
- **當** ai-service 呼叫 `POST /internal/rag/conversations/initialize`
- **則** 網關重寫為 `POST /api/v1/rag/conversations/initialize` 並代理至 ai-service

### 需求：服務發現
每個後端服務 URL 透過環境變數設定。這允許輕鬆交換服務地址（例如在不同部署中）。

#### 情境：服務 URL 設定
- **當** 網關啟動
- **則** 它從 `.env` 讀取：
  - `AUTH_SERVICE_URL`（預設：`http://localhost:3000`）
  - `USER_SERVICE_URL`（預設：`http://localhost:4000`）
  - `CHARACTER_SERVICE_URL`（預設：`http://localhost:5000`）
  - `CHAT_SERVICE_URL`（預設：`http://localhost:6000`）
  - `AI_SERVICE_URL`（預設：`http://localhost:6001`）

### 需求：公開 vs 受保護的路由
某些路由（註冊、登入）不需要 JWT。網關應無需 JWT 驗證即可路由這些。

#### 情境：公開認證路由
- **當** 客戶端發送請求至 `/api/auth/register` 或 `/api/auth/login`
- **則** 網關跳過 JWT 中介層並直接代理
- **並且** 不新增 `x-user-id` header

#### 情境：受保護的使用者路由
- **當** 客戶端發送請求至 `/api/users/:id`
- **則** 網關需要有效 JWT
- **並且** 如果 JWT 缺失或無效，請求被 HTTP 401 拒絕

### 需求：健康檢查端點
網關應提供健康檢查端點，不需要認證。

#### 情境：網關健康檢查
- **當** 客戶端發送 `GET /health`
- **則** 網關回應 HTTP 200 和 `{ status: "ok", service: "api-gateway" }`
- **並且** 此端點在本機提供（不代理）

### 需求：錯誤回應標準化
下游服務的錯誤回應統一為 `{ error: "<CODE>", message: "<human readable>" }` 格式（詳見《微服務架構實作spec.md》第三部分）。網關本身（JWT 驗證失敗等）的錯誤回應也遵循此格式。

#### 情境：認證錯誤
- **當** JWT 驗證失敗
- **則** 網關回傳 `{ message: "Invalid or expired token" }`，HTTP 401

#### 情境：代理服務錯誤
- **當** 代理服務回傳錯誤（例如 `CHARACTER_NOT_FOUND`）
- **則** 網關原樣傳遞服務的回應（`{error: "CHARACTER_NOT_FOUND", message: "..."}`），不重新包裝

## 資料流圖

```
瀏覽器（5173/5174/5175/5176）
    |
    v
api-gateway（8000）
    | JWT 驗證（/api/* 路由）／IP 驗證（/internal/* 路由）
    | CORS 處理
    | x-user-id／x-user-email 注入（/api/*）或 x-internal-request 注入（/internal/*）
    | 路徑重寫
    |
    ├─ /api/auth/*          ──> auth-service（3000）
    ├─ /api/users/*         ──> user-service（4000）
    ├─ /api/characters/*    ──> character-service（5000）
    ├─ /api/conversations/* ──> chat-service（6000）
    ├─ /internal/characters/:id       ──> character-service（3000，供 ai-service 呼叫）
    ├─ /internal/conversations/*      ──> chat-service（供 ai-service 呼叫）
    ├─ /internal/users, /users/:id    ──> user-service（供 auth-service 呼叫）
    ├─ /internal/rag/*, /internal/chat/*, /internal/health ──> ai-service（供 chat-service 呼叫）
    └─ /health ──> （本機回應）
```

## API 路由參考

### 外部路由（`/api/*`，需 JWT，除公開路由外）

| 路由 | 方法 | 掛載方式 | 後端 | 需要 JWT | pathRewrite 目標 |
|-------|---|---|---------|--------------|--------------|
| /api/auth/register | POST | 精確 | auth-service:3000 | 否 | `/api/v1/auth/register` |
| /api/auth/login | POST | 精確 | auth-service:3000 | 否 | `/api/v1/auth/login` |
| /api/users/:id | GET | 前綴 | user-service:4000 | 是 | `/users/:id` |
| /api/users/:id | DELETE | 前綴 | user-service:4000 | 是 | `/users/:id` |
| /api/characters | GET/POST | 前綴 | character-service:5000 | 是 | `/api/v1/characters` |
| /api/characters/:id | GET/PUT/DELETE | 前綴 | character-service:5000 | 是 | `/api/v1/characters/:id` |
| /api/conversations | GET/POST | 前綴 | chat-service:6000 | 是 | `/api/v1/conversations` |
| /api/conversations/:id | GET | 前綴 | chat-service:6000 | 是 | `/api/v1/conversations/:id` |
| /api/conversations/:id/messages | POST | 前綴 | chat-service:6000 | 是 | `/api/v1/conversations/:id/messages` |
| /health | GET | 本機 | 網關本機回應 | 否 | 不適用 |

### 內部路由（`/internal/*`，IP 驗證，不需 JWT）

| 路由 | 方法 | 後端 | 呼叫來源 | pathRewrite 目標 |
|-------|---|---------|---|--------------|
| /internal/characters/:id | GET | character-service:5000 | ai-service | `/api/v1/characters/:id` |
| /internal/conversations | GET | chat-service:6000 | ai-service | `/api/v1/conversations` |
| /internal/conversations/:id/messages | POST | chat-service:6000 | ai-service | `/api/v1/conversations/:id/messages` |
| /internal/users/:id | GET | user-service:4000 | （保留供未來使用，目前無呼叫方） | `/users/:id` |
| /internal/users | POST | user-service:4000 | auth-service | `/users` |
| /internal/rag/conversations/initialize | POST | ai-service:6001 | chat-service | `/api/v1/rag/conversations/initialize` |
| /internal/chat/generate | POST | ai-service:6001 | chat-service | `/api/v1/chat/generate` |
| /internal/health/ai | GET | ai-service:6001 | chat-service | `/health` |

## 環境變數

- `PORT` — 網關監聽的連接埠（預設：8000）
- `JWT_SECRET` — JWT 驗證用的祕密鑰匙（必須與 auth-service 的 `JWT_SECRET` 相同）
- `FRONTEND_ORIGIN` — 允許的前端來源逗號分隔清單（例如 `http://localhost:5173,http://localhost:5174,...`）
- `AUTH_SERVICE_URL` — Auth-service URL（預設：`http://localhost:3000`）
- `USER_SERVICE_URL` — User-service URL（預設：`http://localhost:4000`）
- `CHARACTER_SERVICE_URL` — Character-service URL（預設：`http://localhost:5000`）
- `CHAT_SERVICE_URL` — Chat-service URL（預設：`http://localhost:6000`）
- `AI_SERVICE_URL` — AI-service URL（預設：`http://localhost:6001`）

## 架構說明

**反向代理模式：**
- 網關使用 `http-proxy-middleware` 代理請求
- 移除上游 CORS header（來自服務的 `Access-Control-Allow-Origin`）以防衝突
- 網關自身的 CORS 中介層處理客戶端 CORS

**無狀態設計：**
- 網關不維護任何會話或請求狀態
- 每個請求都被獨立驗證和代理
- 水平擴展可行（多個網關實例負載均衡）

**服務間通訊也走網關：**
- 這是與初版設計不同的地方——最初 auth-service 建立使用者時直連 user-service，2026-07-25 已改為經網關的 `/internal/users` 路由，貫徹「所有服務間通訊都須通過 API Gateway」的準則（見《微服務架構準則.md》第 1 項）

**安全含義：**
- JWT 驗證集中化（減少攻擊面）
- 後端服務信任 `x-user-id` header（假設網關始終存在且值得信任）
- 內部呼叫的信任建立在「下游服務不對外開放」這個部署層前提上，不是程式碼層面能單獨保證的
- 如果網關遭到入侵，後端容易受到偽造 `x-user-id` / `x-internal-request` header 的攻擊

## 已知限制

- 網關層沒有請求速率限制
- 沒有請求/回應日誌記錄或稽核追蹤
- 沒有 API 版本管理策略（所有路由在內部使用 v1）
- 沒有跨後端服務的負載均衡（直接 1:1 代理）
- 沒有失敗服務的斷路器模式
- `internalAuthMiddleware` 的 IP 白名單本身無法在單機開發環境下驗證「拒絕非白名單 IP」這個分支（所有測試流量天然是 `127.0.0.1`）
