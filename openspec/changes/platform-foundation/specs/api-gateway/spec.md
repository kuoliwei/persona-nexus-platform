## 新增需求

### 需求：統一 API 端點
系統應在 `http://localhost:8000` 提供單一 API 網關作為唯一的公開面向入口。所有前端請求必須經過網關；不允許直接呼叫後端服務。

#### 情境：前端使用網關
- **當** 前端發送請求到 `http://localhost:8000/auth/register`
- **則** 網關代理至 auth-service `http://localhost:3000/api/v1/auth/register`

#### 情境：後端服務隔離
- **當** 前端嘗試直接呼叫 `http://localhost:3000/auth/register`
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

### 需求：JWT 驗證
網關應在代理請求之前驗證來自 `Authorization: Bearer <token>` header 的 JWT 令牌。驗證在網關上集中進行一次。

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

### 需求：Header 注入
JWT 驗證成功後，網關應在將使用者資訊注入至請求 header 後才代理至後端服務。這消除了後端服務重新驗證 JWT 的必要。

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

### 需求：路徑重寫
網gateway 應重寫傳入路徑以符合後端服務的內部路由結構。這向客戶端隱藏內部 `/api/v1/` 前綴。

#### 情境：Auth 路由重寫
- **當** 客戶端請求 `POST /auth/register`
- **則** 網關重寫為 `POST /api/v1/auth/register` 並代理至 auth-service

#### 情境：User 路由（無重寫）
- **當** 客戶端請求 `GET /users/:id`
- **則** 網關直接代理至 user-service，無路徑轉換

#### 情境：Character 路由重寫
- **當** 客戶端請求 `PUT /characters/:id`
- **則** 網關重寫為 `PUT /api/v1/characters/:id` 並代理至 character-service

### 需求：服務發現
每個後端服務 URL 透過環境變數設定。這允許輕鬆交換服務地址（例如在不同部署中）。

#### 情境：服務 URL 設定
- **當** 網關啟動
- **則** 它從 `.env` 讀取：
  - `AUTH_SERVICE_URL`（預設：`http://localhost:3000`）
  - `USER_SERVICE_URL`（預設：`http://localhost:4000`）
  - `CHARACTER_SERVICE_URL`（預設：`http://localhost:5000`）
  - `CHAT_SERVICE_URL`（預設：`http://localhost:6000`）

### 需求：公開 vs 受保護的路由
某些路由（註冊、登入）不需要 JWT。網gateway 應無需 JWT 驗證即可路由這些。

#### 情境：公開認證路由
- **當** 客戶端發送請求至 `/auth/register` 或 `/auth/login`
- **則** 網關跳過 JWT 中介層並直接代理
- **並且** 不新增 `x-user-id` header

#### 情境：受保護的使用者路由
- **當** 客戶端發送請求至 `/users/:id`
- **則** 網關需要有效 JWT
- **並且** 如果 JWT 缺失或無效，請求被 HTTP 401 拒絕

### 需求：健康檢查端點
網gateway 應提供健康檢查端點，不需要認證。

#### 情境：網關健康檢查
- **當** 客戶端發送 `GET /health`
- **則** 網關回應 HTTP 200 和 `{ status: "ok" }`
- **並且** 此端點在本機提供（不代理）

### 需求：錯誤回應標準化
網gateway 應回傳一致的錯誤回應。錯誤訊息來自代理服務；網關標準化格式。

#### 情境：認證錯誤
- **當** JWT 驗證失敗
- **則** 網關回傳 `{ status: "error", message: "未授權" }`，HTTP 401

#### 情境：代理服務錯誤
- **當** 代理服務回傳錯誤（例如 `CHARACTER_NOT_FOUND`）
- **則** 網關傳遞服務的回應

## 資料流圖

```
瀏覽器（5173/5174/5175/5176）
    |
    v
api-gateway（8000）
    | JWT 驗證
    | CORS 處理
    | x-user-id 注入
    | 路徑重寫
    |
    ├─ /auth/* ──> auth-service（3000）
    ├─ /users/* ──> user-service（4000）
    ├─ /characters/* ──> character-service（5000）
    ├─ /conversations/* ──> chat-service（6000）
    └─ /health ──> （本機回應）
```

## API 路由參考

| 路由 | 後端 | 需要 JWT | 路徑重寫 |
|-------|---------|--------------|--------------|
| POST /auth/register | auth-service:3000 | 否 | `/api/v1/auth/register` |
| POST /auth/login | auth-service:3000 | 否 | `/api/v1/auth/login` |
| GET /users?email= | user-service:4000 | 否 | `/users?email=`（未改變） |
| GET /users/:id | user-service:4000 | 是 | `/users/:id`（未改變） |
| DELETE /users/:id | user-service:4000 | 是 | `/users/:id`（未改變） |
| POST /characters | character-service:5000 | 是 | `/api/v1/characters` |
| GET /characters/:id | character-service:5000 | 是 | `/api/v1/characters/:id` |
| PUT /characters/:id | character-service:5000 | 是 | `/api/v1/characters/:id` |
| DELETE /characters/:id | character-service:5000 | 是 | `/api/v1/characters/:id` |
| POST /conversations | chat-service:6000 | 是 | `/api/v1/conversations` |
| GET /conversations | chat-service:6000 | 是 | `/api/v1/conversations` |
| POST /conversations/:id/messages | chat-service:6000 | 是 | `/api/v1/conversations/:id/messages` |
| GET /conversations/:id/messages | chat-service:6000 | 是 | `/api/v1/conversations/:id/messages` |
| GET /health | 網gateway（本機） | 否 | 不適用 |

## 環境變數

- `PORT` — 網gateway 監聽的連接埠（預設：8000）
- `JWT_SECRET` — JWT 驗證用的祕密鑰匙（必須與 auth-service 的 `JWT_SECRET` 相同）
- `FRONTEND_ORIGIN` — 允許的前端來源逗號分隔清單（例如 `http://localhost:5173,http://localhost:5174,...`）
- `AUTH_SERVICE_URL` — Auth-service URL（預設：`http://localhost:3000`）
- `USER_SERVICE_URL` — User-service URL（預設：`http://localhost:4000`）
- `CHARACTER_SERVICE_URL` — Character-service URL（預設：`http://localhost:5000`）
- `CHAT_SERVICE_URL` — Chat-service URL（預設：`http://localhost:6000`）

## 架構說明

**反向代理模式：**
- 網gateway 使用 `http-proxy-middleware` 或類似工具代理請求
- 移除上游 CORS header（來自服務的 `Access-Control-Allow-Origin`）以防衝突
- 網gateway 自身的 CORS 中介層處理客戶端 CORS

**無狀態設計：**
- 網gateway 不維護任何會話或請求狀態
- 每個請求都被獨立驗證和代理
- 水平擴展可行（多個網gateway 實例負載均衡）

**安全含義：**
- JWT 驗證集中化（減少攻擊面）
- 後端服務信任 `x-user-id` header（假設網gateway 始終存在且值得信任）
- 如果網gateway 遭到入侵，後端容易受到偽造 `x-user-id` header 的攻擊

## 已知限制

- 網gateway 層沒有請求速率限制
- 沒有請求/回應日誌記錄或稽核追蹤
- 沒有 API 版本管理策略（所有路由在內部使用 v1）
- 沒有跨後端服務的負載均衡（直接 1:1 代理）
- 沒有失敗服務的斷路器模式
