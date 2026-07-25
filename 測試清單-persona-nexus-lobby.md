# persona-nexus-lobby 前端 API 測試清單

> 目的：驗證大廳（首頁／我的角色／側邊欄聊天歷史）實際會發出的每一種前端→後端請求都正常運作。指令模擬各檔案裡 `fetch()` 呼叫的同樣 URL、method、header。允許建立/刪除測試資料。
>
> **依賴：auth（登入 token）+ character（測試角色）先做完即可，不需要先跑 chat 清單。** 案例 5/7 用的對話是這份清單自己建立的專屬對話，**刻意不跟** [測試清單-persona-nexus-chat.md](測試清單-persona-nexus-chat.md) 共用——那份清單案例 14 會把自己建立的對話用 `DELETE /conversations/:id` 刪掉，如果這裡也去搶同一筆來測刪除，兩邊誰先跑誰就會讓另一邊的測試對象消失、變成意外測到 404。

## 依據（讀原始碼確認）

lobby 是一個有自己 SPA 路由（`history.pushState`／`popstate`）的殼，實際頁面內容動態載入。跟後端有直接 API 往來的檔案：

- `src/api.js:22-37`（`listMyCharacters`）：`GET /api/characters?authorId=<userId>`，帶 `Authorization: Bearer <token>`。
- `src/home.js:29-33`：`GET /api/characters?visibility=public`，帶 `Authorization` header（雖然這條後端邏輯上對 public 查詢不檢查身份，但前端還是照送）。
- `src/sidebar.js:168-170`（`loadChatHistoryButtons`）：`GET /api/conversations/summary`，帶 `Authorization` header，回應是**未包裝的陣列**（不是 `{status,data}` 形狀，見下方後端依據）。
- `src/sidebar.js:116-119`（對話選單的刪除）：`DELETE /api/conversations/character/:characterId`，帶 `Authorization` header。
- `src/character-create.js`、`src/character-edit.js`、`src/chat-page.js`：**不直接打後端**，是把 `persona-nexus-character`／`persona-nexus-chat` 用 `<iframe>` 嵌進來（`src` 指向 `/character/creator-create.html?token=...`、`/chat/index.html?characterId=...&token=...`），實際的建立/編輯角色、聊天 API 呼叫發生在 iframe 裡的那兩個前端專案內，屬於另外兩份清單的範圍，這裡不重複測。

後端實際回應：
- `character-service` 的 `GET /characters?...` 回應格式跟 [測試清單-persona-nexus-character.md](測試清單-persona-nexus-character.md) 記載的一致（`{status,message,data}`），這裡不重複列，只列 lobby 特有的查詢參數組合行為：
  - `visibility=public`：回傳**全部使用者**的公開角色（`character-service/src/services/characterService.js:102-107`），不限本人
  - `authorId=<自己的 userId>`：回傳該作者的全部角色（含 private），因為 `requesterId`（從 JWT 來）等於查詢的 `authorId`（`characterService.js:108-116`）
- `chat-service` 的 `GET /conversations/summary`（讀 `chat-service/src/controllers/conversationController.js:71-87`）：`200`，body 是**陣列**（不是物件包一層），每筆含 `characterId`、`characterName`、`conversationId` 等欄位；沒有對話則回傳空陣列 `[]`（不會是 404）
- `chat-service` 的 `DELETE /conversations/character/:characterId`（讀 `conversationController.js:252-286`）：
  - 成功 → `200`，`{status:"success", message:"...", deletedCount: N}`
  - 該角色從沒開過對話 → `404`，`{status:"error", message:"No conversations found for this character"}`
  - 角色不存在 → `404`，`{status:"error", message:"Character not found"}`
  - **ai-service 不可用時**（RAG 清理失敗）→ `503`，聊天室**不會**被刪除——這條路徑依賴 ai-service 正常運作，測試前確認 ai-service 有在跑

**⚠️ 這裡的 CLAUDE.md 嚴重過時**：整份文件還停留在「主內容區暫時空白」的舊版本，完全沒提到現在實際存在的首頁角色列表（`home.js`）、我的角色頁（`my-character.js`）、聊天歷史側邊欄（`sidebar.js` 的 `loadChatHistoryButtons`）、SPA 路由還原（`main.js` 的 `restoreRouteFromUrl`）、iframe 嵌入其他前端等機制。這份測試清單全部依據目前實際原始碼，不採信 CLAUDE.md 的描述。

## 執行方式注意事項（實測踩過的坑，2026-07-25）

跟 [測試清單-persona-nexus-auth.md](測試清單-persona-nexus-auth.md) 的「執行方式注意事項」一樣三個坑（`Get-Content` 讀出來的字串塞進 JSON body 前要 `[string]` 轉型、錯誤 body 要讀 `$_.ErrorDetails.Message`、中文欄位要轉 UTF-8 bytes），helper 函式見 auth 清單。這份清單的請求大多是 GET／DELETE 沒有 body，實際踩到的機率較低，但案例中若要組 body（目前沒有）一樣要注意。

**案例 3 的已知限制**：執行時如果帳號 B 從沒建立過角色，這個案例會回傳空陣列 `[]`——這樣仍然是「正確」的結果（沒有東西可回本來就該是空的），但沒辦法真正驗證「private 角色會被過滤掉」這件事，因為根本沒有東西可以被過滤掉。想要更嚴謹的話，帳號 B 應該先各建一個 public 和 private 角色，再測這個案例，確認回傳裡只有 public 那個。

## 測試案例（需要先有有效 JWT；建議搭配 persona-nexus-character 清單先建立 1 個 public、1 個 private 測試角色）

| # | 情境 | 請求 | 預期結果 |
|---|---|---|---|
| 1 | 首頁公開角色列表 | `GET /api/characters?visibility=public`，帶 Bearer token | `200`，`data` 陣列包含之前建立的 public 測試角色，**不包含** private 的 |
| 2 | 我的角色列表（本人） | `GET /api/characters?authorId=<自己userId>`，同一個 token | `200`，`data` 陣列同時包含自己的 public 和 private 角色 |
| 3 | 我的角色列表（查別人的 authorId，帶自己的 token） | `GET /api/characters?authorId=<別人的userId>`，帶自己的 token | `200`，`data` 只包含對方的 public 角色（驗證 `characterService.js:112-115` 的權限過濾邏輯） |
| 4 | 聊天歷史摘要（尚未有任何對話） | `GET /api/conversations/summary`，一個全新測試帳號的 token | `200`，body 是空陣列 `[]` |
| 5 | 聊天歷史摘要（有對話後） | 用 [測試清單-persona-nexus-character.md](測試清單-persona-nexus-character.md) 案例 2 建立的 private 角色（**不要用 chat 清單測試用的那個角色**，避免搶同一筆對話）打 `GET /api/conversations/character/<該角色id>`（輪詢到 200 即可，不用真的送訊息、不用等 AI 生成，`getOrCreateConversation` 光是這個 GET 就會建立好 Conversation 列並帶入 opening 台詞），建立好之後再打 `GET /api/conversations/summary` | `200`，body 陣列裡有一筆，`characterId`／`characterName`／`conversationId` 有值 |
| 6 | 刪除某角色的對話（該角色從沒聊過） | `DELETE /api/conversations/character/<一個沒被聊過的角色id>`，帶 Bearer token | `404`，message「No conversations found for this character」 |
| 7 | 刪除某角色的對話（成功） | 用案例 5 建立的對話，`DELETE /api/conversations/character/<該角色id>` | `200`，`deletedCount >= 1`；之後再打案例 5 那條 `GET /api/conversations/summary` 應該不再包含這筆 |
| 8 | 沒帶 token 查我的角色 | `GET /api/characters?authorId=xxx` 不帶 `Authorization` | `401`（gateway 這層擋下） |

## 不在這份清單範圍內（原因）

- **`/src/*.html` partial 載入**（`home.html`／`my-character.html`／`sidebar.html`／`chat.html`／`character-edit.html`）：這些是 Vite 靜態檔案請求，不是後端業務 API，同源路由是否正常已經在之前的架構驗證階段測過（5 條 Caddy 路由全 200）。
- **iframe 內部（`persona-nexus-character`、`persona-nexus-chat`）的建立/編輯角色、傳訊息等 API**：屬於各自的測試清單，這裡只驗證 lobby 有沒有正確組出 iframe 的 `src`（帶對的 `token`／`characterId`），不重複測 iframe 內部行為。
- **SPA 路由還原、`pushState`/`popstate` 歷史管理**：純瀏覽器端狀態管理，不牽涉後端請求。

---

## 實測結果（2026-07-25）

**8/8 案例全數通過。** 案例 3 實測當下 B 帳號還沒建立過角色，回傳空陣列——結果正確，但如上方「已知限制」所述，沒有實際驗證到過濾行為本身，之後如果要更嚴謹驗證可以照建議補資料重測。案例 5 的 `characterName` 快照正確反映了 character 清單案例 10 改名後的最新名稱。
