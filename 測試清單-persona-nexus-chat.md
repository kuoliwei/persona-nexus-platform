# persona-nexus-chat 前端 API 測試清單

> 目的：驗證聊天室頁面實際會發出的每一種前端→後端請求都正常運作，包含真正觸發 LLM 生成的流程。指令模擬 `src/chat.js` 裡的 `fetch()` 呼叫。允許建立測試對話/訊息，測完不用刪除（除了案例本身就是在測「刪除」功能的部分）。

## 前置需求

- 這份清單會**真的觸發 ai-service 呼叫 Ollama 生成回覆**，測試前確認 Docker（Qdrant/Caddy）、Ollama、ai-service 都在跑，且模型已預載（`ollama ps` 看得到常駐）。
- 需要一個已存在、你有權限的角色 id（用 [測試清單-persona-nexus-character.md](測試清單-persona-nexus-character.md) 案例 1 建立的 public 角色即可）。
- 需要一組有效 JWT（[測試清單-persona-nexus-auth.md](測試清單-persona-nexus-auth.md) 案例 7 登入取得），以及第二組帳號的 JWT（測 403 用）。

## 依據（讀原始碼確認）

`src/main.js:11-12` 從 URL query string 讀 `characterId`／`token`（這頁本來就設計成被 lobby 用 iframe 嵌入，`?characterId=...&token=...`），存進 `localStorage` 後才進 `chat.js` 的 `initChat()`。以下是 `chat.js` 實際會打的請求：

| 來源函式 | 請求 | 用途 |
|---|---|---|
| `initializeChat` | `GET /api/characters/:charId` | 取角色名稱 |
| `pollForConversation` | `GET /api/conversations/character/:charId`（輪詢直到 200） | 取得或建立對話（202=準備中／200=就緒／503=失敗） |
| `sendMessageToBackend` | `POST /api/conversations/:conversationId/messages` body `{text, tempUserId}` | 送出使用者訊息，觸發 AI 生成 |
| `pollForAIResponse` | `GET /api/conversations/:conversationId/ai-generation-status`（輪詢） | 查詢生成進度 |
| 同上完成後 | `GET /api/conversations/:conversationId/messages` | 取得最新訊息列表 |
| `deleteMessage` | `DELETE /api/conversations/:conversationId/messages/:messageId` | 回溯式刪除訊息 |
| 重啟按鈕 | `DELETE /api/conversations/:conversationId` 接著重新 `pollForConversation` | 整個聊天室砍掉重建 |
| 主角人設彈窗開啟 | `GET /api/conversations/:conversationId/protagonist` | 讀取主角設定 |
| 主角人設儲存 | `PUT /api/conversations/:conversationId/protagonist` body `{protagonistName, protagonistBackground}` | 寫入主角設定 |

**⚠️ CLAUDE.md 完全過時**：`persona-nexus-chat/CLAUDE.md` 和 `chat-service/CLAUDE.md` 都還寫著「訊息刪除、對話刪除待實裝」「聊天 API 尚未串接、目前是模擬回應」，但實際程式碼這些全部都已經完整實作（輪詢、樂觀更新、主角人設、回溯式刪除、重啟都有）。這份清單依實際 `conversationController.js` 撰寫。

後端回應（讀 `chat-service/src/controllers/conversationController.js`）：

| 端點 | 成功 | 主要錯誤情況 |
|---|---|---|
| `GET /conversations/character/:charId` | `200 {conversationId, messages}` | 202 `{status:"preparing"}`；503 `{status:"failed", message}`；404 角色不存在；403 無權限存取該角色 |
| `POST /conversations/:id/messages` | `201`（接收成功，非同步生成） | 400 缺 text；404 對話不存在；403 拒絕存取；**409** 上一則還在生成中；503 AI 服務不可用 |
| `GET /conversations/:id/ai-generation-status` | `200`，`{status: "pending"\|"completed"\|"failed", ...}` | 404／403 |
| `GET /conversations/:id/messages` | `200`，訊息陣列（未包裝） | 404／403 |
| `DELETE /conversations/:id/messages/:messageId` | `200 {status, deletedCount, deletedIds}` | 400 不是自己的訊息；404 訊息不存在；**409** AI 生成中拒絕刪除；503 記憶清理失敗 |
| `DELETE /conversations/:id` | `200 {status:"success", message}` | 503 RAG 清理失敗時**不會真的刪除** |
| `GET /conversations/:id/protagonist` | `200 {protagonistName, protagonistBackground}` | 404／403 |
| `PUT /conversations/:id/protagonist` | `200 {status:"success", ...}` | 503（RAG 更新失敗時 DB 不會被改） |

## 執行方式注意事項（實測踩過的坑，2026-07-25）

跟其他三份清單一樣的 PowerShell 三個坑（`Get-Content` 字串轉型、`$_.ErrorDetails.Message` 抓錯誤 body、中文轉 UTF-8 bytes），helper 函式見 [測試清單-persona-nexus-auth.md](測試清單-persona-nexus-auth.md)。這份清單額外要注意：

- **輪詢案例（2、5）真的需要等，不要設太短的逾時就判定失敗**：案例 2（建立對話，含 RAG 初始化）實測約 4-6 次輪詢（2 秒一次）內完成；案例 5（LLM 生成回覆）實測落在 6-11 次輪詢（3 秒一次，約 20-35 秒）內完成，第二次重測時甚至到過 6 次就完成——時間會因為 GPU 負載、模型是否剛冷啟動而有落差，輪詢上限建議抓 60 次以上比較保險，不要低於 30 次。
- **這種會等超過幾十秒的案例，建議用背景執行（`run_in_background`）跑輪詢迴圈，不要同步等**，同步等待中如果環境有其他逾時限制（例如工具呼叫的預設 timeout）可能會提早被切斷，看起來像失敗，實際上只是還沒等到。

## 測試案例

| # | 情境 | 請求 | 預期結果 |
|---|---|---|---|
| 1 | 取角色資訊 | `GET /api/characters/<測試角色id>`，帶 Bearer token | `200`，`data.name` 有值 |
| 2 | 建立/取得對話（首次） | `GET /api/conversations/character/<測試角色id>` | 第一次應為 `202 {status:"preparing"}`，短暫輪詢後應變 `200`，body 含 `conversationId` 與初始 `messages`（角色的 opening 台詞） |
| 3 | 查無此角色的對話 | `GET /api/conversations/character/char_0000000000000` | `404`，message「Character not found」 |
| 4 | 送出訊息，觸發 AI 生成 | `POST /api/conversations/<案例2的conversationId>/messages` body `{text:"你好，很高興認識你", tempUserId:"temp_test_1"}` | `201`（先接收） |
| 5 | 輪詢生成狀態直到完成 | 重複 `GET /api/conversations/<id>/ai-generation-status` | 最終 `status` 變成 `"completed"`（有耐心等，LLM 推論需要時間），不應該是 `"failed"` |
| 6 | 取得訊息列表，確認 AI 真的回了 | `GET /api/conversations/<id>/messages` | 陣列裡多了一筆 `role:"assistant"`、`status:"completed"` 的新訊息，`text` 非空 |
| 7 | 生成中重複送訊息（併發保護） | 案例 4 送出後**立刻**（生成還沒完成前）再送一次 `POST .../messages` | `409`，message「上一條訊息仍在處理中...」 |
| 8 | 讀主角人設（尚未設定過） | `GET /api/conversations/<id>/protagonist` | `200`，`protagonistName`/`protagonistBackground` 為 `null` 或空 |
| 9 | 寫入主角人設 | `PUT /api/conversations/<id>/protagonist` body `{protagonistName:"測試主角", protagonistBackground:"一個平凡的上班族"}` | `200`，`status:"success"` |
| 10 | 讀主角人設（確認寫入生效） | 再打一次案例 8 | `protagonistName` 變成「測試主角」 |
| 11 | 刪除訊息（回溯式） | `DELETE /api/conversations/<id>/messages/<案例4/6產生的使用者訊息id>` | `200`，`deletedCount >= 2`（該訊息 + 之後的 AI 回覆一起刪），`deletedIds` 包含兩者 |
| 12 | 刪除別人的對話（403） | 用第二組帳號的 token `DELETE /api/conversations/<案例2的conversationId>` | `403`，message「Access denied」 |
| 13 | 別人查詢這個對話的訊息（403） | 用第二組帳號的 token `GET /api/conversations/<id>/messages` | `403`，message「Access denied」（驗證跨帳號讀取漏洞的修正還在） |
| 14 | 刪除整個對話 | `DELETE /api/conversations/<案例2的conversationId>` | `200`，`status:"success"` |
| 15 | 刪除後查訊息 | 再打 `GET /api/conversations/<id>/messages` | `404`，message「Conversation not found」 |

## 資料庫驗證

`chat-service/prisma/dev.db`，表 `Conversation`（含角色快照欄位 `characterName`/`characterGender`/... 與主角欄位 `protagonistName`/`protagonistBackground`）、`Message`（`role`/`text`/`status`/`summarized`/`summaryId`，`onDelete: Cascade` 掛在 `conversationId` 外鍵上）。

> ⚠️ **這個路徑曾經是錯的，2026-07-25 已修復**：`chat-service/.env` 的 `DATABASE_URL` 相對路徑一度被 Prisma 解析成巢狀的 `chat-service/prisma/prisma/dev.db`（Prisma 對 SQLite 的相對路徑是相對 `schema.prisma` 檔案本身的位置解析，不是相對執行時的資料夾），害第一輪測試時查資料庫查到一個空檔案，一度誤判成資料不見了。詳情見 [部署除錯測試.md](部署除錯測試.md) 第 16 節。現在 `chat-service/prisma/dev.db` 已經是正確、唯一的資料庫檔案，可以放心照下面的路徑查。

> ⚠️ **執行順序：A/B/C 一定要排在案例 11、14（刪除訊息/刪除對話）之前做**，不然資料已經被刪掉會查不到。第一輪實測就是排錯順序，A/B/C 全部補不回來，只補測了 D。

| # | 驗證時機 | 查詢 | 預期結果 |
|---|---|---|---|
| A | 案例 2 之後（**刪除案例 11/14 之前**） | `sqlite3 chat-service/prisma/dev.db "SELECT id, characterName, protagonistName FROM Conversation WHERE id='<conversationId>'"` | 1 筆，`characterName` 已經是建立當下角色的名字快照（**不會**跟著角色之後被編輯而變動——這是刻意設計，見 schema 註解） |
| B | 案例 9 之後（**刪除案例 11/14 之前**） | 同一句查詢 | `protagonistName` 欄位是「測試主角」 |
| C | 案例 6 之後（**刪除案例 11/14 之前**） | `sqlite3 chat-service/prisma/dev.db "SELECT role, status, summarized FROM Message WHERE conversationId='<id>' ORDER BY createdAt"` | 至少 3 筆（opening 的 assistant 訊息、案例4的 user、案例6的 assistant），新訊息 `status='completed'`、`summarized=0` |
| D | 案例 14（刪除對話）之後 | `sqlite3 chat-service/prisma/dev.db "SELECT COUNT(*) FROM Message WHERE conversationId='<id>'"` | `0`——驗證 `onDelete: Cascade` 真的連帶刪掉訊息，不是只刪 Conversation 那一列留下孤兒 Message |

## 不在這份清單範圍內（原因）

- **樂觀更新的畫面渲染、佔位符訊息、虛擬滾動（`virtualMessageList.js`）**：純前端 UI 邏輯，不牽涉後端請求。
- **重啟聊天室按鈕**：程式碼上是「刪除（案例 14 的邏輯）+ 重建（案例 2 的邏輯）」的組合，兩段邏輯都已經個別測過，不重複整套測一次。
- **Qdrant／RAG 內部運作是否真的把角色背景/摘要正確檢索進 prompt**：這屬於 ai-service 的 RAG 品質驗證，不是「前端請求有沒有正常運作」的範圍，若要驗證回覆品質是否真的貼合角色設定，需要另外設計評測方式。
- **ai-service 直接呼叫**：`persona-nexus-chat` 從不直接打 ai-service（案例 4/5 這條路徑是 chat-service 內部去呼叫 ai-service），前端只看得到 chat-service 這一層的行為，這裡測的就是前端實際看得到的邊界。

---

## 實測結果（2026-07-25）

**15/15 案例通過。** DB 驗證因為第一輪排錯順序（見上方警告），只有 D 有效驗證到；A/B/C 之後在確認 chat-service 資料庫路徑修復時，用一次新的煙霧測試（建對話→送訊息→AI 生成→確認訊息→刪除→cascade）補跑過，全部通過。案例 6 的 AI 回覆是真的依角色人設生成的內容，不是罐頭回應，證實 RAG + Ollama 整條管線運作正常。
