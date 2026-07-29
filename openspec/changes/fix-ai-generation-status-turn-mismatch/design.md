## Context

`chat-service` 的「發送訊息」是非同步管線：`POST /api/conversations/:id/messages` 立即回 `accepted`，背景 `_generateAIResponseAsync()` 呼叫 ai-service 生成回覆，成功後**原子性**同時存使用者訊息 + AI 回覆。前端 `persona-nexus-chat` 則以樂觀更新先畫出兩個氣泡（`temp_*` 使用者訊息、`placeholder_*` 佔位符），再輪詢 `GET /ai-generation-status` 取得結果並替換。

狀態載體是 `Conversation` 表的六個欄位（2026-07-26 從進程內 Map 改為持久化）：

| 欄位 | 寫入者 |
|------|--------|
| `generationStatus` | `tryAcquireLock` → `'generating'`；`setCompleted` → `'completed'`；`setFailed` → `'failed'`；`releaseLock`/`reset` → `null` |
| `generationError` | `tryAcquireLock`（清空）、`setFailed` |
| `generationTempUserId` | **只有** `setCompleted` |
| `generationUserMessageId` | **只有** `setCompleted` |
| `generationAssistantMessageId` | **只有** `setCompleted` |
| `generationUpdatedAt` | `tryAcquireLock`、`setCompleted`、`setFailed` |

### 當前（有問題）的時序

```
前端                          Caddy/gateway            chat-service DB 狀態
 │
 │ sendMessage()
 ├─ push temp_user、placeholder，renderMessages()      generationStatus='completed'   ← 上一回合殘留
 ├─ pollForAIResponse() 啟動 setInterval(1000)          generationTempUserId=temp_A    ← 上一回合
 ├─ sendMessageToBackend() ──POST──▶ ...               generationUserMessageId=u_A     ← 上一回合
 │                                                     generationAssistantMessageId=a_A ← 上一回合
 │
 │ t=1000ms
 ├─ GET /ai-generation-status ─────▶ 讀到上表 ────────▶ 回 { status:'completed',
 │                                                          tempUserId:'temp_A',
 │                                                          userMessageId:'u_A',
 │                                                          assistantMessageId:'a_A' }
 ├─ 無條件採信：
 │     messages[tempUserIndex] = 舊的 u_A       ← 剛送出的使用者氣泡被覆蓋
 │     replaceOrPushMessage(placeholderId, a_A) ← 佔位符被覆蓋
 │     clearInterval(pollInterval)              ← 輪詢停止，本回合真正的回覆再也不會被取回
 │
 │ t≈1200ms  POST 才跑到 tryAcquireLock() ────────────▶ generationStatus='generating'
 │                                                     （三個 ID 欄位仍是上一回合的值）
```

尾端出現與上方重複的 message id → `virtualMessageList` 以 id 為 `keyOf`，`renderedEls` Map 撞 key 取到同一個 DOM 節點並 `insertBefore` 搬移 → 視覺上兩個氣泡消失。

### 約束

- 兩個 repo 皆無自動化測試框架，驗證只能靠手動走查與人為放大競態視窗。
- `generationStatusRepository` 有兩套實作分支（`config.persistence.enableGenerationStatus` 開/關），任何改動必須兩邊一致——這是既有的測試約定（先前 14/14 一致性腳本）。
- 不可引入 schema 變更：`Conversation` 表已有全部需要的欄位，只是寫入時機錯了。

## Goals / Non-Goals

**Goals:**

- 讓 `GET /ai-generation-status` 的回應在任何時刻都能被明確歸屬到「某一個回合」。
- 讓前端在狀態歸屬不明時**維持現狀繼續等待**，而不是採信錯誤資料並停止輪詢。
- 修正後，使用者送出的訊息在任何時序下都不會憑空消失。
- 後端單方部署即已改善（縱深防禦），不強制兩端同時上線。

**Non-Goals:**

- 不改成 WebSocket / SSE。輪詢是既有設計決策（`same-origin-deployment` design 決策 7），本輪不動。
- 不動 `virtualMessageList.js` 的重複 key 行為。重複 key 是本 bug 的**放大器**而非根因；讓 vlist 對重複 key 更健壯是獨立的健壯性議題，另案處理（見 Open Questions）。
- 不改前端「先啟動輪詢、再非同步 POST」的順序（見決策 3）。
- 不移除既有的 `🐛 [DEBUG]` log。

## Decisions

### 決策 1：在「上鎖」時就標記回合身分，而不是等到「完成」

`tryAcquireLock()` 成功時同時寫入本回合的 `generationTempUserId`，並把 `generationUserMessageId` / `generationAssistantMessageId` 清為 `null`。

**理由**：上鎖是「本回合開始」的唯一原子性時間點，也是狀態語意應該翻頁的地方。把回合身分綁在這裡，`generating` 狀態才是自洽的——它描述的是當前回合，而非「狀態碼是新的、ID 是舊的」這種混合體。

**替代方案 A：`tryAcquireLock` 只清空三個 ID，不寫 `tempUserId`。** 能消除「誤用上一回合訊息」，但前端無法區分「本回合還沒開始」與「本回合正在跑」，也無法把 `failed` 歸屬到回合。捨棄。

**替代方案 B：純前端修，比對 `assistantMessageId` 是否已存在於本地 `messages` 陣列。** 不需動後端，但這是靠「巧合可偵測」而非契約——若使用者在同一聊天室重新整理過、本地陣列不含舊訊息，偵測就失效。捨棄。

**替代方案 C：前端改成 `await POST` 之後才啟動輪詢。** 見決策 3。

### 決策 2：`setFailed` 必須保留上鎖時寫入的 `tempUserId`

`setFailed` 目前只寫 `generationStatus` / `generationError` / `generationUpdatedAt`，不動 `generationTempUserId`。搭配決策 1 後，這個「不動」正好是對的：上鎖時已寫入本回合的 `tempUserId`，`setFailed` 保留它即可。**要明確寫進 spec 並在實作時確認，不能只是碰巧成立**——若日後有人為了「清乾淨」而在 `setFailed` 裡把 `tempUserId` 設 null，前端守門會讓真實失敗要等滿 120 秒才顯示失敗氣泡，且沒有任何測試會抓到。

### 決策 3：前端維持「先啟動輪詢、再非同步 POST」，改用守門而非改順序

改成 `await postMessage()` 成功後才啟動輪詢也能避開這個視窗——`sendMessageToConversation` 是先 `tryAcquireLock` 才做 `findUnsummarized`／`executeSummary` 再回應，所以 POST 回應到達時鎖必定已上好。但這個修法有兩個缺點：

1. 它把「正確性」建立在**後端內部的語句順序**上。哪天有人為了效能把 `tryAcquireLock` 往後挪、或在它之前多加一個 await，前端就會無聲地退回今天這個 bug——而且沒有任何測試會抓到。
2. 它把「送出」與「等待」耦合成序列，任何後端回應變慢都直接變成輪詢啟動變慢（摘要觸發時 `executeSummary` 會呼叫 ai-service，可能數秒）。

守門法（比對 `tempUserId`）則是**時序無關**的正確性條件：不論輪詢多早開始、後端多晚上鎖，前端都只會在讀到屬於本回合的狀態時才動畫面。選守門法。

### 決策 4：守門不符時「繼續輪詢」，不做任何 UI 變更

讀到不屬於本回合的狀態時：不替換氣泡、不停止 `setInterval`、不解除輸入禁用、**照舊累加 `attempts`**。累加的理由是超時保護必須是絕對時間上限——若守門不符就不計數，遇到後端永遠沒上鎖（POST 徹底失敗）的情況，輪詢會無限跑。POST 失敗本身有 `sendMessageToBackend` 的 catch 呼叫 `stopPoll()` 收尾，但超時計數不該依賴另一條路徑的正確性。

### 決策 5：兩種持久化分支必須行為一致

`enableGenerationStatus` 為 `false` 時走記憶體 Map。`tryAcquireLock` 的記憶體分支目前 `set()` 一個全新物件（只有 status/error/updatedAt），**副作用上已經清掉了舊的 ID 欄位**——與 DB 分支行為不同（DB 分支是 `updateMany` 只更新指定欄位，舊 ID 留著）。這個既有不一致正是「兩套實作容易分岔」的實例。本輪把兩邊都明確寫成「寫入本回合 tempUserId + 清空兩個訊息 ID」，並沿用先前的一致性驗證腳本手法補一輪比對。

### 決策 6：不新增端點、不新增欄位

`GET /ai-generation-status` 已回傳 `tempUserId`，前端只是沒用。這是純語意收緊的修正，API 形狀不變，不需要版本化。

## Risks / Trade-offs

- **[新前端 + 舊後端的混合部署]** → 舊後端的 `setFailed` 帶著上一回合的 `tempUserId`，新前端守門會擋掉真實失敗，使用者要等滿 120 秒輪詢超時才看到失敗氣泡（內容仍正確，只是慢）。緩解：兩端一起部署；本專案為單機開發環境，實際上不存在滾動升級。
- **[舊前端 + 新後端]** → `generating` 期間 `assistantMessageId` 變成 `undefined`，舊前端的 ID 配對路徑找不到目標，退回時間篩選後備路徑（`createdAt > userMessageCreatedAt`）。該路徑要求 `role==='assistant' && status==='completed' && createdAt > 使用者訊息時間`，上一回合的舊訊息不滿足時間條件，因此不會再誤用——舊前端也有改善。但時間篩選依賴**瀏覽器時鐘 vs 伺服器時鐘**，若客戶端時鐘超前，本回合真實回覆也可能被濾掉而走到超時。此風險在修正前就存在，本輪不擴大也不解決。
- **[守門把真實狀態誤判為非本回合]** → 唯一會發生的情況是後端沒有在上鎖時寫入 `tempUserId`（決策 1 沒實作到位，或前端沒送 `tempUserId`）。緩解：實作時在守門不符的分支加一行 log 印出 `期望 vs 實際` 的 `tempUserId`，讓這種情況在 console 裡立刻可見，而不是靜默地跑到 120 秒超時。
- **[競態難以重現，改完無法確信有效]** → 緩解：驗證階段用可控手法把 1 秒視窗放大（見 Migration Plan 步驟 3），先重現失敗、再驗證修正。不接受「跑幾次沒看到就算修好」。
- **[虛擬滾動的重複 key 仍是未爆彈]** → 本輪不處理，但已記錄在 Open Questions。修正後根因消失，實務上不再有觸發路徑。

## Migration Plan

無 DB migration、無環境變數變更、無部署配置變更。

1. **後端先行**：改 `conversationRepository.js` 的 `tryAcquireLock`（含兩種持久化分支）與 `conversationService.js` 的呼叫點；跑一致性比對確認兩分支行為相同。此時舊前端已獲得部分改善（不再誤用上一回合訊息）。
2. **前端跟上**：改 `chat.js` 的 `pollForAIResponse` 守門。
3. **放大競態視窗驗證**（關鍵步驟）：在 `sendMessageToConversation` 的 `tryAcquireLock` 之前暫時插入 `await new Promise(r => setTimeout(r, 3000))`，讓每次送訊息都必定落入舊的錯誤視窗。
   - 先在**未修正**的程式上跑，確認能穩定重現「兩個氣泡一閃消失」——確立這個手法真的打中根因。
   - 再套用修正跑，確認氣泡穩定保留、佔位符維持「思考中」、AI 回覆最終正確替換佔位符。
   - 驗證完**移除**這段延遲。
4. **回歸走查**：正常送訊息（第 1 則與第 2 則以後）、AI 生成失敗、輪詢超時、連續快速送兩則（第二則應被 409 擋下）、刪除訊息後再送。
5. **文件同步**：更新兩個 repo 的 `CLAUDE.md`，並視情況把本變更的規格同步回 `chat-service/openspec/specs/conversations` 與 `persona-nexus-chat/openspec/specs/chat-ui`。

**Rollback**：兩處改動各自獨立、無狀態遷移，`git revert` 即可。DB 中已被清成 `null` 的 ID 欄位不影響舊版程式（舊版只在 `setCompleted` 後讀取，那時三個欄位都會被重新寫滿）。

## Open Questions

- `virtualMessageList` 對重複 key 的行為（同一 DOM 節點被搬移、`totalHeight` 重複計算撐條高度）是否要另立變更加防護，例如渲染前對 `keyOf` 去重並在 console 警告？本輪不處理，待根因修正驗證穩定後再評估。
- 前端從未呼叫 `DELETE /ai-generation-status`（`clearAIGenerationStatus`）。該端點目前無使用者——是應該在每回合開始前呼叫（讓狀態顯式翻頁），還是確認為死端點後移除？決策 1 已讓它變得非必要，但端點的去留尚未決定。
- `_generateAIResponseAsync` 的 `setFailed` 路徑之後，鎖是否有被正確釋放、下一回合能否立即送出（`generationStatus='failed'` 不等於 `'generating'`，`tryAcquireLock` 的 where 條件會放行）——本輪順帶在回歸走查中確認，未發現問題就不動。
