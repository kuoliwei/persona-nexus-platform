## Context

目前平台架構為多 origin：四個前端（5173-5176）各自一個 port、gateway 一個 port (8000)。前端寫死 `http://localhost:8000` 調用 gateway，跨前端跳轉也寫死各自的 port。這導致：
- 瀏覽器認定 5 個不同 origin，CORS 需逐一配置
- Bootstrap 網址（前端啟動時先要找 gateway）形成「先有雞生蛋」的問題
- 環境變數零散，難以部署到不同環境（dev/staging/prod）

同源部署目標是統一對外入口（Caddy 反向代理），讓瀏覽器只看到一個 origin，內部再依路徑分流。

**涉及的系統邊界：**
- **對外**：Caddy 監聽單一埠（443/HTTPS 或 80/HTTP，或開發時 8080），終結 HTTPS、提供唯一網址
- **內網**：Caddy 依路徑轉給前端靜態檔或 gateway；gateway 再轉給各後端微服務；後端仍用內網 port（3000-6001）
- **前端**：四個獨立 Vite 專案，build 出靜態檔各佔不同路徑

## Goals / Non-Goals

**Goals:**
- 消除跨域（CORS）問題——瀏覽器只認一個 origin
- 簡化前端環境配置——API 呼叫用相對路徑，無需寫死主機名
- 為公網部署打基礎——統一的對外入口便於配置域名、HTTPS、防火牆
- 保持後端微服務獨立——內網架構不變，各服務仍用自己的 port

**Non-Goals:**
- GPU/ai-service 的部署問題（本次不涉及）
- 性能優化（反向代理無額外瓶頸，但本次不做性能測試）
- 從舊架構無縫遷移（這是破壞性變動，需完整切換）
- 多區域或地理分布式部署

## Decisions

### 1. 用 Caddy 而非 Nginx 作反向代理

**決策**：Caddy v2
**原因**：
- HTTPS 自動化（Let's Encrypt 自動申請、續期），無需手動管理憑證
- 設定檔語法簡潔直觀（Caddyfile vs Nginx 囉嗦的 `server` 塊）
- 對新手友善，學習曲線平緩

**替代方案考慮**：
- Nginx：成熟、性能頂級、資料豐富，但 HTTPS 憑證管理複雜
- HAProxy：功能強，但語法更複雜
- Node.js Express 自己當代理：簡單但性能損失、HTTPS 複雜

### 2. Gateway 所有路由統一加 `/api` 前綴

**決策**：所有對外路由改為 `/api/auth`、`/api/characters` 等；`/internal/*` 絕不對外暴露
**原因**：
- 清晰分離 API 與前端頁面路徑（業界標準做法）
- 避免路徑衝突（前端頁面 `/auth` 和 API `/auth` 不會打架）
- 便於未來 API 版本管理（可擴展成 `/api/v2/...`）

**替代方案考慮**：
- 前端都加 `/app/` 前綴：改動少但前端路徑冗長，不符合使用者期待
- 各服務各自子域名（`auth.localhost`）：徹底同源但複雜且浪費

### 3. 前端頁面路徑：lobby `/`、auth `/login`、character `/character`、chat `/chat`

**決策**：如方案 A（見 proposal）
**原因**：
- `/login` 清晰表意，業界慣例
- 避開 API 路徑 `/auth` 的衝突
- 對使用者友善（網址易懂）

**替代方案考慮**：
- 都用複數形（`/auths`、`/characters`、`/chats`）：對稱但 `/auths` 語義差
- 都在 `/app/` 下：統一但冗長

### 4. 前端改用相對路徑調用 API，各自設 Vite `base`

**決策**：
- 所有 API 呼叫從 `fetch('http://localhost:8000/auth/login')` → `fetch('/api/auth/login')`
- 各前端 `vite.config.js` 設 `base: '/'` / `base: '/login/'` / 等

**原因**：
- Bootstrap 問題消失（前端啟動時無需先知道 gateway 位址）
- 環境無關（localhost、127.0.0.1、example.com 一套 code 通用）
- Vite 的 `base` 自動調整資源路徑，build 流程標準化

**實現細節**：
- `fetch('/api/config')` 這類相對路徑，瀏覽器會補當前網域
- 若在 `http://localhost:3000/chat/`，`fetch('/api/x')` 自動變成 `http://localhost:3000/api/x`
- 同源，無跨域問題

### 5. 部署配置納入 git，根目錄建立版本控制 & Docker 內網通信用 service name

**決策**：
- 建 `openspec/changes/same-origin-deployment/` OpenSpec 規格
- 建 `deploy/Caddyfile`、`deploy/docker-compose.yml`
- 根目錄 `git init`，納管部署檔與 ARCHITECTURE.md
- **Docker 容器間通信改用 service name（`gateway`、`chat-service` 等），不硬寫 IP**

**原因**：
- 部署是一等公民，不能只存本機
- 團隊新成員可用 docker-compose 一鍵起環境
- OpenSpec 記錄設計決策與實裝檢查清單
- **容器重啟時 IP 會變化**，硬 IP 導致連線斷裂或白名單失效；service name 由 Docker 內置 DNS 解析，永久有效

### 6. CORS 與 `/internal/*` 安全

**決策**：
- 同源後，gateway 的 `FRONTEND_ORIGIN` 許可清單大幅縮減（同源自動允許）
- `/internal/*` 路由**永遠不經 Caddy**，只在內網暴露，gateway 層做 IP 白名單（用 service name，不硬 IP）

**原因與說明**：
- **CORS 的角色**：browser 預設禁止跨 origin 請求（不同網域 = 不同 origin）。當前多 origin 架構下（lobby 5175 ≠ gateway 8000），gateway 必須在 header 加 `Access-Control-Allow-Origin` 來許可 CORS。同源後，瀏覽器自動允許（同網域），無需 CORS header，簡化部署
- **`/internal/*` 隔離**：後端內部通信（ai-service ← chat-service）不能對外暴露；前端永遠只打 `/api/*`，內部路由靠 IP 白名單防護

## Risks / Trade-offs

| 風險 | 影響 | 緩減 |
|------|------|------|
| **破壞性變動** — API 路由全改，舊客户端 404 | 中 | 必須前後端同時切換；提前通知；無舊版相容 |
| **路徑衝突** — 若未來新增服務用了 `/login`、`/character` 等前端路徑 | 低 | 明文規定前端頁面路徑清單；在部署指南寫死 |
| **Docker 內網 IP 變化** — 容器重啟後 IP 可能改變（影響 IP 白名單） | 中 | 用 Docker 網路別名（`gateway` service 名），不用硬 IP；gateway 已改 `/internal/*` 用 service name |
| **HTTPS 憑證過期** — 無人監視時逾期 | 低 | Caddy 自動續期；監控告警（future work） |
| **前端 build 產物路徑錯誤** — 若 `base` 設錯會導致資源 404 | 中 | 測試清單明確逐一驗證；build 產物檢查工具（future） |
| **迴圈重定向** — Caddy 轉 `/login/` 時若 gateway 誤配會造成無限迴圈 | 中 | 嚴格分離：`/api/*` → gateway，`/login/*` → 前端靜態檔；單元測試路由規則 |

## Migration Plan

### Phase 1：準備（不上線）
1. 建立 OpenSpec 規格（本文件）
2. 根目錄 git init，納管部署檔
3. 編寫 `deploy/Caddyfile` 試運行
4. 各前端本地驗證 `base` 設置（`npm run build` 後檢查產物）

### Phase 2：後端改造
1. api-gateway 路由全加 `/api` 前綴
2. 更新 `.env.example` 新增 `CADDY_DOMAIN` 等
3. 測試 gateway `/internal/*` 仍可內網訪問

### Phase 3：前端改造（同步進行，四個前端各自一支分支）
1. 所有 `fetch('http://localhost:8000/...')` 改 `fetch('/api/...')`
2. 各前端 `vite.config.js` 設 `base`
3. 跨前端跳轉改為相對路徑
4. 本地驗證（用 Caddy localhost 發開發伺服器 reverse_proxy）

### Phase 4：整合測試
1. 起 Caddy (8080)、四個前端、gateway、後端服務
2. 測試路由分流（`localhost:8080/`、`/login`、`/character`、`/chat` 各能正確載入）
3. 測試跨前端跳轉（不再寫死 port）
4. 測試 API 呼叫（相對路徑、不寫主機名）

### Phase 5：文件與交付
1. 更新 ARCHITECTURE.md（加入同源架構說明）
2. 編寫部署指南（Caddy 配置、docker-compose 啟動）
3. 環境變數文件更新

**回滾策略**：這是基礎架構變動，無法真正回滾。若發現重大問題，需停止切換、保持舊架構運行，等修復後再試。不建議部分切換。

## Open Questions

1. **根目錄 git 初始化的 CI/CD 影響**：獨立的 6 個微服務 repo 怎麼跟根目錄 repo 協作？需要 git submodule 或複製？
2. **ai-service 的同源部署**：ai-service 現在本機 GPU 跑，同源後如何處理？（暫時先不考慮，後續 issue）
3. **生產環境 HTTPS 憑證**：Caddy 申請 Let's Encrypt 需公網域名 + 能訪問 80/443，開發時用 localhost 自簽憑證怎麼配？
4. **前端頁面 404 時**：用戶手動輸入錯路徑（如 `/typo`），Caddy 應回 404 還是重導 Lobby？
5. **WebSocket 支援**：chat-service 未來若用 WebSocket，Caddy 怎麼配置轉發？

