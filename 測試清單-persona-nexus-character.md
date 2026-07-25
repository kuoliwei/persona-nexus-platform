# persona-nexus-character 前端 API 測試清單

> 目的：驗證角色創建/編輯頁實際會發出的每一種前端→後端請求都正常運作。指令模擬 `src/api.js` 的 `fetch()` 呼叫，同樣的 URL、method、payload。允許建立測試角色，測完不用刪除。

## 依據（讀原始碼確認）

- `src/api.js:1`（**這次搬機器改過**）：`BASE_URL = '/api'`，相對路徑，經 Caddy 同源代理打到 `api-gateway`，gateway 再轉發到 `character-service`（內部路由前綴 `/api/v1/characters`）。
- `src/api.js:3-7`：所有請求都帶 `Authorization: Bearer <localStorage 裡的 token>`。
- `src/create.js:38-42`、`src/edit.js:38-46`：進頁面先呼叫 `getCurrentUserId()`（解碼 localStorage 的 JWT），沒登入就導去登入頁；`edit.js` 額外要求 URL 帶 `?id=`。
- `src/form.js:9-19`：表單收集出的 payload 形狀：
  ```json
  { "name": "...", "gender": "...或 null", "tags": ["..."], "visibility": "private 或 public", "introduction": "...", "background": "...", "opening": "...", "fewShots": [{ "user": "...", "char": "..." }] }
  ```
- **⚠️ 這裡的 CLAUDE.md 已過時，兩處都跟現在的程式碼對不上**：
  1. 文件說「本前端直打 character-service:5000，不經過 gateway，`Authorization` header 被忽略」——這是搬機器前的舊架構。現在 `BASE_URL='/api'` 會經過 gateway，`Authorization` header 會被 gateway 的 `authMiddleware` 真的拿去驗證 JWT，驗證失敗直接被 gateway 擋下（401），根本進不了 character-service。
  2. 文件說「persona-nexus-web 沒有把 token 存進 localStorage，登入會卡住」——這個之前已經確認 `persona-nexus-auth/src/main.js` 現在其實有透過 URL 參數把 token 轉交給 lobby 存進 localStorage，這裡的 `create.js`/`edit.js` 也是靠 `?token=` query string 接手存 token（`create.js:30-36`），流程是通的。
- 後端實際回應（讀 `character-service/src/controllers/characterController.js` + `src/services/characterService.js`）：
  - 必填欄位：`name`、`introduction`、`background`、`opening`；缺任一 → `400`「缺少必填欄位」
  - `visibility` 只能是 `"private"` / `"public"`，其他值 → `400`「可見性設定錯誤」
  - 建立成功 → `201`「創建成功！」
  - 查詢單一：不存在 → `404`「角色不存在」；`private` 且非本人 → `403`「無權限」
  - 更新：不存在 → `404`；非本人 → `403`「無權限」（**檢查順序在必填欄位驗證之前**，所以改別人角色不會先看到欄位錯誤，會先看到 403）
  - 刪除：不存在 → `404`；非本人 → `403`
  - `x-user-id` 由 gateway 從 JWT 注入，character-service 自己完全信任、不重複驗證

## 執行方式注意事項（實測踩過的坑，2026-07-25）

跟 [測試清單-persona-nexus-auth.md](測試清單-persona-nexus-auth.md) 的「執行方式注意事項」一樣三個坑（`Get-Content` 讀出來的字串塞進 JSON body 前要 `[string]` 轉型、錯誤 body 要讀 `$_.ErrorDetails.Message`、中文欄位要轉 UTF-8 bytes 再送），這份清單的角色名稱／背景／開場白都是中文，UTF-8 編碼這條特別容易忘記，忘記的話中文會變 `?`。範例 helper 函式見 auth 清單，這裡不重複貼。

**案例 14 執行順序提醒**：案例 1、2 是刻意保留給你之後手動在頁面上查看的（不要刪掉），所以案例 14「刪除本人角色」需要**先另外建一個專門拿來刪的拋棄角色**，不要沿用案例 1/2。原始版本的清單漏寫這個前置步驟，這裡已經補上明確案例編號（0.5）。

## 測試案例（需要先有一組有效 JWT，用測試清單-persona-nexus-auth.md 案例 7 登入取得）

| # | 情境 | 請求 | 預期結果 |
|---|---|---|---|
| 1 | 建立角色（全欄位） | `POST /api/characters`（帶 Bearer token）body 含 `name`/`gender`/`tags`/`visibility:"public"`/`introduction`/`background`/`opening`/`fewShots` 全部給值 | `201`，`data.id` 格式為 `char_<timestamp>`，回傳欄位跟送出的一致 |
| 2 | 建立角色（只填必填欄位） | `POST /api/characters` body 只給 `name`/`introduction`/`background`/`opening` | `201`，`data.gender` 為 `null`、`data.tags`/`data.fewShots` 為 `[]`、`data.visibility` 為 `"private"`（驗證預設值邏輯） |
| 3 | 建立角色缺必填欄位 | `POST /api/characters` body 缺 `opening` | `400`，message「缺少必填欄位」 |
| 4 | 建立角色 visibility 非法值 | `POST /api/characters` body 其餘正常，`visibility: "public-ish"` | `400`，message「可見性設定錯誤」 |
| 5 | 建立角色沒帶 token | `POST /api/characters` 不帶 `Authorization` header | `401`（在 gateway 這層就被擋，回應應為 gateway 的未授權訊息，不會到 character-service） |
| 6 | 查詢單一角色（本人的 private） | `GET /api/characters/<案例2建立的id>`，帶案例 1/2 建角色時登入的同一個 token | `200`，message「取得成功！」，資料完整 |
| 7 | 查詢單一角色（別人的 private） | 用另一組帳號的 token 查案例 2 的角色 id（案例 2 是 private） | `403`，message「無權限」 |
| 8 | 查詢單一角色（別人的 public） | 用另一組帳號的 token 查案例 1 的角色 id（案例 1 是 public） | `200`，正常取得（public 沒有作者限制） |
| 9 | 查詢不存在的角色 | `GET /api/characters/char_0000000000000` | `404`，message「角色不存在」 |
| 10 | 更新角色（本人） | `PUT /api/characters/<案例2的id>`，同一個 token，改 `name` | `200`，message「修改成功！」，`data.name` 是新值 |
| 11 | 更新角色（別人的） | 用另一組帳號的 token 更新案例 2 的角色 | `403`，message「無權限」 |
| 12 | 更新不存在的角色 | `PUT /api/characters/char_0000000000000` | `404`，message「角色不存在」 |
| 13 | 刪除角色（別人的） | 用另一組帳號的 token 刪案例 1 的角色 | `403`，message「無權限」（**先測這個，確保案例 1 角色留著給後面的案例用**） |
| 14.0 | 建立拋棄用測試角色 | `POST /api/characters` body 隨便填必填欄位即可（例如 `name:"拋棄角色"`） | `201`，記下這個 `id`，只給案例 14 用 |
| 14 | 刪除角色（本人） | 用建立時的 token 刪案例 14.0 建立的拋棄角色（**不要刪案例 1/2**，那兩個要保留給你之後手動在頁面上看） | `200`，message「刪除成功！」 |

## 資料庫驗證

`character-service/prisma/dev.db`，表名 `Character`（欄位：`id`／`authorId`／`name`／`gender`／`tags`／`introduction`／`background`／`opening`／`fewShots`／`visibility`／`createdAt`／`updatedAt`；`tags`／`fewShots` 存成 JSON 字串，不是關聯表）。

| # | 驗證時機 | 查詢 | 預期結果 |
|---|---|---|---|
| A | 案例 1、2 之後 | `sqlite3 character-service/prisma/dev.db "SELECT id, authorId, visibility, tags, fewShots FROM Character WHERE id IN ('<案例1id>','<案例2id>')"` | 2 筆都在；`tags`/`fewShots` 是合法 JSON 字串（如 `[]` 或 `[{"user":"...","char":"..."}]`），不是 `undefined`/`null` |
| B | 案例 10（更新）之後 | 查同一個 `id` | `name` 已經是更新後的新值，`updatedAt` 比 `createdAt` 晚 |
| C | 案例 14（刪除）之後 | 查被刪那個 `id` | 查無資料（真的從 DB 移除，不是軟刪除——`characterRepository.deleteById` 沒有看到 soft-delete 欄位） |

## 不在這份清單範圍內（原因）

- **表單本身的必填/select 限制**：`visibility` 在 UI 上是 `<select>`，瀏覽器操作不可能送出非法值，案例 4 是測「假設繞過表單」後端會不會照樣擋下來，屬於防禦縱深驗證，不是模擬真實使用者操作。
- **Few Shots 動態新增/刪除的 UI 互動**（`fewShots.js` 的 `<template>` clone 邏輯）：純前端 DOM 操作，不牽涉後端請求，指令測試測不到也不需要測。
- **建立/更新成功後 1.5 秒導回大廳的 `window.parent.location.href` 行為**：瀏覽器導頁行為，且用到 `window.parent`（代表這個頁面預期被包在 lobby 的 iframe 裡），指令測試模擬不到。

---

## 實測結果（2026-07-25）

**14/14 案例 + 3/3 資料庫驗證全數通過。** 中文欄位（名稱/背景/開場白/標籤）UTF-8 編碼正確送達且正確存回，資料庫確認硬刪除（不是軟刪除）。
