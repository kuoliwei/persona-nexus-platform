## 1. 規格驗證 & 文檔化

- [ ] 1.1 驗證使用者認證規格與 auth-service 實現相符
  - 檢查 bcrypt saltRounds=10 是否被使用
  - 驗證 JWT_SECRET 在 auth-service 和 api-gateway 間的同步
  - 確認密碼永遠不被記錄或在錯誤訊息中暴露
  - 預期時間：1 小時

- [ ] 1.2 驗證使用者帳號管理規格與 user-service 實現相符
  - 確認電子郵件唯一性約束被強制執行
  - 檢查 GET /users?email= 對不存在的使用者回傳 404
  - 驗證密碼欄位儲存預先雜湊的值
  - 預期時間：1 小時

- [ ] 1.3 驗證角色管理規格與 character-service 實現相符
  - 確認 tags 和 fewShots 被序列化為 JSON 字串至資料庫
  - 檢查 visibility=private 防止未授權存取
  - 驗證 introduction 欄位是必填（遷移已應用）
  - 確認 authorId 基礎的擁有權檢查正常運作
  - 預期時間：1.5 小時

- [ ] 1.4 驗證對話管理規格與 chat-service 實現相符
  - 確認 Conversation 和 Message 表存在，具正確的關係
  - 檢查對話刪除時的 CASCADE DELETE
  - 驗證訊息不可變性（訊息上無 PUT/DELETE）
  - 確認 userId 基礎的存取控制有效
  - 預期時間：1.5 小時

- [ ] 1.5 驗證 api-gateway 路由和 JWT 驗證
  - 測試 /auth/register 和 /auth/login 略過 JWT 中介層
  - 驗證所有其他路由需要有效 JWT
  - 檢查 x-user-id header 在 JWT 驗證後被注入
  - 確認路徑重寫正常運作（/characters → /api/v1/characters）
  - 測試 CORS 白名單包含所有前端連接埠
  - 預期時間：2 小時

---

## 2. 記憶 & RAG 整合驗證

- [ ] 2.1 驗證短期記憶檢索
  - 確認 chat-service 回傳所有未摘要的訊息
  - 測試訊息是否正確標記為 summarized 旗標
  - 驗證訊息排序是時間順序
  - 預期時間：1 小時

- [ ] 2.2 驗證訊息閾值觸發摘要
  - 確認未摘要計數達到 50（可設定）時觸發摘要
  - 檢查較舊訊息是否標記為已摘要
  - 驗證最新訊息始終保留在短期
  - 預期時間：1.5 小時

- [ ] 2.3 驗證 Qdrant 的 RAG 整合
  - 確認 ai-service 可連接到 Qdrant
  - 測試摘要的嵌入生成
  - 驗證語義相似度搜尋回傳前 K 條結果
  - 檢查最新摘要始終被包含
  - 預期時間：2 小時

- [ ] 2.4 測試端到端記憶流程
  - 建立長對話（50+ 條訊息）
  - 驗證摘要已生成並儲存
  - 生成角色回覆並確認 RAG 檢索有效
  - 檢查角色在摘要邊界上維持個性
  - 預期時間：2 小時

---

## 3. 資料持久化驗證

- [ ] 3.1 驗證 Prisma 遷移已就位
  - user-service：User 表遷移
  - character-service：Character 表 + make_introduction_required 遷移
  - chat-service：Conversation 和 Message 表遷移
  - 在每個服務中執行 `npx prisma migrate status` 以確認
  - 預期時間：1 小時

- [ ] 3.2 驗證 SQLite 資料庫檔案建立正確
  - 確認 dev.db 檔案存在於每個服務的 prisma/ 目錄
  - 檢查檔案許可允許讀/寫
  - 驗證資料庫可用 `sqlite3` CLI 檢查
  - 預期時間：30 分鐘

- [ ] 3.3 驗證 Prisma 客戶端正確初始化
  - 檢查 src/lib/prisma.js 匯出單例實例
  - 確認所有服務使用單個 Prisma 連接
  - 驗證 libSQL 適配器設定正確
  - 預期時間：1 小時

- [ ] 3.4 測試資料庫備份和還原流程
  - 記錄備份 SQLite 檔案的程序
  - 建立備份，刪除原始檔案，從備份還原
  - 驗證還原後的資料完整性
  - 預期時間：1 小時

---

## 4. 錯誤處理 & 程式碼標準化

- [ ] 4.1 驗證錯誤碼在所有服務間一致
  - 檢查 EMAIL_ALREADY_EXISTS 始終回傳 409
  - 驗證 CHARACTER_NOT_FOUND 始終回傳 404
  - 測試錯誤回應格式：`{ status: "error", message: "..." }`
  - 預期時間：1.5 小時

- [ ] 4.2 驗證錯誤碼已被記錄
  - 確認每個服務的錯誤碼列在其規格中
  - 檢查 CLAUDE.md 檔案參考錯誤處理約定
  - 預期時間：1 小時

- [ ] 4.3 測試錯誤情境
  - 測試 user-service 從 auth-service 無法連接時會發生什麼
  - 測試資料庫被鎖定或損壞時會發生什麼
  - 測試 JWT_SECRET 不正確時會發生什麼
  - 驗證錯誤訊息不洩露敏感資訊
  - 預期時間：1.5 小時

---

## 5. 環境 & 組態驗證

- [ ] 5.1 驗證 .env 檔案在所有服務間一致
  - 檢查 JWT_SECRET 在 auth-service 和 api-gateway 中相同
  - 驗證服務 URL 正確（auth-service、user-service 等）
  - 確認 FRONTEND_ORIGIN 包含全部 4 個前端連接埠
  - 預期時間：1 小時

- [ ] 5.2 更新 .env.example 檔案
  - 在每個服務中建立/更新 .env.example
  - 確保 .env.example 反映現時 .env 結構
  - 新增說明每個變數的註解
  - 預期時間：1 小時

- [ ] 5.3 驗證環境變數載入
  - 測試僅用 .env.example 啟動服務（應優雅失敗）
  - 測試用正確 .env 啟動服務
  - 驗證可選變數的預設值有效
  - 預期時間：1 小時

---

## 6. API 契約測試

- [ ] 6.1 測試使用者認證流程
  - 註冊新使用者：POST /auth/register
  - 用正確密碼登入：POST /auth/login → 回傳 JWT
  - 用錯誤密碼登入 → 回傳 400
  - 驗證 JWT 有效且包含正確的使用者 ID
  - 預期時間：1 小時

- [ ] 6.2 測試使用者帳號操作
  - GET /users/:id，包含有效 JWT
  - GET /users?email=xxx 檢查電子郵件存在
  - DELETE /users/:id，包含擁有權檢查
  - 驗證 x-user-id header 被 user-service 信任
  - 預期時間：1 小時

- [ ] 6.3 測試角色操作
  - 建立角色：POST /characters
  - 列出角色：GET /characters?authorId=xxx
  - 檢索角色：GET /characters/:id
  - 更新角色：PUT /characters/:id
  - 刪除角色：DELETE /characters/:id
  - 驗證擁有權檢查有效
  - 預期時間：1.5 小時

- [ ] 6.4 測試對話操作
  - 建立對話：POST /conversations
  - 列出對話：GET /conversations
  - 發送訊息：POST /conversations/:id/messages
  - 檢索訊息，包含分頁：GET /conversations/:id/messages
  - 驗證存取控制有效
  - 預期時間：1.5 小時

- [ ] 6.5 測試 gateway 路由和 CORS
  - 驗證位於 5173 的前端可連接位於 8000 的 gateway
  - 測試 OPTIONS 請求的 CORS preflight
  - 測試來自非白名單來源的請求失敗
  - 驗證 Authorization header 被正確處理
  - 預期時間：1 小時

---

## 7. 前端整合測試

- [ ] 7.1 測試 persona-nexus-auth（登入/註冊前端）
  - 註冊流程：提交表單 → 收到 JWT
  - 登入流程：提交表單 → 收到 JWT
  - 在 localStorage 中儲存 JWT（目前缺失）
  - 成功登入後重新導向至大廳（目前缺失）
  - 預期時間：2 小時

- [ ] 7.2 測試 persona-nexus-character（建立者前端）
  - 建立角色：表單 → POST /characters
  - 編輯角色：載入現有 → PUT /characters/:id
  - 驗證角色擁有者檢查有效
  - 測試 tags 和 fewShots 輸入/輸出
  - 預期時間：1.5 小時

- [ ] 7.3 測試 persona-nexus-lobby（首頁/畫廊前端）
  - 列出使用者的角色
  - 登入守門：沒有 JWT 時重新導向至認證
  - 「建立角色」按鈕導航至角色建立者
  - 預期時間：1 小時

- [ ] 7.4 測試 persona-nexus-chat（對話前端）
  - 載入現有對話
  - 發送訊息並在 UI 中顯示
  - 接收角色回覆（來自 ai-service 透過 chat-service）
  - 處理長對話（>50 條訊息）
  - 預期時間：2 小時

---

## 8. 文檔 & 知識轉移

- [ ] 8.1 用當前實現狀態更新 CLAUDE.md 檔案
  - auth-service：確認 JWT 流程、密碼處理
  - user-service：確認 CRUD 操作、錯誤處理
  - character-service：確認可見性規則、序列化
  - chat-service：確認訊息不可變性、分頁
  - api-gateway：確認路由、JWT 驗證、CORS
  - 每個檔案應參考 OpenSpec 規格
  - 預期時間：2 小時

- [ ] 8.2 建立快速開始指南
  - 記錄如何在本機執行所有服務
  - 列出環境變數和預設值
  - 為每個 API 端點提供範例 curl 指令
  - 預期時間：1.5 小時

- [ ] 8.3 記錄已知限制和技術債
  - persona-nexus-auth 不在 localStorage 中儲存 JWT
  - persona-nexus-character 繞過 gateway（應使用 8000）
  - auth 端點上無速率限制
  - 無使用者刪除級聯邏輯
  - 無刷新令牌端點
  - 預期時間：1 小時

- [ ] 8.4 建立故障排除指南
  - JWT 驗證失敗：原因和修復
  - CORS 錯誤：如何除錯和解決
  - 資料庫連接問題
  - 服務啟動順序依賴
  - 預期時間：1 小時

---

## 9. 測試 & 品質保證

- [ ] 9.1 執行現有單元測試
  - auth-service：`npm test`（16 個測試案例）
  - character-service：`npm test`（service 層測試）
  - 驗證所有都通過
  - 預期時間：1 小時

- [ ] 9.2 手動煙霧測試
  - 完整註冊 → 登入 → 建立角色 → 開始對話流程
  - 測試錯誤情境（無效電子郵件、重複電子郵件、錯誤密碼）
  - 測試授權（使用者無法存取其他使用者的資料）
  - 預期時間：2 小時

- [ ] 9.3 負載測試（可選）
  - 建立 100 個使用者
  - 為每個使用者建立 50 個對話
  - 在一個對話中生成 50+ 條訊息
  - 測量回應時間和資料庫效能
  - 預期時間：2 小時

- [ ] 9.4 安全審查
  - 檢查 SQL 注入漏洞（Prisma 應防止）
  - 檢查前端中的 XSS 漏洞
  - 驗證 CORS 不允許意外來源
  - 驗證 JWT 祕鑰不被記錄任何地方
  - 預期時間：2 小時

---

## 10. 最終驗證 & 交接

- [ ] 10.1 驗證所有 OpenSpec 構件已完成
  - proposal.md ✓
  - specs/*.md（7 個檔案）✓
  - design.md ✓
  - tasks.md ✓

- [ ] 10.2 建立摘要檢查清單
  - 所有服務執行無錯誤
  - 所有規格已針對實現驗證
  - 所有已知限制已記錄
  - 所有環境變數已設定
  - 前端到後端整合正常運作
  - 預期時間：1 小時

- [ ] 10.3 為下一階段準備（剩餘 20% 功能）
  - 識別應首先處理的下一功能（前端令牌儲存、character bypass gateway 等）
  - 為最高優先級功能建立 OpenSpec 提案
  - 預期時間：1 小時

---

## 時間表摘要

**預計總工作量：** 30-35 小時

**推薦節奏：**
- 第 1 週：規格 1-2（7-8 小時）
- 第 2 週：規格 3-5（8-9 小時）
- 第 3 週：規格 6-8（8-9 小時）
- 第 4 週：規格 9-10（6-8 小時）

**關鍵路徑：**
1. API 契約測試（第 6 節）— 阻止所有其他驗證
2. 資料持久化（第 3 節）— 功能測試所需
3. 記憶 & RAG（第 2 節）— 僅當 chat-service 正常運作時
