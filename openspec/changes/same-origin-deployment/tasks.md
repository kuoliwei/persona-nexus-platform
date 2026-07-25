# Same-Origin Deployment — Implementation Tasks

## 1. 準備與基礎設施（2-3h）

- [x] 1.1 根目錄 `git init`，建 `.gitignore` 排除 `ai-service/`, `auth-service/`, `user-service/`, `character-service/`, `chat-service/`, `persona-nexus-*` 等微服務資料夾
- [x] 1.2 建立 `deploy/` 目錄，新增 `Caddyfile`（開發環境 `:8080` 配置）
- [x] 1.3 編寫 `deploy/docker-compose.yml`，定義 Caddy + 四個前端 build + gateway + 後端服務容器
- [x] 1.4 建 `deploy/README.md`，文檔化啟動步驟、環境變數、健康檢查方法
- [x] 1.5 驗證：本地 `cd deploy && docker-compose config` 語法檢查通過

## 2. API Gateway 路由重構（3-4h）

- [x] 2.1 api-gateway `src/app.js`：修改所有 `app.use()` 路由，統一加 `/api` 前綴
  - `/auth/*` → `/api/auth/*`
  - `/users/*` → `/api/users/*`
  - `/characters/*` → `/api/characters/*`
  - `/conversations/*` → `/api/conversations/*`
  - `/api/config` 保持不變（已正確）
  - `/internal/*` 路由保持不變但禁止對外暴露
- [x] 2.2 api-gateway 各 proxy 檔（authProxy.js、userProxy.js 等）的 `pathRewrite` 邏輯隨之調整（檢查轉發到後端的路徑仍正確）
- [x] 2.3 更新 `.env.example`：新增 `CADDY_DOMAIN`、`CADDY_PORT` 等
- [x] 2.4 驗證：gateway 啟動後，`curl http://localhost:8000/api/config` 回傳 200 OK

## 3. 前端 JavaScript 改造——相對路徑（8-10h，四個前端平行進行）

### 3.1 persona-nexus-auth
- [x] 3.1.1 `src/api.js`：`const BASE_URL = 'http://localhost:8000'` → 移除或改相對 `/api`
- [x] 3.1.2 所有 `fetch()` 改為相對路徑（`fetch('/api/auth/register')` 等）
- [x] 3.1.3 `src/config-loader.js`：`fetch('http://localhost:8000/api/config')` → `fetch('/api/config')`
- [x] 3.1.4 跨前端跳轉（登入成功後跳大廳）改為 `window.location.href = '/'`

### 3.2 persona-nexus-character
- [x] 3.2.1 `src/api.js`：`const BASE_URL = 'http://localhost:8000'` → 相對路徑
- [x] 3.2.2 所有 `fetch()` 改為相對路徑
- [x] 3.2.3 `src/config-loader.js` 改為相對路徑
- [x] 3.2.4 跨前端跳轉（返回大廳、返回登入）改為相對路徑

### 3.3 persona-nexus-lobby
- [x] 3.3.1 `src/api.js`：改相對路徑
- [x] 3.3.2 所有 `fetch()` 改為相對路徑
- [x] 3.3.3 `src/config-loader.js` 改為相對路徑
- [x] 3.3.4 跨前端跳轉改為相對路徑

### 3.4 persona-nexus-chat
- [x] 3.4.1 `src/chat.js`：`const GATEWAY_URL = 'http://localhost:8000'` → 移除，改用 `/api/...`
- [x] 3.4.2 所有 `fetch()` 改為相對路徑
- [x] 3.4.3 `src/config-loader.js` 改為相對路徑
- [x] 3.4.4 跨前端跳轉改為相對路徑

## 4. 前端 Vite 配置——base 設定（1-2h，四個前端平行進行）

- [x] 4.1 persona-nexus-auth `vite.config.js`：加 `base: '/login/'`
- [x] 4.2 persona-nexus-character `vite.config.js`：加 `base: '/character/'`
- [x] 4.3 persona-nexus-lobby `vite.config.js`：加 `base: '/'` （或確認未設 base，預設即為 `/`）
- [x] 4.4 persona-nexus-chat `vite.config.js`：加 `base: '/chat/'`
- [x] 4.5 驗證：各前端 `npm run build` 產生的 `dist/index.html` 裡，`<script src="/...">` 路徑包含正確的前綴（e.g., `/login/src/main.js`）

## 5. 前端配置中心簡化（1-2h）

- [x] 5.1 檢查四個前端的 `config-loader.js`，簡化 `frontends` 物件（可移除各前端網址清單）
- [x] 5.2 驗證前端啟動時不再依賴 `config.frontends.xxx` 這類數據（改用相對路徑跳轉）

## 6. CORS 與安全規則（1-2h）

- [x] 6.1 api-gateway `src/config/services.js` 或 CORS 設定：更新 `FRONTEND_ORIGIN` 允許清單，同源後可大幅簡化（例如只需 `http://localhost` 或 `persona-nexus.com`）
- [x] 6.2 api-gateway `/internal/*` 的 IP 白名單檢查：確保用 Docker 服務名（`gateway` 等）而非硬 IP，避免容器重啟後失效
- [x] 6.3 驗證：訪問 `/api/internal/rag/conversations` 時被 gateway 攔截（401 或 IP 白名單失敗）

## 7. 整合測試（2-3h）

- [x] 7.1 本機起 Caddy (8080)、四個前端 dev server、gateway、後端服務
  - 方式 A：Docker compose（`docker-compose up -d` 在 `deploy/` 目錄）
  - 方式 B：手動逐個啟動（適合開發 debug）
- [x] 7.2 測試路由分流：
  - `curl http://localhost:8080/` → 拿到 lobby 首頁 HTML
  - `curl http://localhost:8080/login` → 拿到 auth 首頁 HTML
  - `curl http://localhost:8080/api/config` → gateway 回傳 JSON
- [x] 7.3 測試 API 呼叫：前端打 `/api/auth/login`、`/api/characters` 等
- [x] 7.4 測試跨前端跳轉：lobby → login → character → chat，確保相對路徑生效
- [x] 7.5 測試單頁應用回退：訪問 `http://localhost:8080/chat/conversation/123`（不存在的靜態檔），應回傳 chat 的 `index.html`

## 8. 文件與交付（1-2h）

- [ ] 8.1 更新 `ARCHITECTURE.md`：加入同源部署架構說明（加一章「Deployment」）
- [ ] 8.2 更新各微服務的 `.env.example`：確認新增的環境變數都列上（如 `CADDY_DOMAIN`）
- [ ] 8.3 驗證：根目錄已納入版本控制（.gitignore 正確、可 `git status`）
- [ ] 8.4 建立或更新 `CONTRIBUTING.md`：新開發者怎麼用 docker-compose 起環境

## 實作偏離與待辦（Phase 1-4 驗證後更新）

**部署模型變更**：前端改為「主機建置靜態檔、Caddy 直接 serve」，不再於容器內跑 Vite dev server。
因此 docker-compose 移除四個前端服務，改掛載各自 `dist/`；Vite 也不需要 `host: '0.0.0.0'`。
Caddyfile 拆成兩份：`Caddyfile`（主機模式，proxy 到 dev server）與 `Caddyfile.docker`（靜態 serve）。

**驗證中發現並修正的缺陷**：
- `app.use('/api/x', proxy)` 會剝除掛載前綴，故 character/chat proxy 的 regex pathRewrite 完全失效，已改回函式 prepend 形式
- Caddyfile 原有的 `@notapi`/`file`/`try_files` 區塊無效；`handle /` 只匹配根路徑，會漏掉 `/assets/*`
- 前端仍有約 10 處跨源網址未轉換（含 HTML 內嵌腳本），以及 `//?token=`、`//my-characters` 兩類協定相對 URL bug
- 既有缺陷：character/index.html import 了不存在的 `getConfig`，production build 本來就失敗
- 既有缺陷：lobby 執行期 fetch 的 5 個 HTML 片段未進 dist，已移至 `public/src/`
- 既有缺陷：character 多頁入口未列入 Vite build input

**Phase 5-6 補充**：
- `/api/config` 已移除 `services`/`frontends` 網址清單，只回 `{ apiBase, environment }`；端點保留作為前端啟動時的後端可達性探測
- CORS 改為 opt-in：`FRONTEND_ORIGIN` 預設為空時完全不掛 `cors()`。實測即使帶 `Origin` 標頭也不回傳任何 `Access-Control-*`
- `internalAuthMiddleware` 原本的私有網段判斷漏了 `172.16.0.0/12`（Docker 預設 bridge 網段），容器互打 `/internal/*` 會被自己擋掉；已改寫並以 15 個邊界案例覆蓋
- chat 前端已完全不需要設定，`config-loader.js` 已刪除

**Phase 7 整合測試結果（全服務實機啟動）**：
- 路由分流、SPA 深層回退、四個前端身分辨識全部通過
- 真實 API 流程通過同源 :8080 驗證：註冊 201、登入 200、`/api/characters` 讀寫、`/api/conversations/summary`、`/api/users/:id`
- 未帶 token 的 `/api/characters` 正確回 401
- `/internal/*` 在 :8080 落到 lobby SPA fallback（回 HTML），未對外暴露；直連 :8000 才會進到 ai-service
- 修正：`/login`、`/character`、`/chat` 無結尾斜線時 404（Vite base 不匹配），已於 Caddy 加正規化重導
- 修正：`/api/users/*` 因缺少 pathRewrite 一律 404（既有缺陷，早於本次改造）
- 7.4 說明：跨前端目標路徑均已驗證可正確解析到對應應用；實際瀏覽器點擊流程未以 curl 覆蓋

**發現的安全問題（原列為不在本次範圍、需另案處理，✅ 已於 2026-07-25 修復並於 2026-07-26 正式測試驗證）**：
- ~~`GET /api/users/:id` 回傳完整使用者物件，**包含 bcrypt 密碼雜湊**。此端點先前因 404 而未被觸及，修好路由後這個外洩才變成實際可達。應在 user-service 的 controller 過濾掉 password 欄位。~~
- 修復記錄：`user-service/src/controllers/userController.js` 的 `toPublicUser()` 已在回傳前濾掉 `password` 欄位（`微服務架構實作spec.md` 落差稽核 `mistakes.md` 未把這個欄位過濾列為獨立問題，是因為 pathRewrite 沒修好前這條路由本來就 404 打不到，過濾邏輯其實已存在，只是不可達）。2026-07-26 進階整合測試案例 G1（`GET /api/users/:id` 帶合法 token）實測回傳 `200`，body 僅含 `{id, email}`，不含 `password`，確認外洩已排除。

**仍未完成（docker 模式的最後阻礙）**：
- [ ] 各後端專案（api-gateway、auth/user/character/chat/ai-service）尚無 `Dockerfile`，`docker-compose up --build` 會失敗

## 檢查與驗收標準

- ✓ 所有相對路徑改寫完成，無寫死 `http://localhost:port` 字串殘留
- ✓ Caddy Caddyfile 配置正確，本地 8080 測試通過
- ✓ docker-compose 能起全套系統，無容器啟動失敗
- ✓ 四個前端 build 產物位置正確（各自路徑底下的 `index.html`）
- ✓ 跨域問題消失（所有路由同源）
- ✓ 文檔齊全，新人能跟著流程快速起環境

