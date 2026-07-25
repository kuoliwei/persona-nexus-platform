# Mistakes：現況與《微服務架構準則》《微服務架構實作 Spec》的落差

> 本文件由 4 個獨立稽核（Gateway、auth/user-service、character/chat-service、ai-service）逐一讀取原始碼、對照 spec 條款產生。每筆均附檔案路徑與行號，可回頭核實。依嚴重度分組，同組內大致依影響面排序。

---

## 分級說明

- **高**：功能會壞掉（呼叫失敗、資料外洩、授權被繞過）或安全性缺口
- **中**：功能可運作但格式不一致，會造成前端/跨服務整合困難
- **低**：文字表述與實作有落差，需要確認是否為預期設計

---

## 高：安全性缺口

### M1. `GET /users?email=` 無授權檢查，直接回傳密碼雜湊值
- **檔案**：`user-service/src/app.js:18`、`user-service/src/controllers/userController.js:60-87`
- **問題**：此路由完全不在 spec 的路由表定義中，屬於架構外的「暗門」路由。`getUserByEmail` 明確註解「刻意不使用 toPublicUser()」，直接回傳含 bcrypt 密碼雜湊的完整使用者物件，且沒有掛任何授權檢查（無 `authorizeSelf`、無 `x-internal-request` 判斷）。任何能連到 `user-service:4000` 的呼叫者都能用 email 查出密碼雜湊。
- **違反條款**：《微服務架構準則》第 7 項「資源所有權檢查」、第 1 項「所有服務間通訊都須通過 Gateway」

### M2. `POST /users` 無 `x-internal-request` 檢查，任何人可建帳號
- **檔案**：`user-service/src/controllers/userController.js:32-58`、`user-service/src/services/userService.js:4-12`
- **問題**：spec 授權決策表要求此路由「檢查 `x-internal-request: true`」才放行，程式碼完全沒有此判斷，且路由未掛在 `/internal/*` 之下、未經 Gateway 的 IP 驗證，形同完全無授權保護的公開建帳號端點。
- **違反條款**：spec 第二部分授權決策表（user-service）

---

## 高：功能會壞掉（路徑/路由層）

### M3. `userProxy.js` 完全沒有 pathRewrite，`/api/users/:id` 與 `/internal/users/:id` 兩條路由轉發路徑錯誤
- **檔案**：`api-gateway/src/proxies/userProxy.js:16-25`，影響 `app.js:68`（`/api/users`）、`app.js:94`（`/internal/users`）
- **問題**：Express 前綴掛載會 strip 掉掛載路徑前綴，`userProxy` 沒有補回 `/users`，導致轉發給 user-service 的路徑錯誤（例如 `/api/users/123` 轉發後變成 `/123`，user-service 沒有這個路由 → 404）。這是最初發現的既有 bug，尚未修復。
- **違反條款**：spec 第一部分「受保護的外部路由」統一原則、外部/內部路由表

### M4. `POST /internal/users` 路由缺失
- **檔案**：`api-gateway/src/app.js`（無此路由定義）、`user-service/src/app.js`（無 `/internal/*` 任何路由）
- **問題**：spec 明確定義的新路由，Gateway 端完全沒有獨立實作（只有籠統不分 method 的 `app.use('/internal/users', ...)`），user-service 端更是完全沒有 `/internal/*` 前綴的路由。與 M5（auth-service 直連）互為因果——因為沒人真正呼叫這條路由，所以兩端都沒做。
- **違反條款**：spec 第一部分內部路由表、第二部分授權決策表（auth-service、user-service）

### M5. auth-service 建帳號直連 user-service，未經 Gateway
- **檔案**：`auth-service/src/repositories/userRepository.js:1-4, 23-47`
- **問題**：`save()`、`findByEmail()` 直接對 `http://localhost:4000/users...` 發 fetch，完全繞過 Gateway，也未呼叫 spec 定義的 `/internal/users`。
- **違反條款**：《微服務架構準則》第 1 項「所有服務間通訊都須通過 API Gateway」；spec 授權決策表（auth-service）

### M6. `internalAuthMiddleware` 完全沒有注入 `x-internal-request` header
- **檔案**：`api-gateway/src/middlewares/internalAuthMiddleware.js`（全檔案）
- **問題**：只做 IP 白名單檢查，驗證通過後直接 `next()`，沒有任何一行設定 `req.headers['x-internal-request']`。所有經過此 middleware 的 6 條 `/internal/*` 掛載路由，下游服務永遠拿不到這個標記。
- **違反條款**：spec 第二部分 Header 契約表

### M7. `x-internal-request` 判斷邏輯在 user-service、character-service、chat-service 三個服務完全沒寫
- **檔案**：
  - `user-service`：授權邏輯集中在獨立 middleware `authorizeSelf.js`（見 M9），沒有搬到 service 層，也沒有依 spec 判斷順序處理
  - `character-service/src/services/characterService.js:69-89`（`updateCharacter`）、`122-128`（`deleteCharacter`）、`90-97`（`getCharacter`）：全文 grep `x-internal-request` 零匹配
  - `chat-service/src/services/conversationService.js:28-46`（`assertConversationOwnership`）：函式簽章只接受 `(userId, conversationId)`，全文 grep 零匹配
- **問題**：這不是「Gateway 沒注入、下游邏輯觸發不到」的問題，而是三個服務的程式碼裡**根本沒有寫這段判斷邏輯**，比 M6 更嚴重一層——即使先修好 M6，這三個服務的內部呼叫依然會被當成一般外部請求處理（缺 `x-user-id` → 401，或所有權比對失敗 → 403）。
- **違反條款**：spec 第二部分「授權檢查統一模式」判斷順序、授權決策表全部 `x-internal-request 例外放行` 條目

### M8. `/internal/characters/:id`、`/internal/conversations`、`/internal/conversations/:id/messages` 路由完全不存在
- **檔案**：`character-service/src/app.js`（僅 `/api/v1/characters*`）、`chat-service/src/app.js`（僅 `/api/v1/conversations*`，且全部掛 `authMiddleware`）
- **問題**：spec 定義的三條內部路由，兩服務都沒有對應的 `/internal/*` 路由。更嚴重的是 chat-service 若依 spec 把 Gateway 端的 `/internal/conversations` pathRewrite 到 `/api/v1/conversations`，會命中同一個掛了 `authMiddleware` 的路由——而 `/internal/*` 依 spec 不會帶 `x-user-id`，該 middleware 會直接回 401，內部呼叫必定失敗。
- **違反條款**：spec 第一部分內部路由表、第二部分授權決策表

---

## 高：授權邏輯架構性違規（獨立 middleware）

### M9. user-service 存在獨立授權 middleware `authorizeSelf.js`
- **檔案**：`user-service/src/middlewares/authorizeSelf.js:1-29`，掛載於 `app.js:19-20`
- **問題**：spec 明文規定「不設獨立的授權 middleware」，controller 應只負責讀 header、service 層統一判斷。但 `getUserById`／`deleteUser` 的 controller（`userController.js:90-104, 107-121`）完全沒讀 header 也沒傳給 service，`userService.js` 對應方法（24-42 行）也完全沒有授權判斷——授權邏輯 100% 集中在這支獨立 middleware，是結構性違規，不是部分符合。
- **違反條款**：spec 第二部分「授權檢查統一模式」第 1 條

### M10. chat-service 存在獨立授權 middleware `authMiddleware.js`
- **檔案**：`chat-service/src/middlewares/authMiddleware.js:1-7`，掛載於 `app.js`（16 條路由全掛）
- **問題**：只做「`x-user-id` 是否存在」的檢查，但這個判斷依 spec 應屬於 service 層職責。且 `conversationService.js` 的 `validateUserId`（13-17 行）做了重複判斷，形成兩層都做授權檢查、回應格式還不一致（middleware 回 `{message}`，service 層錯誤經 `ERROR_MAP` 轉換後格式不同）的狀況。
- **違反條款**：spec 第二部分「授權檢查統一模式」第 1 條

---

## 中：回應格式不符 spec（`{error, message}` / 直接返回物件）

一次列出四個服務的回應格式落差，因為屬於同一類問題、修法一致：

### M11. 錯誤回應格式不符 `{error, message}`
- **auth-service**：`authController.js:15` 用 `{status: 'error', message}`，鍵名錯誤且缺錯誤碼
- **user-service**：`userController.js:28`、`authorizeSelf.js:23-25` 用 `{message}`，完全缺 `error` 欄位
- **character-service**：`characterController.js:13-20` 用 `{status: 'error', message}`，同 auth-service 問題
- **chat-service**：`conversationController.js`（約 20 處）只回 `{message}`，缺 `error` 欄位
- **ai-service**：完全沒有自訂 exception handler，FastAPI 預設輸出 `{"detail": "..."}`，鍵名、結構都不符
- **違反條款**：spec 第三部分「錯誤回應格式」

### M12. 成功回應格式包裹 `{status, message, data}`，不符「直接返回物件」
- **auth-service**：`authController.js:42-46, 74-78` 包裹 `{status, message, data}`，且缺 `createdAt`
- **character-service**：5 個方法（`characterController.js`）全部包裹 `{status, message, data}`
- **user-service**：`DELETE /users/:id` 回 204 無 body，不符 spec 要求的 `{success:true, message}`
- **chat-service**：6 處操作成功回應用 `{status:'success', message}`，鍵名（`status` vs `success`）與型別（字串 vs 布林）都不符；但其餘端點（`getAllConversations`、`getMessages` 等）符合「直接返回物件/陣列」
- **ai-service**：全面用 `{status: "success"/"accepted", ...}` 包裹，`generate_response` 等應直接返回結果卻多包一層
- **違反條款**：spec 第三部分「成功回應格式」

---

## 中：非同步狀態存在進程內記憶體

### M13. chat-service `creationJobs`、`aiGenerationStatus` 為進程內 Map
- **檔案**：`chat-service/src/services/conversationService.js:239`（`creationJobs`）、`:7`（`aiGenerationStatus`）
- **問題**：服務重啟即遺失、多實例不共享。其中 `aiGenerationStatus` 同時充當「拒絕並行生成」的鎖（581-598 行判斷 `status === 'generating'`）——多實例部署下這個鎖會直接失效，導致同一對話在不同實例被同時處理，比單純狀態遺失更嚴重。
- **違反條款**：spec 第四部分「非同步狀態管理」

### M14. ai-service `initialization_jobs` 為進程內 Python dict
- **檔案**：`ai-service/src/services/rag_service.py:17`（宣告）、`66,141,169,184,220-221`（讀寫）、`422`（全域單例）
- **問題**：與 M13 同性質問題，是團隊已知但尚未修的技術債（ai-service 自身 CLAUDE.md 已記錄），但仍是現況與 spec 的真實落差。
- **違反條款**：spec 第四部分「非同步狀態管理」

---

## 低：表述與實作落差（需確認是否為預期設計）

### M15. `GET /api/characters` 沒有「單一查詢同時涵蓋自己的角色+他人 public 角色」的路徑
- **檔案**：`character-service/src/services/characterService.js:98-121`（`listCharacters`）
- **問題**：spec 文字寫「返回『登入者自己的角色』+『標記為 public 的其他角色』」，但實作是依 query 參數分成兩個互斥情境（`visibility=public` 拿全部公開角色；`authorId=xxx` 拿某作者角色），前端要打兩次 API 才能拼出 spec 描述的結果。不確定 spec 原意是否就是「分兩次呼叫」，需要確認。
- **違反條款**：spec 第二部分授權決策表（character-service）表述方式

---

## 附註：確認無落差的項目

以下項目經逐條核對，**符合 spec**，列出以確認稽核覆蓋率：

- Gateway：`authProxy`（精確掛載 + regex pathRewrite）、`characterProxy`／`chatProxy`／`aiProxy`（前綴掛載 + 函式式 pathRewrite）、`x-user-id`／`x-user-email` 注入邏輯
- character-service：未使用獨立授權 middleware（授權邏輯已在 service 層）；無非同步任務，不適用第四部分
- ai-service：三條內部路由授權邏輯（皆不檢查所有權）符合；未設獨立授權 middleware
- user-service 本身的 `/users/:id` 命名與 Gateway 轉發目標一致（純路徑核對，不含授權部分）

---

## 更新紀錄

- **2026-07-25**：初稿，彙整 4 個並行稽核（Gateway、auth/user-service、character/chat-service、ai-service）的逐條核查結果
