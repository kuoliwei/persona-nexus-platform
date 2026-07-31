## Context

`chat.js` 目前是一個 655 行的閉包：`initChat(characterId)` 內部宣告了 DOM 參照、`messages` 陣列、`vlist` 虛擬滾動實例，並定義十幾個函式共享這些變數。拆分的核心難點不是「把程式碼搬到別的檔案」，而是**這些函式互相依賴的可變狀態（`messages`、`vlist`、DOM 禁用狀態）要用什麼方式在拆開後的模組間繼續共享**，同時不破壞既有的回合守門（turn-gating）不變式與樂觀更新時序。

本專案已有一個現成的模式可參考：`virtualMessageList.js` 用 `createVirtualMessageList({ deps }) → { methods }` 的工廠函式模式封裝內部狀態，不用 class、不用模組級單例。這與《前端系統設計原則.md》的「模組邊界與資訊隱藏」一致——呼叫方只看到 `export` 出的方法，不需要知道內部怎麼存資料。

## Goals / Non-Goals

**Goals:**
- 依「修改理由是否獨立」拆分職責，讓改動範圍可預測（改輪詢策略不會意外影響發送邏輯）
- 沿用專案既有的工廠函式模式（與 `virtualMessageList.js` 一致），不引入 class 或框架
- 用回呼（callback）注入的方式讓純邏輯模組（poller、sender）不直接碰 DOM，只通過 `onRender`／`onInputLock` 等回呼與 UI 互動
- 完全保留現有對外行為，包含回合守門的不變式（見 `aiResponsePoller.js` 內要原樣保留的注釋）

**Non-Goals:**
- 不重寫聊天室的業務邏輯或修正既有 bug（本輪純重構）
- 不引入狀態管理框架（Redux/Zustand 等）——YAGNI，目前規模不需要
- 不處理 `lobby` 的職責聚合（屬於下一個獨立 change）
- 不新增測試框架（本專案現況無測試，維持現況，用 build + 手動走查驗證）

## Decisions

### 1. 用工廠函式封裝狀態，而非模組級單例或 class
每個需要維護狀態的模組（`messageStore`、`aiResponsePoller`、`conversationManager`）都 export 一個 `createXxx(deps)` 函式，回傳一組綁定好內部狀態的方法。`chat.js` 的 `initChat()` 負責建立實例並把彼此的依賴接起來。

**為什麼不用模組級單例（`let messages = []` 直接寫在 messageStore.js 頂層）**：`initChat()` 理論上可能被呼叫不只一次（例如頁面重新初始化的情境），模組級單例會讓多次呼叫共享同一份狀態，產生跨實例污染。工廠函式模式讓每次 `initChat()` 都拿到全新、互相隔離的狀態容器，這也是 `virtualMessageList.js` 已驗證過的既有慣例。

**為什麼不用 class**：專案是 Vanilla JS 無框架、無 TypeScript，既有程式碼零 class 使用，工廠函式是本專案的一致慣例（一致性原則優先於個人偏好）。

### 2. `messageStore.js` 是 `messages` 陣列的唯一寫入點
```js
createMessageStore(initialMessages = [])
  → { getAll(), setAll(msgs), push(msg), replaceOrPush(id, msg), removeByIds(idSet), findById(id) }
```
所有其他模組（sender、poller、conversationManager、chat.js 本身）一律透過這組方法讀寫訊息，不再有任何模組直接 `messages.push(...)` 或 `messages[i] = ...`。這是《程式撰寫設計原則.md》C2（狀態傳遞透明性）在前端的具體套用——目前 `deleteMessage()`／`sendMessage()`／`pollForAIResponse()` 三處各自直接改陣列，改完後追蹤「誰改了 messages」需要 grep 整個檔案；拆分後只需看 `messageStore.js` 一處。

### 3. UI 副作用一律用回呼注入，邏輯模組不碰 DOM
`aiResponsePoller.js`、`messageSender.js`、`conversationManager.js` 都不接收 DOM element 參照，而是接收回呼函式：
- `onRender()` — 觸發重新渲染（chat.js 綁定到 `renderMessages`）
- `onInputLock(locked)` — 禁用/啟用輸入框與送出鈕（chat.js 綁定到操作 `messageInput`/`sendBtn`）
- `getCharacterName()` — 讀取目前角色名稱（chat.js 綁定到讀 `characterNameEl.textContent`）

這是《前端系統設計原則.md》B節「模組邊界與資訊隱藏」的套用：邏輯模組的呼叫方（chat.js）決定「禁用輸入」實際上要操作哪個 DOM 元素，邏輯模組本身不假設任何 DOM 結構，未來若要幫這些模組補測試（目前本專案無測試，但保留可能性）不需要 mock DOM。

### 4. `conversationManager.js` 收斂三個子職責，不再往下拆
初始化（`initializeChat`）、輪詢建立狀態（`pollForConversation`）、重啟（`restartConversation`）三者共用同一組「聊天室生命週期」概念與同一套輪詢邏輯（`pollForConversation` 被 `initializeChat` 和重啟流程共同呼叫）。依《程式撰寫設計原則.md》A1 的判斷準則——「修改『職責 A』經常被迫同時改『職責 B』」時應合併——這三者符合合併條件：重啟本質上就是「刪除＋重新走一次初始化的建立輪詢」，拆開反而會製造兩份輪詢邏輯或增加不必要的跨模組呼叫。

### 5. `aiResponsePoller.js` 完整保留回合守門邏輯與原有注釋
原檔案 412-423 行有一段解釋「為何用 tempUserId 而非時序來判斷回合歸屬」的長注釋，這是一個容易被誤刪、誤改的不變式說明（作者已明確寫出「日後有人把 tryAcquireLock 往後挪，前端會無聲退回同樣的 bug」）。拆分時原樣搬移這段注釋到新檔案，不精簡、不重寫。

## Risks / Trade-offs

- **[風險] 拆分過程中不慎改變閉包捕獲的變數時機，導致 TDZ 或狀態不同步** → 緩解：採漸進式抽取（見遷移步驟），每抽出一個模組就跑一次 `npm run build` + 手動走查對應功能，不一次性重寫整個檔案
- **[風險] messageStore 的方法簽名如果和原本三處直接操作陣列的邏輯有細微差異（例如 `replaceOrPush` 的比對條件）會產生行為差異** → 緩解：`messageStore.js` 的方法直接照搬原本 `replaceOrPushMessage()`／`makeFailureMessage()` 的邏輯，不做「順便改進」
- **[取捨] 回呼注入增加了 chat.js 中「接線」的樣板程式碼（wiring）** → 可接受：換來的是邏輯模組可獨立閱讀、獨立驗證，樣板集中在 `initChat()` 頂部，一眼可見全部依賴關係

## Migration Plan

依序抽取，每步驟後用 `npm run build` 確認打包成功，並在瀏覽器手動走查對應功能：
1. 抽 `messageFormatter.js`（純函式，零依賴，風險最低）→ 驗證訊息文字渲染（含括弧敘事樣式）正常
2. 抽 `messageStore.js` → 驗證發送/刪除/輪詢替換訊息後畫面正確
3. 抽 `aiResponsePoller.js` → 驗證 AI 回覆輪詢、回合守門（連續快速發送兩則訊息不應互相覆蓋）、失敗氣泡
4. 抽 `messageSender.js`（依賴 poller 的啟動函式）→ 驗證發送流程與樂觀更新
5. 抽 `conversationManager.js` → 驗證初始化輪詢、重啟聊天室
6. 精簡 `chat.js` 為協調層，移除已搬移的函式，只保留 DOM 查詢與事件綁定
7. 全流程回歸走查：開啟聊天室 → 發送訊息 → 等待 AI 回覆 → 刪除訊息 → 重啟聊天室 → 開啟主人公人設彈窗

無需 rollback 策略——本變更未涉及資料庫遷移或已部署的服務契約，若發現問題直接修正程式碼即可，不影響其他前端或後端服務。

## Open Questions

無——拆分範圍與方法已透過稽核確認，唯一需要留意的是遷移步驟需逐步驗證，不能一次性大改。
