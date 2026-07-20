## Why

目前平台前端和後端各佔獨立 port（前端 5173-5176，gateway 8000），瀏覽器看到 5 個不同 origin，導致 CORS 複雜、跨域問題、寫死主機名的 bootstrap 網址等痛點。同源部署將四個前端和 gateway 統一到單一對外入口（Caddy 反向代理），依路徑分流到各服務，消除同源問題、簡化部署、為後續公網開放打基礎。

## What Changes

**backend**
- api-gateway：所有對外路由統一加 `/api` 前綴（`/api/auth`、`/api/characters`、`/api/conversations`、`/api/users`、`/api/config`）
- `/internal/*` 路由保持不對外暴露

**frontend（四個都改）**
- 所有 API 呼叫（8 處寫死 `http://localhost:8000`）改為相對路徑 `/api/*`，消除 bootstrap 網址
- 跨前端跳轉改為相對路徑（`/login` 代替 `http://localhost:5173` 等）
- 各前端 `vite.config.js` 設 `base` 指向各自的路徑：
  - persona-nexus-lobby: `base: '/'`（根目錄）
  - persona-nexus-auth: `base: '/login/'`（避開 `/auth` API 路徑）
  - persona-nexus-character: `base: '/character/'`
  - persona-nexus-chat: `base: '/chat/'`
- config-loader 設定中心可大幅簡化或移除（不再需拿各服務網址）

**新增部署配置**
- `deploy/Caddyfile`：Caddy 反向代理設定
- `deploy/docker-compose.yml`：整套系統一鍵啟動配置
- 根目錄 git 初始化，納管部署設定

**CORS 與安全**
- gateway 的 `FRONTEND_ORIGIN` 允許清單同源後大多移除（同源 CORS 自動允許）
- `/internal/*` 的 IP 白名單重新檢視（Docker 網路環境下 IP 可能變化）

## Capabilities

### New Capabilities

- `same-origin-routing`: 單一對外入口的反向代理設定與路徑分流規則
- `api-prefix-standardization`: API 路由統一 `/api` 前綴約定
- `frontend-relative-paths`: 前端 API 呼叫改相對路徑，消除寫死主機名
- `deployment-automation`: Caddy + docker-compose 一鍵部署配置

### Modified Capabilities

- `api-gateway`: 路由前綴改動（所有外部路由加 `/api`），會影響前端和內部路由轉發邏輯
- `cors-management`: 同源後 CORS 允許清單簡化，IP 白名單需調整

## Impact

**涉及的服務與前端**：
- api-gateway (8000) — 路由重構（加 `/api` 前綴）
- persona-nexus-auth (5173)、persona-nexus-character (5174)、persona-nexus-lobby (5175)、persona-nexus-chat (5176) — API 呼叫改相對路徑、跳轉改相對路徑、設 base 路徑
- 新增基礎設施：Caddy 反向代理、docker-compose

**API 契約變化**：
- gateway 對外 API 前綴全改：`/auth/*` → `/api/auth/*`、`/characters/*` → `/api/characters/*`、`/conversations/*` → `/api/conversations/*`、`/users/*` → `/api/users/*`
- `/api/config` 已正確，無需改動
- `/internal/*` 保持不變（內部專用，不對外暴露）

**環境變數新增**：
- `CADDY_DOMAIN`（反向代理監聽的域名或 localhost）
- docker-compose 可能需新環境變數指向各服務的內網位址

**向後相容性**：
- 這是一個**大規模破壞性變動**（API 路由全改、前端 API 呼叫全改）
- 不相容舊客户端（會 404）；必須前端、後端同步更新
- 無遷移路徑，直接切新架構
