# 待辦 Task：修正現況與《微服務架構準則》《微服務架構實作 Spec》的落差

> 根據 `mistakes.md` 的 15 條落差整理成可執行任務，按依賴順序分批。每個任務標明對應的 mistake 編號，方便回頭查落差細節。

---

## 批次 1：Gateway 路徑與 header 基礎設施（其他批次的前提）

這批不做，後面所有跟 `/internal/*`、`x-internal-request` 相關的任務都無法驗證。

- [x] **T1. 修 `userProxy.js` 補上 pathRewrite**
  - **對應**：M3
  - **內容**：`api-gateway/src/proxies/userProxy.js` 補上函式式 pathRewrite，補回 `/users` 前綴
  - **驗收**：`GET /api/users/:id`、`DELETE /api/users/:id` 能正確轉發到 user-service 的 `/users/:id`

- [x] **T2. `internalAuthMiddleware` 注入 `x-internal-request: true`**
  - **對應**：M6
  - **內容**：IP 驗證通過後，加一行注入 header
  - **驗收**：任一 `/internal/*` 路由的請求，下游服務能在 header 裡讀到 `x-internal-request: true`

- [x] **T3. 新增 `POST /internal/users` 路由（Gateway 端）**
  - **對應**：M4（Gateway 部分）
  - **依賴**：T1（`userProxy` 要先修好，否則新路由一樣會轉發錯路徑）
  - **內容**：在 `app.js` 明確掛載 `POST /internal/users`，沿用修好後的 `userProxy`
  - **驗收**：`POST /internal/users` 能正確轉發到 user-service 的 `POST /users`

---

## 批次 2：user-service 收尾（建帳號流程 + 授權重構）

- [x] **T4. user-service 新增 `POST /users` 的 `x-internal-request` 檢查**
  - **對應**：M2
  - **依賴**：T2
  - **內容**：service 層檢查 `x-internal-request === 'true'` 才放行建帳號
  - **驗收**：直接打 `POST /users`（不帶 header）應被拒絕；帶正確 header 才能建帳號

- [x] **T5. 移除 `authorizeSelf.js`，授權邏輯搬到 service 層**
  - **對應**：M9
  - **依賴**：T2（要先有 header 可讀）
  - **內容**：
    - 刪除 `user-service/src/middlewares/authorizeSelf.js`
    - `userController.js` 的 `getUserById`／`deleteUser` 改成讀 `x-user-id`、`x-internal-request`，傳給 service 層
    - `userService.js` 對應方法補上判斷順序：`x-internal-request === 'true'` 放行，否則比對 `x-user-id === :id`
  - **驗收**：GET/DELETE `/users/:id` 行為不變（自己可查/刪，別人不行），且內部呼叫（帶正確 header）可放行

- [x] **T6. auth-service 改連 Gateway `/internal/users`，不再直連 user-service**
  - **對應**：M5
  - **依賴**：T3、T4
  - **內容**：`auth-service/src/repositories/userRepository.js` 的 `save()`、`findByEmail()` 改打 Gateway 而非 `user-service:4000`
  - **驗收**：註冊流程整條走 Gateway，直連 user-service 的寫死網址被移除

- [x] **T7. 修掉或收斂 `GET /users?email=` 這個暗門路由**
  - **對應**：M1
  - **依賴**：T6（先確認 auth-service 走 `/internal/users` 之後，是否還需要這條路由查 email）
  - **內容**：這條路由目前是登入比對密碼用的。需先決定：
    - 方案 A：併入 `/internal/users` 系列，掛在 `/internal/*` 下並檢查 `x-internal-request`
    - 方案 B：保留現路徑，但補上 `x-internal-request` 檢查
    - 不論哪種，都必須移除「無條件回傳密碼雜湊」且「無授權檢查」的現況
  - **驗收**：非內部呼叫無法查到任何使用者的密碼欄位

---

## 批次 3：character-service、chat-service 補齊 `/internal/*` 與授權邏輯

這批兩個服務可以並行處理，彼此不互相依賴，但都依賴 T2。

- [x] **T8. character-service 新增 `/internal/characters/:id` 路由與 `x-internal-request` 放行邏輯**
  - **對應**：M7（character-service 部分）、M8（character-service 部分）
  - **依賴**：T2
  - **內容**：
    - `app.js` 新增 `/internal/characters/:id` 路由（或確認現有路由 + Gateway pathRewrite 後行為正確）
    - `characterService.js` 的 `getCharacter`／`updateCharacter`／`deleteCharacter` 補上判斷順序：`x-internal-request === 'true'` 放行，否則走原本的所有權比對
  - **驗收**：ai-service 透過內部路由查詢私有角色詳情不會被誤擋 `FORBIDDEN`

- [x] **T9. chat-service 新增 `/internal/conversations` 系列路由與 `x-internal-request` 放行邏輯**
  - **對應**：M7（chat-service 部分）、M8（chat-service 部分）
  - **依賴**：T2
  - **內容**：
    - `app.js` 新增 `/internal/conversations`、`/internal/conversations/:id/messages` 路由，不掛 `authMiddleware`
    - `assertConversationOwnership` 函式簽章加入 `internalRequest` 參數，判斷順序：`x-internal-request === 'true'` 放行，否則原本的所有權比對
    - 所有呼叫 `assertConversationOwnership` 的地方（`sendMessageToConversation`、`getMessagesByConversationId`、`deleteConversation` 等）改傳入這個參數
  - **驗收**：ai-service 透過內部路由查詢對話歷史、發送訊息不會被 401/403 擋下

- [x] **T10. 移除 chat-service 的 `authMiddleware.js`，判斷邏輯併入 service 層**
  - **對應**：M10
  - **依賴**：T9（`assertConversationOwnership` 要先能處理 `x-internal-request`，否則拆掉 middleware 後外部請求的 401 判斷會漏掉）
  - **內容**：
    - 刪除 `chat-service/src/middlewares/authMiddleware.js`，`app.js` 移除掛載
    - controller 改讀 header 傳給 service，`validateUserId` 保留為 service 層唯一的存在性判斷
  - **驗收**：缺 `x-user-id` 的外部請求仍然被拒絕（行為不變），只是判斷邏輯只剩一層

---

## 批次 4：回應格式統一（M11、M12）

這批影響面最廣（5 個服務都要改），且**會動到前端**，建議動工前先跟前端對齊。

- [x] **T11. 決定並記錄最終回應格式規格**
  - **對應**：M11、M12
  - **內容**：目前 spec 定義的格式（錯誤 `{error, message}`、成功直接返回物件/陣列）與多數服務現況（`{status, message, data}`）不同，屬於先前討論裡「問題 6」尚未決定的部分。動工前需要先拍板：
    - 是否維持 spec 原定格式，把 5 個服務都改過去
    - 還是反過來讓 spec 遷就現有的 `{status, message, data}` 慣例
  - **這個任務本身不是修程式碼，是先做決策**，決策拍板後才能拆成 T12-T16

- [x] **T12. auth-service 回應格式對齊**
  - **對應**：M11、M12（auth-service 部分）
  - **依賴**：T11

- [x] **T13. user-service 回應格式對齊**
  - **對應**：M11、M12（user-service 部分）
  - **依賴**：T11

- [x] **T14. character-service 回應格式對齊**
  - **對應**：M11、M12（character-service 部分）
  - **依賴**：T11

- [x] **T15. chat-service 回應格式對齊**
  - **對應**：M11、M12（chat-service 部分）
  - **依賴**：T11

- [x] **T16. ai-service 回應格式對齊**
  - **對應**：M11、M12（ai-service 部分）
  - **依賴**：T11
  - **內容**：需額外註冊 FastAPI 的 `@app.exception_handler`，統一攔截 `HTTPException` 轉成 `{error, message}` 格式

---

## 批次 5：非同步狀態持久化（M13、M14）

- [x] **T17. 決定持久化技術選型**
  - **對應**：M13、M14
  - **內容**：DB 欄位 vs Redis，兩個服務必須用同一種。這是架構決策，決定前不要動工。
  - **注意**：`aiGenerationStatus` 目前兼職當「拒絕並行生成」的鎖，選型時要一併考慮鎖的實作方式（DB 用悲觀鎖/唯一索引，Redis 用 `SETNX` 之類），不是單純把 Map 換成儲存介質而已

- [x] **T18. chat-service 的 `creationJobs`、`aiGenerationStatus` 改為持久化**
  - **對應**：M13
  - **依賴**：T17

- [ ] **T19. ai-service 的 `initialization_jobs` 改為持久化** — ⚠️ 擱置：ai-service 目前無關聯式資料庫，需先決定是否引入（新增 SQLite）或改用其他儲存方式，詳見執行日誌
  - **對應**：M14
  - **依賴**：T17

---

## 批次 6：待確認事項（不確定是否算落差）

- [x] **T20. 確認 `GET /api/characters` 的查詢方式是否為預期設計**
  - **對應**：M15
  - **內容**：目前是分兩次查詢（`?authorId=` 和 `?visibility=public`）拼出結果，需要確認 spec 原意是否就是如此，若是則只需修正 spec 文字敘述；若否則需改成單一查詢同時涵蓋兩者
  - **這個任務不依賴其他任務，可隨時處理**

---

## 建議執行順序摘要

```
T1 → T2 → T3
         ├─→ T4 → T6 → T7
         │        └─→ T5
         ├─→ T8
         └─→ T9 → T10

T11 → T12/T13/T14/T15/T16（可並行）

T17 → T18/T19（可並行）

T20（獨立，隨時可做）
```

---

## 更新紀錄

- **2026-07-25**：初稿，根據 mistakes.md 的 15 條落差整理成任務，標注依賴順序
- **2026-07-25**：改為 checklist 形式，方便逐項勾選追蹤進度
