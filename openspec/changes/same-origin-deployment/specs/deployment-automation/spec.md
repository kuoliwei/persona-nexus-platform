# Deployment Automation

## ADDED Requirements

### Requirement: docker-compose.yml 一鍵啟動
`deploy/docker-compose.yml` MUST 定義整套系統（Caddy + 四個前端 build + gateway + 所有後端服務）的啟動配置，使用 `docker-compose up -d` 即可拉起。

#### Scenario: 本機開發啟動
- **WHEN** 開發者執行 `cd deploy && docker-compose up -d`
- **THEN** 容器啟動，服務可訪問（Caddy 監聽 8080、gateway 在容器內網 :8000 等）

#### Scenario: 環境變數注入
- **WHEN** docker-compose 啟動時讀取 `.env` 或傳入 `-e` 參數
- **THEN** 各服務收到正確的環境變數（如 `JWT_SECRET`、`CADDY_DOMAIN`）

### Requirement: Caddyfile 反向代理配置
`deploy/Caddyfile` MUST 包含完整的路由配置（见 same-origin-routing 規格），支援開發環境（localhost:8080）和生產環境（real domain）兩種模式。

#### Scenario: 開發環境配置
- **WHEN** Caddyfile 配置 `:8080 { ... }`
- **THEN** Caddy 監聽本機 8080，支援 reverse_proxy 到內網服務

#### Scenario: 生產環境配置
- **WHEN** Caddyfile 配置 `persona-nexus.com { ... }`
- **THEN** Caddy 自動申請 HTTPS、監聽 80/443、轉發到內網服務

### Requirement: 部署清單文件
`deploy/README.md` 或類似檔案 MUST 說明：
- docker-compose 的啟動步驟
- 環境變數清單
- 如何驗證各服務是否正常（健康檢查端點）
- 常見問題與排查方法

#### Scenario: 新開發者快速上手
- **WHEN** 新人閱讀 `deploy/README.md`
- **THEN** 能 copy-paste 指令拉起環境、理解各服務職責

