# API Prefix Standardization

## ADDED Requirements

### Requirement: 所有對外 API 路由加 `/api` 前綴
api-gateway 對瀏覽器暴露的所有路由 MUST 統一加 `/api` 前綴。內部路由（`/internal/*`）保持不變但禁止對外。

#### Scenario: 認證路由前綴
- **WHEN** 前端呼叫登入端點
- **THEN** 路由應為 `POST /api/auth/login`（而非 `/auth/login`）

#### Scenario: 資源路由前綴
- **WHEN** 前端查詢使用者或角色
- **THEN** 路由應為 `GET /api/users/{id}`、`GET /api/characters` 等（而非直接 `/users`、`/characters`）

#### Scenario: 內部路由隔離
- **WHEN** gateway 處理內部服務間通信
- **THEN** 內部路由 `/internal/rag/conversations` 保持不變，但 IP 白名單確保只有內網可訪問

### Requirement: 配置管理端點
`GET /api/config` 端點 MUST 存在，回傳平台配置（原有規格保持）。

#### Scenario: 前端啟動獲取配置
- **WHEN** 前端在 `initApp()` 時呼叫 `/api/config`
- **THEN** 回傳 JSON：`{ services: { gateway: "..." }, frontends: { ... } }`

