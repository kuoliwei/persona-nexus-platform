## Context

`conversationService.js` 1263 行、7 種職責混在同一檔案，是 chat-service 累積最久的結構債。
過去兩輪稽核都碰到它但都沒動：
- 2026-07-25 架構層稽核：判定 SOLID-SRP 違反「把握度低，建議列為觀察項」
- 2026-07-30 程式碼層稽核：標為 🔴 高，但只加區段註解，理由是無測試安全網

本輪把「無測試安全網」這個前提條件直接解決掉，然後真的拆。

### 探索確認的關鍵事實（決定拆檔可行性）

拆檔前先做了完整的呼叫圖分析，結果比預期樂觀得多：

1. **全檔只有 1 處 `this.` 跨方法呼叫**（`sendMessageToConversation` → `_generateAIResponseAsync`）
2. **全檔只有 1 個模組級可變狀態**（`requestCounter`），且只被單一方法使用
3. **9 個私有 helper 中，6 個 fan-in = 1**（只被一個方法呼叫，可直接搬走）
4. **真正跨模組共用的只有 2 個**：`validateUserId`、`assertConversationOwnership`
5. 所有候選切點經驗證皆為**單向 DAG，無循環依賴風險**

**為什麼這麼乾淨**：舊的記憶體 Map（`creationJobs`／`aiGenerationStatus`）早在 2026-07-25～26
的持久化改造中就搬進 repository 層了，所以 service 層沒有共用可變狀態的地雷。

## Goals / Non-Goals

**Goals:**
1. ✅ 建立可用的單元測試框架與足夠的回歸安全網
2. ✅ 依職責（非行數）把巨型檔案拆成邊界清楚的模組
3. ✅ 拆檔過程零行為變更，且可被自動化驗證
4. ✅ controller 零修改

**Non-Goals:**
- 不改任何業務邏輯（唯一例外：移除已確認的死參數）
- 不處理 console.log 氾濫（先前兩輪已確認暫緩）
- 不處理 SOLID-DIP（先前已確認 JS 環境下屬約定俗成）
- 不補 controller／repository 層的單元測試（本輪聚焦 service 層）
- 不引入 TypeScript、不加 lint

## Decisions

### 1. 測試打 barrel，不打個別模組 —— 這是整個計畫的安全性核心

**決策：** 所有測試一律透過 `conversationService.X(...)` 呼叫，即 controller 使用的同一層介面。

**為什麼：** 測試若直接打個別內部函式，拆檔時就得跟著改斷言——那樣「測試通過」就失去意義
（你無法分辨是行為沒變，還是斷言被改到能通過）。打 barrel 則讓同一份測試在拆檔前後都適用，
**測試檔 zero diff + 全綠**就是行為未變的直接證據。

先在單檔狀態下把 82 則測試轉綠並 commit，再拆檔，跑同一份測試。

### 2. 拆分依據是專案自己的職責清單，不是行數

**決策：** 用《程式撰寫設計原則.md》第 50-57 行的職責清單當切分依據。

**為什麼：** 該文件正是拿 `conversationService.js` 當範例寫的，等於作者早就把職責分類寫好了。
用行數當標準會切出語意不連貫的模組；用專案自己的原則文件則保證分類與既有設計思維一致。

文件本身的指引也吻合：職責 3/4/5「考慮獨立」、職責 6「應該提取」。

主角人設（職責 7）是文件寫成之後才加的功能，補進清單。

### 3. `conversationOwnership.js` 必須是葉節點

**決策：** 擁有權檢查獨立成檔，只 import repository，**絕不 import 任何兄弟 service 模組**。

**為什麼：** 它被 9 個方法共用，是唯一有可能製造循環依賴的地方。若把它放進
`conversationCrudService.js`（理由：都用 `conversationRepository`），則
message/generation/protagonist 全都要 import crud，一旦 crud 日後需要反向依賴任何一方就成環。

### 4. 保留 barrel

**決策：** `conversationService.js` 降為組裝層，重組出原本的 17 方法物件。

**為什麼：** `conversationController.js` 有 16 處 `conversationService.X(...)` 呼叫。保留 barrel
讓拆檔變成純檔案搬移，controller 一行都不用改——大幅降低風險，也讓「行為未變」更容易論證。

**代價：** 多一層間接。可接受，且未來若要改成 controller 直接 import 各模組，是獨立且低風險的後續工作。

### 5. 移除 `this._generateAIResponseAsync`

**決策：** 改為直接呼叫模組內函式。

**為什麼：** `this.` 的寫法隱性依賴「barrel 有把該方法合併進同一個物件」且「呼叫方不解構」。
兩者都成立時能運作，但那是脆弱的巧合。改成直接呼叫後，兩個函式同檔，`this` 完全消失。

## Risks / Trade-offs

| 風險 | 概率 | 影響 | 緩解 |
|------|------|------|------|
| 拆檔造成行為改變 | 低 | 高 | 82 則測試 + zero diff 驗證；純搬移不改邏輯 |
| 循環依賴 | 低 | 高 | ownership 維持葉節點；子模組不得 import barrel；用「17 個方法全部解析為 function」自動檢查 |
| 測試漏掉某條路徑，拆檔時被改壞 | 中 | 中 | 覆蓋全部 17 個方法的 happy path + 每個 JSDoc 錯誤碼；controller/repository 層未覆蓋，靠 `test.http` 補 |
| 背景任務（fire-and-forget）在測試中洩漏 | 中 | 低 | `_prepareAndCreateConversation` 相關測試讓 `initializeRAG` 立刻失敗，走進 catch 直接結束，不留待觸發的 timer |

## 已知落差（誠實記錄）

- **Controller、Repository 層仍無單元測試**：本輪聚焦 service 層。若日後要動 controller
  的 ERROR_MAP 映射或 repository 的持久化開關邏輯，同樣缺乏安全網。
- **log 前綴仍寫 `[conversationService]`**：拆檔後這些 log 分散在 7 個檔案裡，但前綴未改。
  維持不動是為了讓本輪嚴格保持「純搬移」；若要改成各自的模組名，應為獨立變更。
