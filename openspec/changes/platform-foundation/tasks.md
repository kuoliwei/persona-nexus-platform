> 2026-07-26 更新：本檔案原本 10 節全部是 `[ ]` 未勾選狀態，但其中不少項目已被 `執行日誌.md` 記錄的 T1-T22 修復、以及 2026-07-26 `進階整合測試task0726.md`（47 個案例 + 資料庫驗證 A/B + H6，共 50 項全數 PASS）實際驗證過。這次依「有實際證據佐證才打勾」的原則逐項核對：有直接測試或程式碼證據的項目打勾並附引用；只有部分證據的維持未打勾，但補上目前已知狀態的說明；完全沒有證據的維持原樣不動。證據來源三份：`mistakes.md`（2026-07-25 四方稽核）、`執行日誌.md`（T1-T22 修復記錄）、`測試清單-進階整合測試.md`／`進階整合測試task0726.md`（2026-07-26 正式測試）。

## 1. 規格驗證 & 文檔化

- [ ] 1.1 驗證使用者認證規格與 auth-service 實現相符
  - 檢查 bcrypt saltRounds=10 是否被使用
  - 驗證 JWT_SECRET 在 auth-service 和 api-gateway 間的同步
  - 確認密碼永遠不被記錄或在錯誤訊息中暴露
  - 預期時間：1 小時
  - **狀態**：部分驗證。回應格式與狀態碼已於 2026-07-26 案例 1（註冊/登入）、G3、J1 實測，`EMAIL_ALREADY_EXISTS` 已於 T22 修正為 409；JWT 能在 gateway 端成功驗證代表 `JWT_SECRET` 確實同步（貫穿全部 50 項測試皆依賴此前提成立）。但 `bcrypt saltRounds=10` 與「密碼不被記錄」兩點沒有本輪獨立測試證據（2026-07-25 四方稽核也未把這兩點列為落差，但未逐行覆核），故不打勾。

- [x] 1.2 驗證使用者帳號管理規格與 user-service 實現相符
  - 確認電子郵件唯一性約束被強制執行
  - 檢查 GET /users?email= 對不存在的使用者回傳 404
  - 驗證密碼欄位儲存預先雜湊的值
  - 預期時間：1 小時
  - **證據**：`user-account-management/spec.md` 已於 2026-07-25 依 T4/T5/T7/T13 同步；電子郵件唯一性經 G2/G3（`待辦task.md` T4-T7）與 J1 一併驗證（`EMAIL_ALREADY_EXISTS` 409）；`GET /users?email=` 現已限定僅供內部呼叫（T7 修復，見 `mistakes.md` M1），非內部呼叫會被拒於 403，此變化已反映在 spec；密碼欄位由 auth-service 預先雜湊後原樣儲存（design.md 決策 6）。「對不存在的使用者回傳 404」本身的行為未變，但存取前提已從原任務描述的「公開查詢」改為「限內部呼叫」。

- [x] 1.3 驗證角色管理規格與 character-service 實現相符
  - 確認 tags 和 fewShots 被序列化為 JSON 字串至資料庫
  - 檢查 visibility=private 防止未授權存取
  - 驗證 introduction 欄位是必填（遷移已應用）
  - 確認 authorId 基礎的擁有權檢查正常運作
  - 預期時間：1.5 小時
  - **證據**：`visibility=private` 防未授權存取於 2026-07-26 大量案例驗證（13/15/16、H1/H3/H6、L1-L3 對照組），並經 T21 修復跨服務繞過漏洞；`authorId` 擁有權檢查於案例 3-5、L3 驗證；`introduction` 必填遷移（`make_introduction_required`）已列於 `data-persistence/spec.md`。`tags`／`fewShots` JSON 序列化本輪測試建角色時未特別帶這兩個欄位驗證，僅沿用先前 character 前端清單已驗證過的基礎行為，未重新測試。

- [ ] 1.4 驗證對話管理規格與 chat-service 實現相符
  - 確認 Conversation 和 Message 表存在，具正確的關係
  - 檢查對話刪除時的 CASCADE DELETE
  - 驗證訊息不可變性（訊息上無 PUT/DELETE）
  - 確認 userId 基礎的存取控制有效
  - 預期時間：1.5 小時
  - **狀態**：部分過時，不打勾。`userId` 存取控制已大量驗證（H4/H5、J2、案例 7-16、案例 21/23）。但「訊息不可變性（無 PUT/DELETE）」這條檢查項目本身已與現況矛盾——`DELETE /api/conversations/:id/messages/:messageId` 回溯式刪除端點確實存在且是 2026-07-26 案例 20-23 的核心驗證對象，`conversation-management/spec.md` 開頭已加註說明此章節「訊息不可變性」部分為舊版描述、與現況不符。CASCADE DELETE 本輪未測試。

- [ ] 1.5 驗證 api-gateway 路由和 JWT 驗證
  - 測試 /auth/register 和 /auth/login 略過 JWT 中介層
  - 驗證所有其他路由需要有效 JWT
  - 檢查 x-user-id header 在 JWT 驗證後被注入
  - 確認路徑重寫正常運作（/characters → /api/v1/characters）
  - 測試 CORS 白名單包含所有前端連接埠
  - 預期時間：2 小時
  - **狀態**：多數子項已驗證，CORS 未測，故整體維持未打勾。`/auth/register`／`/auth/login` 略過 JWT：案例 1、G3、J1。其他路由需要 JWT：H2、H5（缺 token 一律 401）。`x-user-id` 注入：I1、J2、案例 13/15/16 等所有所有權檢查案例皆依賴此 header 存在。路徑重寫：G1（T1 修復的 `/api/users/:id` pathRewrite bug 驗證通過）。**CORS 白名單本輪完全未測試**（無 CORS preflight 案例），`api-gateway/spec.md` 也未把 CORS 列入 2026-07-25 同步範圍。

---

## 2. 記憶 & RAG 整合驗證

- [x] 2.1 驗證短期記憶檢索
  - 確認 chat-service 回傳所有未摘要的訊息
  - 測試訊息是否正確標記為 summarized 旗標
  - 驗證訊息排序是時間順序
  - 預期時間：1 小時
  - **證據**：資料庫驗證 A（案例 19 後）確認訊息依 `summaryId` 分段不交錯（summary1／summary2／NULL 三段有序）；案例 23 確認刪除後訊息列表排序與內容正確。

- [ ] 2.2 驗證訊息閾值觸發摘要
  - 確認未摘要計數達到 50（可設定）時觸發摘要
  - 檢查較舊訊息是否標記為已摘要
  - 驗證最新訊息始終保留在短期
  - 預期時間：1.5 小時
  - **狀態**：機制已驗證，但本項描述的觸發條件已過時，不打勾以避免誤導。實際觸發邏輯是**字數閾值**而非訊息計數：`chat-service/src/config/config.json` 的 `{summary:{threshold:500, maxWords:70, shortTermLimit:2}}`，`checkIfNeedsSummary` 把最新 2 條（`shortTermLimit`）以外的未摘要訊息文字長度加總，達 500 字才觸發（見 `測試清單-進階整合測試.md` 依據段落、`conversationService.js:69-107`）。2026-07-26 案例 17-19 已實測驗證觸發、標記、最新 2 條保留在短期的完整行為，機制本身沒問題，只是本任務描述的「訊息計數達到 50」與程式碼不符，需要先修正任務描述才能勾選。

- [x] 2.3 驗證 Qdrant 的 RAG 整合
  - 確認 ai-service 可連接到 Qdrant
  - 測試摘要的嵌入生成
  - 驗證語義相似度搜尋回傳前 K 條結果
  - 檢查最新摘要始終被包含
  - 預期時間：2 小時
  - **證據**：案例 18/19 透過 `list-summaries.ps1` 直接查詢 Qdrant `summaries` collection 確認摘要份數 0→1→2，且腳本內建孤兒一致性檢查（DB 有 `summaryId` 但 Qdrant 查無對應點）全程無警告，代表嵌入生成與儲存正常。語義相似度搜尋回傳前 K 條、是否始終包含最新摘要，本輪未針對生成回覆時的檢索邏輯做逐條驗證（無專用 API 可直接檢查 RAG 檢索到的內容），僅驗證了摘要「有沒有正確產生與存放」，未驗證「生成時有沒有正確撈回來」，此差異保留供後續參考。

- [ ] 2.4 測試端到端記憶流程
  - 建立長對話（50+ 條訊息）
  - 驗證摘要已生成並儲存
  - 生成角色回覆並確認 RAG 檢索有效
  - 檢查角色在摘要邊界上維持個性
  - 預期時間：2 小時
  - **狀態**：未執行。2026-07-26 測試只需 4 輪（約 9 則訊息）即觸發 2 次摘要（字數閾值遠低於 50 則訊息量），未特別建立 50+ 則訊息的長對話，也未驗證角色個性在摘要邊界上是否維持一致（此為生成品質評測，`測試清單-進階整合測試.md`「不在這份清單範圍內」已明文排除）。

---

## 3. 資料持久化驗證

- [x] 3.1 驗證 Prisma 遷移已就位
  - user-service：User 表遷移
  - character-service：Character 表 + make_introduction_required 遷移
  - chat-service：Conversation 和 Message 表遷移
  - 在每個服務中執行 `npx prisma migrate status` 以確認
  - 預期時間：1 小時
  - **證據**：chat-service 新增 migration `20260725092955_add_persistent_generation_and_creation_job_state`（T18）已於 2026-07-25 執行 `npx prisma migrate dev` 套用並 `prisma generate` 成功（`執行日誌.md` T18）；2026-07-26 K1-K5 進一步透過實際重啟服務、直查 SQLite 驗證新欄位（`generationStatus` 等）與 `ConversationCreationJob` 表確實生效。user-service／character-service 既有遷移本輪未重新執行 `migrate status` 檢查，但貫穿測試的 CRUD 操作間接證明結構正確可用。

- [x] 3.2 驗證 SQLite 資料庫檔案建立正確
  - 確認 dev.db 檔案存在於每個服務的 prisma/ 目錄
  - 檢查檔案許可允許讀/寫
  - 驗證資料庫可用 `sqlite3` CLI 檢查
  - 預期時間：30 分鐘
  - **證據**：2026-07-26 測試全程對 `user-service`／`character-service`／`chat-service` 的 `prisma/dev.db` 做過直接 `sqlite3` CLI 查詢（資料庫驗證 A/B）與收尾清理的 SQL DELETE 操作（含清理前完整備份至 `.cleanup-backup-20260726_005117/`），確認三個 db 檔案存在、可讀寫。

- [ ] 3.3 驗證 Prisma 客戶端正確初始化
  - 檢查 src/lib/prisma.js 匯出單例實例
  - 確認所有服務使用單個 Prisma 連接
  - 驗證 libSQL 適配器設定正確
  - 預期時間：1 小時
  - **狀態**：未獨立驗證，維持未打勾。

- [ ] 3.4 測試資料庫備份和還原流程
  - 記錄備份 SQLite 檔案的程序
  - 建立備份，刪除原始檔案，從備份還原
  - 驗證還原後的資料完整性
  - 預期時間：1 小時
  - **狀態**：2026-07-26 收尾清理時有對三個 `dev.db` 做過備份（`.cleanup-backup-20260726_005117/`）並在刪除資料前確認備份完整，但這是清理作業的副產品，不是本任務要求的「備份→刪除原始檔→從備份還原→驗證完整性」完整演練（沒有實際執行「從備份還原」這一步），不足以打勾。

---

## 4. 錯誤處理 & 程式碼標準化

- [x] 4.1 驗證錯誤碼在所有服務間一致
  - 檢查 EMAIL_ALREADY_EXISTS 始終回傳 409
  - 驗證 CHARACTER_NOT_FOUND 始終回傳 404
  - 測試錯誤回應格式：`{ error: "<CODE>", message: "..." }`（2026-07-26 更正，原文字寫 `{status:"error", message:"..."}` 是 T12 之前的舊格式，已於 T11-T16 全面改為 `{error, message}`）
  - 預期時間：1.5 小時
  - **證據**：`EMAIL_ALREADY_EXISTS` 於 auth-service（T22 修復）與 user-service 皆確認回 409（J1、J2/J3 一併驗證同批 `ERROR_MAP` 行為）；錯誤格式 `{error, message}` 貫穿 J1-J6、I1、H2/H3/H5 全數驗證。`CHARACTER_NOT_FOUND` 404 本輪測試未直接觸發（沒有查詢不存在角色 ID 的案例），但 spec 錯誤碼表已記錄。

- [x] 4.2 驗證錯誤碼已被記錄
  - 確認每個服務的錯誤碼列在其規格中
  - 檢查 CLAUDE.md 檔案參考錯誤處理約定
  - 預期時間：1 小時
  - **證據**：`user-account-management`、`character-management`、`conversation-management`、`api-gateway`、`user-authentication` 五份 spec 皆有「錯誤碼參考」表格且已於 2026-07-25/26 同步至現況。CLAUDE.md 是否參考這些約定本輪未逐一檢查；`chat-service/CLAUDE.md` 已知至少一處過時描述（見 8.1 備註），故不預設其餘 CLAUDE.md 檔案已同步到位。

- [ ] 4.3 測試錯誤情境
  - 測試 user-service 從 auth-service 無法連接時會發生什麼
  - 測試資料庫被鎖定或損壞時會發生什麼
  - 測試 JWT_SECRET 不正確時會發生什麼
  - 驗證錯誤訊息不洩露敏感資訊
  - 預期時間：1.5 小時
  - **狀態**：未執行，維持未打勾。

---

## 5. 環境 & 組態驗證

- [ ] 5.1 驗證 .env 檔案在所有服務間一致
  - 檢查 JWT_SECRET 在 auth-service 和 api-gateway 中相同
  - 驗證服務 URL 正確（auth-service、user-service 等）
  - 確認 FRONTEND_ORIGIN 包含全部 4 個前端連接埠
  - 預期時間：1 小時
  - **狀態**：部分間接證據，不打勾。`JWT_SECRET` 同步：全部 50 項測試都依賴 gateway 能成功驗證 auth-service 簽發的 token，間接證明兩者一致，但未直接比對 `.env` 內容。服務 URL：T6 已把 auth-service 的 `USER_SERVICE_URL` 改成 `GATEWAY_URL`（見 `user-authentication/spec.md` 環境變數段落），其餘服務 URL 未逐一核對。`FRONTEND_ORIGIN` 完全未測試。

- [ ] 5.2 更新 .env.example 檔案
  - 在每個服務中建立/更新 .env.example
  - 確保 .env.example 反映現時 .env 結構
  - 新增說明每個變數的註解
  - 預期時間：1 小時
  - **狀態**：僅 auth-service 一處有記錄：T6 執行時同步更新了 `auth-service/.env`、`.env.example` 的 `USER_SERVICE_URL` → `GATEWAY_URL`（`執行日誌.md` T6）。其餘服務、T18 新增的 chat-service 欄位等是否需要新環境變數、`.env.example` 是否已同步，本輪未檢查，不打勾。

- [ ] 5.3 驗證環境變數載入
  - 測試僅用 .env.example 啟動服務（應優雅失敗）
  - 測試用正確 .env 啟動服務
  - 驗證可選變數的預設值有效
  - 預期時間：1 小時
  - **狀態**：未執行，維持未打勾。

---

## 6. API 契約測試

- [ ] 6.1 測試使用者認證流程
  - 註冊新使用者：POST /auth/register
  - 用正確密碼登入：POST /auth/login → 回傳 JWT
  - 用錯誤密碼登入 → 回傳 400
  - 驗證 JWT 有效且包含正確的使用者 ID
  - 預期時間：1 小時
  - **狀態**：多數已驗證，「錯誤密碼登入」子項未測，維持未打勾。案例 1（3 組帳號註冊+登入皆 201/200，拿到合法 JWT）、J1（重複 email 409）、G3（新 email 201）已驗證註冊/登入正常路徑；JWT 內含正確使用者 ID 由後續所有依賴 `x-user-id` 的所有權檢查（I1、13/15/16 等）間接證明。**「用錯誤密碼登入應回 400」本輪未測試**。

- [x] 6.2 測試使用者帳號操作
  - GET /users/:id，包含有效 JWT
  - GET /users?email=xxx 檢查電子郵件存在
  - DELETE /users/:id，包含擁有權檢查
  - 驗證 x-user-id header 被 user-service 信任
  - 預期時間：1 小時
  - **證據**：`GET /api/users/:id`：G1（200，含 JWT，密碼欄位已濾除）、I1/J2（跨帳號查詢 403）。`DELETE /users/:id`：J3（200，`{success:true,message}` 格式，含擁有權比對）。`x-user-id` 信任：I1/J2/J3 全數依賴此 header 判斷擁有權。`GET /users?email=` 現為內部限定路由，經 G2/G3 間接驗證（T7 修復後的存在性檢查邏輯，spec 已同步記錄 404/403 情境）。

- [ ] 6.3 測試角色操作
  - 建立角色：POST /characters
  - 列出角色：GET /characters?authorId=xxx
  - 檢索角色：GET /characters/:id
  - 更新角色：PUT /characters/:id
  - 刪除角色：DELETE /characters/:id
  - 驗證擁有權檢查有效
  - 預期時間：1.5 小時
  - **狀態**：建立/列出/檢索/擁有權檢查已驗證，更新與刪除未測，維持未打勾。建立：案例 2（6 個角色皆 201）。列出：案例 3-6、L1-L3。檢索單一角色：J5（200，直接物件）。擁有權檢查：13/15/16、H1/H3/H6（含 T21 修復驗證）。**`PUT /characters/:id`、`DELETE /characters/:id` 本輪完全沒有測試案例覆蓋**（無更新或刪除角色的操作）。

- [x] 6.4 測試對話操作
  - 建立對話：POST /conversations
  - 列出對話：GET /conversations
  - 發送訊息：POST /conversations/:id/messages
  - 檢索訊息，包含分頁：GET /conversations/:id/messages
  - 驗證存取控制有效
  - 預期時間：1.5 小時
  - **證據**：建立對話：案例 7-16（經 `GET /conversations/character/:id` 觸發 202 preparing → 200 ready）。列出：K4（`GET /conversations` 過濾驗證）。發送訊息：案例 17（`POST .../messages` 201 accepted）。檢索訊息：案例 23、H4/H5。存取控制：13/15/16、H4/H5、J2。分頁參數（`limit`/`offset`）本輪未專門測試，但端點本身的基本讀寫與存取控制已充分覆蓋。

- [ ] 6.5 測試 gateway 路由和 CORS
  - 驗證位於 5173 的前端可連接位於 8000 的 gateway
  - 測試 OPTIONS 請求的 CORS preflight
  - 測試來自非白名單來源的請求失敗
  - 驗證 Authorization header 被正確處理
  - 預期時間：1 小時
  - **狀態**：Authorization header 處理已充分驗證（H2/H3/H5、I2 涵蓋缺失、格式錯誤、無效簽名等情境），但**CORS 相關子項（preflight、白名單）完全未測試**，且本輪測試全程用指令模擬請求、未啟動任何前端 dev server，無法驗證「前端實際連得上 gateway」，故整體維持未打勾。

---

## 7. 前端整合測試

> 2026-07-26 說明：本節四項全部需要實際啟動前端 dev server 並在瀏覽器中操作，但 2026-07-26 的整合測試（`進階整合測試task0726.md`）明確採用「全部用指令模擬前端會發的請求，不開瀏覽器」的方式執行（環境準備段落明寫「不需要啟動 4 個前端 Vite dev server」）。因此本節 7.1-7.4 沒有任何一項有本輪測試證據，維持全部未打勾，不逐項展開。

- [ ] 7.1 測試 persona-nexus-auth（登入/註冊前端）
- [ ] 7.2 測試 persona-nexus-character（建立者前端）
- [ ] 7.3 測試 persona-nexus-lobby（首頁/畫廊前端）
- [ ] 7.4 測試 persona-nexus-chat（對話前端）

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
  - **狀態**：未執行，且已有具體反例：2026-07-26 K5 測試過程中發現 `chat-service/CLAUDE.md` 對 `aiGenerationStatus` 的描述（「進程內記憶體 Map、重啟即遺失」）已過時，與 T18 之後的實際行為（Prisma 持久化欄位，重啟不遺失，見 K1-K5 全數 PASS）不符，見 `進階整合測試task0726.md` K5 備註。這是本項尚未執行的直接證據。

- [ ] 8.2 建立快速開始指南
  - **狀態**：未執行。

- [ ] 8.3 記錄已知限制和技術債
  - ~~persona-nexus-auth 不在 localStorage 中儲存 JWT~~ — **2026-07-26 查證：已修復**，登入後導向 lobby 並帶 `?token=`，lobby 端 `localStorage.setItem('token', ...)`，詳見 `openspec/config.yaml` 已知缺口段落
  - ~~persona-nexus-character 繞過 gateway（應使用 8000）~~ — **2026-07-26 查證：已修復**，`api.js` 已改用相對路徑 `/api`（同源部署），詳見同上
  - auth 端點上無速率限制 — 狀態未變，仍是已知限制（見 `user-authentication/spec.md` 已知限制）
  - 無使用者刪除級聯邏輯 — 本輪未測試，狀態未重新查證
  - 無刷新令牌端點 — 狀態未變
  - 預期時間：1 小時
  - **狀態**：清單內容已於 2026-07-26 核對並更正兩項過時描述（如上），但本任務本身（把這份清單正式寫入文件並交付）未完整執行，維持未打勾。

- [ ] 8.4 建立故障排除指南
  - **狀態**：未執行。

---

## 9. 測試 & 品質保證

- [ ] 9.1 執行現有單元測試
  - auth-service：`npm test`（16 個測試案例）
  - character-service：`npm test`（service 層測試）
  - 驗證所有都通過
  - 預期時間：1 小時
  - **狀態**：未執行。2026-07-26 測試全程是啟動真實服務走 HTTP 整合測試，未執行任一服務的單元測試指令。

- [ ] 9.2 手動煙霧測試
  - 完整註冊 → 登入 → 建立角色 → 開始對話流程
  - 測試錯誤情境（無效電子郵件、重複電子郵件、錯誤密碼）
  - 測試授權（使用者無法存取其他使用者的資料）
  - 預期時間：2 小時
  - **狀態**：第一、三子項已驗證，第二子項只驗證了「重複電子郵件」，維持未打勾。完整流程：案例 1、2、7-16（註冊→登入→建立角色→開始對話全程走通，含 202→200 輪詢）。授權：13/15/16、H3、I1、J2。錯誤情境僅驗證「重複電子郵件」（J1/G3），**未驗證「無效電子郵件格式」與「錯誤密碼」兩種情境**。

- [ ] 9.3 負載測試（可選）
  - **狀態**：未執行（本任務本身標註可選）。

- [ ] 9.4 安全審查
  - 檢查 SQL 注入漏洞（Prisma 應防止）
  - 檢查前端中的 XSS 漏洞
  - 驗證 CORS 不允許意外來源
  - 驗證 JWT 祕鑰不被記錄任何地方
  - 預期時間：2 小時
  - **狀態**：未系統性執行，維持未打勾。本輪測試（含 H6 直打裸 port）驗證的是「架構層授權繞過」而非傳統 SQL 注入／XSS／CORS 安全審查；`mistakes.md` 的 2026-07-25 四方稽核聚焦在架構準則合規性，同樣未涵蓋此處列出的傳統安全檢查項。

---

## 10. 最終驗證 & 交接

- [x] 10.1 驗證所有 OpenSpec 構件已完成
  - proposal.md ✓
  - specs/*.md（7 個檔案）✓
  - design.md ✓
  - tasks.md ✓（本檔案，2026-07-26 已同步現況）

- [ ] 10.2 建立摘要檢查清單
  - 所有服務執行無錯誤
  - 所有規格已針對實現驗證
  - 所有已知限制已記錄
  - 所有環境變數已設定
  - 前端到後端整合正常運作
  - 預期時間：1 小時
  - **狀態**：後端服務層面大致可視為完成（第 1-6 節多數已驗證），但「前端到後端整合正常運作」這條本輪完全沒有瀏覽器層級的驗證（見第 7 節），不足以整體打勾。

- [ ] 10.3 為下一階段準備（剩餘 20% 功能）
  - **狀態**：未執行。

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
