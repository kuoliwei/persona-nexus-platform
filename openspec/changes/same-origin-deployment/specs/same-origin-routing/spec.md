# Same-Origin Routing

## ADDED Requirements

### Requirement: Caddy 作為唯一對外入口
Caddy 反向代理 MUST 監聽單一埠（開發環境通常 8080/localhost，生產環境 80/443），作為所有使用者流量的唯一入口。所有前端請求和 API 呼叫都經過 Caddy。

#### Scenario: 使用者瀏覽器連入
- **WHEN** 使用者在瀏覽器打開 `http://localhost:8080/`
- **THEN** Caddy 終結 HTTP 連線，依路徑規則轉給相應的前端靜態檔或 gateway

#### Scenario: API 呼叫經過代理
- **WHEN** 前端執行 `fetch('/api/auth/login')`
- **THEN** 瀏覽器傳給 `http://localhost:8080/api/auth/login`，Caddy 轉給 gateway (內網 localhost:8000)

### Requirement: 路徑分流規則
Caddy MUST 根據請求路徑分流到不同後端：

| 請求路徑 | 轉向目標 | 說明 |
|---------|--------|------|
| `/` | 前端靜態檔 (lobby dist) | 根目錄 |
| `/login/*` | 前端靜態檔 (auth dist) | 登入/註冊頁面 |
| `/character/*` | 前端靜態檔 (character dist) | 角色創建/編輯頁面 |
| `/chat/*` | 前端靜態檔 (chat dist) | 聊天室 |
| `/api/*` | api-gateway (內網 :8000) | 所有 API 呼叫 |
| `/api/internal/*` | **不允許**（404） | 內部路由不對外暴露 |

#### Scenario: API 路由轉給 gateway
- **WHEN** 前端發送 `GET /api/auth/login` 請求到 Caddy
- **THEN** Caddy 轉給 `http://localhost:8000/api/auth/login` (gateway 內網地址)

#### Scenario: 前端頁面靜態檔
- **WHEN** 使用者進入 `http://localhost:8080/chat`
- **THEN** Caddy 從 chat 前端的 `dist/` 送出 `index.html` 及其靜態資源

#### Scenario: 內部路由被攔截
- **WHEN** 有人試圖從公網訪問 `/api/internal/rag/conversations/initialize`
- **THEN** Caddy 傳回 404 Not Found（或轉給 gateway，由 gateway 的 IP 白名單再攔截）

### Requirement: 前端靜態檔預設路由
當使用者訪問前端頁面路徑（如 `/chat/some-route`）但沒有對應的靜態檔時，Caddy MUST 回傳該前端的 `index.html`（支援單頁應用路由）。

#### Scenario: 單頁應用路由回退
- **WHEN** 使用者訪問 `http://localhost:8080/chat/conversation/12345`（chat 前端的客戶端路由）
- **THEN** Caddy 找不到 `dist/conversation/12345` 檔案，改送 `dist/index.html`，讓前端 JS 接管路由

### Requirement: HTTPS 終結（生產環境）
Caddy MUST 在生產環境上終結 HTTPS，使用 Let's Encrypt 自動申請和續期憑證。

#### Scenario: HTTPS 自動配置
- **WHEN** Caddyfile 配置 `persona-nexus.com` 域名
- **THEN** Caddy 自動申請 Let's Encrypt 憑證，啟用 HTTPS，設定自動續期

#### Scenario: 瀏覽器安全連線
- **WHEN** 使用者在瀏覽器輸入 `https://persona-nexus.com/chat`
- **THEN** 瀏覽器與 Caddy 建立 TLS 連線，Caddy 解密後轉給內網服務

