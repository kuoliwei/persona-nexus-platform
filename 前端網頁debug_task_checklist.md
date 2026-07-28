# 前端網頁 Debug Task Checklist

# 🆕 交接說明（2026-07-27，新任務：稽核本輪 debug 是否違反四份設計文件）

> **這是目前最新、最優先要做的任務，請先讀這一段。** 下面從「一句話現況」開始的內容都是
> *前一輪工作*（8 個 bug 的調查、修復、測試）的完整記錄，本輪不用重做，是**查核材料**。

## 任務是什麼

檢查本文件記錄的 8 個 bug 修復（第 1～8 項），有沒有讓被動到的專案違反這四份文件的內容：

- `後端系統設計原則.md`
- `微服務架構準則.md`
- `微服務架構實作spec.md`
- `前端系統設計原則.md`

四份文件都在專案根目錄，跟本文件同一層。

## 這 8 個 bug 分別動到哪些專案（決定了要對照哪份文件）

| Bug | 動到的專案 | 性質 | 主要該對照的文件 |
|---|---|---|---|
| 1 | `persona-nexus-character` | 純前端 | 前端系統設計原則 |
| 2 | `persona-nexus-lobby` | 純前端 | 前端系統設計原則 |
| 3 | `persona-nexus-chat` | 純前端 | 前端系統設計原則 |
| **4** | **`ai-service`（後端）+ 兩支部署 bat** | **唯一牽涉後端／跨服務** | **後端系統設計原則 + 微服務架構準則 + 微服務架構實作spec** |
| 5 | `persona-nexus-chat` | 純前端 | 前端系統設計原則 |
| 6 | `persona-nexus-lobby` | 純前端 | 前端系統設計原則 |
| 7 | `persona-nexus-lobby` | 純前端 | 前端系統設計原則 |
| 8 | `persona-nexus-lobby` | 純前端 | 前端系統設計原則 |

**Bug 4 是唯一一個會牽涉到後端／微服務兩份文件的**，其餘 7 個都是前端專案內部的修復，只需要
對照《前端系統設計原則.md》。稽核時建議把 Bug 4 獨立出來仔細看，其餘 7 個可以一起過。

## 已經先幫忙看過、值得優先深入查的幾個疑點（不是結論，是起點）

這些是我讀過四份文件後，覺得「值得對照確認」的地方，**不是已經下的判斷**，新聊天室要自己去
兩邊對照原始碼與文件條文確認：

1. **Bug 4 的 `/health` 回應格式，可能不符合《微服務架構實作spec.md》第三部分的「錯誤回應
   格式」／「成功回應格式」**：spec 定義的成功格式是「單一資源直接回物件」或
   `{success, message}`，錯誤格式是 `{error, message}`；但 Bug 4 的 `/health` 回的是
   `{status: "ok"/"degraded", dependencies: {...}}` 這種第三種形狀。健康檢查算不算要遵守這個
   契約，還是可以自成一格，值得判斷。

2. **Bug 4 用到的 503 狀態碼，沒有出現在《微服務架構實作spec.md》「HTTP Status Code 統一
   定義」的表格裡**（表格只列了 200/400/401/403/404/409/500）。`/health` 回 503、
   `rag_controller._raise_for_error()` 也會判 503，這是否算違反「統一定義」，還是健康檢查
   這種非典型端點本來就不受這張表約束，值得確認。

3. **`rag_controller._raise_for_error()` 用關鍵字字串比對（"qdrant"/"connect"/"refused"）
   決定要回 500 還是 503**，這是一種隱性、脆弱的契約（依賴錯誤訊息的字面內容做判斷，不是
   明確定義的錯誤碼/欄位）。對照《後端系統設計原則.md》D 節「契約設計 Design by Contract」
   的「如何檢查違反：API 的錯誤碼...是否有明確且穩定的契約」，這點值得重點檢查。

4. **Bug 4 的 startup 不 crash（12-Factor IX Disposability）決策，本文件裡已經自己引用了
   這條原則**（見 Bug 4「已修復」區塊 D 項），可以直接對照《後端系統設計原則.md》C 節的
   12-Factor 表格核對這個引用/理由站不站得住腳，不用重新從零分析。

5. **Bug 7 的修法選擇「幫 `<div tabindex="0">` 補 `keydown` 監聽器」，而不是「改用原生
   `<button>`」**。本文件裡已經寫了為什麼不選後者（怕污染既有 CSS）。但《前端系統設計
   原則.md》B 節「最低能力原則」明講「如何檢查違反：是否用 JS 重新實作了瀏覽器原生就有的
   能力」——這正是這個情境。值得判斷本文件給的理由（CSS 風險）是否足以蓋過這條原則，或者
   只是圖方便沒有真的評估過。

6. **Bug 2 的修法明確承認沒有做「根本修法」**（body 級 UI 元素統一在路由切換時清理），
   只做了「補齊已知路徑」。`message-utils.js` 的同型問題本文件自己就承認仍然存在（見文末
   「調查／修復中順帶發現」第 2 項）。這是否構成 SoC／模組邊界原則上的「治標不治本」，
   值得在稽核報告裡明確點出，不要因為本文件自己承認了就跳過不提。

7. **本文件多處引用「SOP 貫穿原則 #6」（可觀察行為改動要先反映在 spec 再改碼）**——這條原則
   **不在**這四份要稽核的文件裡，是另一份不同的 SOP 文件。稽核時如果要引用它，請先確認它
   出處為何、跟這四份文件是什麼關係，不要混為一談。

## 做法建議

- 8 個 bug 的完整修復內容都在下方「Bug 1」～「Bug 8」各自的「✅ 已修復」區塊，含改了什麼、
  為什麼這樣改、當時的理由。**先讀這些，不用重新去讀一次原始碼的 diff**（除非要驗證本文件
  記載是否仍與現狀相符——四個前端與 ai-service 都是獨立 git repo，可以用 `git log`/`git show`
  對照）。
- 建議稽核報告的格式：依《前端系統設計原則.md》《後端系統設計原則.md》《微服務架構準則.md》
  《微服務架構實作spec.md》四份文件分類，每一條被觸及的原則列「符合／不符合／有疑慮」，
  並附上是哪個 bug、哪個檔案、哪一行。
- **這是一份純稽核任務，不是要重新修 bug**——8 個 bug 都已經修完、測完（見下方「一句話
  現況」與《前端網頁手動測試task.md》第九階段）。如果稽核發現真的違反了原則，先回報給
  使用者決定要不要修，不要自己動手改。
- 環境現況：現場資料庫裡還留著這幾輪測試建立的測試帳號/角色/對話資料，dev server 上次可能
  還在跑（見對話記錄，本文件未記載啟動細節）；本次稽核是讀文件+讀程式碼的靜態工作，
  不需要啟動任何服務。

## ✅ 稽核結果（2026-07-28）：有違反嫌疑的代辦事項

> 稽核已完成，逐條對照四份文件、並實際讀原始碼驗證（非只讀 checklist 本身的敘述）。
> 以下只列「有違反嫌疑」的項目，列為代辦，**修不修由使用者決定，本輪未動手改**。
> 沒有問題的原則（如 KISS/DRY/YAGNI/SSOT、WCAG、一致性與標準等，多數在本輪修復後已符合）
> 不重複列出，稽核結論見對話記錄；這裡只放需要決策的部分。

### 待勾選清單

- [x] 代辦 A：`message-utils.js` body 級單例殘留，未隨 SPA 路由清除（lobby，前端）
      → **已完成 2026-07-28（含瀏覽器實測 24/24 通過）**：change `lobby-shell-message-box`
      （`persona-nexus-lobby/openspec/changes/lobby-shell-message-box/`）。
      作法：`index.html` 靜態宣告外殼插座 `#shell-message-box`（`position: fixed`、
      `z-index: 1200`、直屬 `<body>`），`message-utils.js` 新增 `showShellMessage()`，
      側邊欄改用外殼插座；`getMessageBox()` **移除 `document.body.appendChild()`**，
      找不到子頁插座時降級用外殼插座 + `console.warn`。
      `npm run build` 與 `openspec validate --all` 皆通過。
      **實測（Playwright 無頭 Chromium，經 Caddy 8080）24 項全過**，其中呼叫點 #1
      （側邊欄刪除失敗，此前從未實測觸發過）確認：外殼訊息浮於畫面上方、
      `document.body` 下**沒有**動態建立的 `#message-box`、全文件無重複 id、
      聊天室 iframe 的 `y`/`height` 在訊息出現前後完全不變（未被擠壓）、
      3 秒後自動隱藏、換頁後無殘留；手機版抽屜開啟時 `elementFromPoint` 命中訊息框本身
      （z-index 1200 > 1100 驗證通過）。
      ⚠️ 非真人肉身測試——無人類肉眼判斷、無真實螢幕報讀器。
- [x] 代辦 B：`conversation-history.js:34` 缺 `autoHideMs`，與 `home.js` 不一致（lobby，前端）
      → **已隨代辦 A 同批完成並實測**。
      ⚠️ 原文寫 `conversation-history.js:33` 有誤，實際為**第 34 行**（33 行是 `console.error`）。
      **注意 B 只能治標**——補 `autoHideMs` 僅讓訊息自動隱藏（`display:none`），
      DOM 節點仍留在 body，A 的結構問題不因此解決，故兩者分別處理。
      待決兩項的結論：**秒數統一為 3000**（`main.js` 的 4000 改為 3000）；
      `my-character.js:42`「載入失敗」**維持不自動隱藏**並補上註解說明理由。
      規則不是「一律 3 秒」，而是依訊息性質分兩類——
      **一次性動作回饋**（訊息消失後畫面仍完整可用）3000ms 自動隱藏；
      **狀態說明**（訊息在解釋一個持續存在的畫面狀態，消失後畫面會失去意義）不自動隱藏。
      `my-character.js` 兩句訊息皆屬後者，因此不是規則的例外，而是規則的另一半。
- [x] 代辦 C：Bug 7 補 `keydown` 而非改用原生 `<button>`（有正當理由，僅建議補寫進 spec/CLAUDE.md）
      → **已完成 2026-07-28**：決策與 CSS 證據寫入 `persona-nexus-lobby/openspec/specs/lobby-ui/spec.md`
      的〈共用選單定位工具〉需求，新增 Scenario「選單項目的鍵盤啟動」＋實作決策說明。
      `openspec validate --all` 2/2 通過。
- [x] 代辦 D：`rag_controller._raise_for_error()` 用字串關鍵字判斷 500/503（ai-service，後端）
      → **已完成 2026-07-28**：change `typed-qdrant-errors` 實作完畢。
      新增 `src/exceptions.py`（`QdrantUnavailableError`／`OllamaUnavailableError`）與
      `src/http_errors.py`（共用 `raise_for_error()`），改依**例外型別**判斷 503/500，
      移除 `_CONNECTION_ERROR_KEYWORDS` 與 `vector_store` docstring 中的隱性契約。
      **實測推翻了原本的假設**：中文語系 Windows 上連線被拒的訊息是
      `[WinError 10061] 無法連線，因為目標電腦拒絕連線。`，不含 `qdrant`/`connect`/`refused`
      任一關鍵字——原本以為「矇對 503」，實際是**漏判成 500**。本輪等於修好一個既有缺陷。
      **範圍依使用者裁示擴充**：Ollama 不可用也型別化為 503，且 `chat_controller` 的
      `/generate`／`/summary` 一併接上（原本不論任何錯誤一律 500）。
      另修好 `ensure_collection` 經 `create_collection()` bool 中介吞掉原始例外的問題，
      並補上併發補建的冪等處理。實測 12 項情境全通過（含 Qdrant 停止/恢復、Ollama 不可用、
      模型不存在回 500、400 驗證未被吃掉）。`openspec validate --all` 5/5 通過。
- [x] 代辦 E：`rag_repository` 三處繞過 `vector_store` 封裝（ai-service，後端）
      → **已完成 2026-07-28**：change `encapsulate-vector-store` 實作完畢。
      `vector_store` 新增 `delete_by_filter()`／`scroll_points()`（參數為純字典），
      7 處 `.client` 呼叫全部收斂，`rag_repository` 已不 import `qdrant_client` 任何型別，
      4 處補丁式 `ensure_collection()` 移除（ensure 責任收進 `vector_store` 方法內部）。
      ⚠️ 實地清點為 **4 個方法、7 個 `.client` 操作**（稽核記載的「三處」低估，多出
      `get_conversation_data`；proposal 記為 8 處是把一個 ensure 也計入，範圍相同）。
      最高風險項（`replace_protagonist_background` 的兩條件刪除）已實測驗證：
      更新主角背景後**角色背景與角色性格完全未受影響**。
      collection 缺失的 Bug 4 迴歸驗證改用「另起空 Qdrant 容器」的非破壞性作法——
      正式 Qdrant 的 volume 內有使用者真實資料（114/46/12 筆），不可 `docker rm`。
      接手用的前情提要：平台根目錄 `前情提要-ai-service架構修正.md`
- [x] 代辦 F：《微服務架構實作spec.md》狀態碼表缺 503（文件補充）→ **已完成 2026-07-28**
- [x] 代辦 G：`/health` 回應格式疑慮，建議 spec 補一句豁免（文件補充）→ **已完成 2026-07-28**
- [x] 代辦 H：`chat_service`／`app.py` 不讀 `config.ollama.url`（ai-service，後端）
      → **已完成 2026-07-28**：change `config-driven-ollama-host` 實作並實測完畢。
      新增 `src/llm_client.py`（`ollama.Client(host=config.OLLAMA_URL)` 模組級單例），
      `app.py` 預載與 `chat_service` 的 `generate_response`／`generate_summary` 三處
      全部改走它；三處函式內的 `import ollama` 移除，全服務僅 `llm_client.py` 保留該匯入。
      既有的 `except ConnectionError → OllamaUnavailableError` 包裝**一行未改**（如預期）。
      **核心驗證通過**：`ollama.url` 改為 `http://localhost:19999` 重啟後，
      `POST /api/v1/chat/summary` 回 **503**（變更前回 200），`/health` 的 `ollama_url`
      顯示同一位址；反向測試設 `OLLAMA_HOST=19999` 但 config 正確時仍回 **200**
      （環境變數已被忽略）；還原後 `/generate`／`/summary` 皆 200、RAG `/context` 正常、
      預載日誌 `✅ 模型預載完成（2.5s）`。
      ⚠️ **一個執行中的發現**：`/generate` 的 503 **不足以單獨證明本輪修正**——它會先做
      RAG 檢索，由 `embedder`（本來就走 config）先拋錯。真正的證據是**不經 RAG 的
      `/summary`**，以及預載日誌如實跟隨 config 失敗。已寫入 tasks 4.2.A 與 `test.http` H-1。
      另實測補上一項原文件缺的事實：`ollama.Client(host=...)` **建構時不發起網路連線**，
      故模組層級單例＋檔案頂部匯入不會讓「Ollama 未啟動」變成服務起不來的原因
      （已寫成 spec scenario〈共用 client 的建立不成為啟動期依賴〉並實測：位址不可達時
      服務 1 秒內開埠、`/health` 回 200）。
      `config.json` 測試前備份、測後以檔案複製還原，SHA256 與測試前完全相同。
      `openspec validate --all` 6/6 通過；delta 已同步回主 spec（本專案不用 `archive`）。
      **不是稽核發現，是執行代辦 D 的手動測試時撞到的**：把 `config.json` 的 `ollama.url`
      指向不存在的埠後，`POST /api/v1/chat/summary` 仍回 200——因為 `chat_service` 用的是
      `ollama` 套件的**模組層級預設 client**（讀 `OLLAMA_HOST` 環境變數），不讀 config。
      四個 Ollama 呼叫點中**只有 `embedder.py` 真的用 config 的值**；
      `app.py:69` 預載、`chat_service.py:164/223` 生成與摘要都繞過。
      **實害**：`/health` 與 `/rag/status` 都把 `config.OLLAMA_URL` 當權威值回報，
      換 Ollama 位址時會出現「回報新位址、實際連 localhost」——監控說謊、排查被誤導。
      而 `config.py:19` 用 `_require("ollama.url")` **強制**此鍵存在（缺鍵服務起不來），
      證明這是實作缺陷而非設計取捨。
      **修法**（已查證 `ollama` 0.6.2）：新增 `src/llm_client.py` 建立
      `ollama.Client(host=config.OLLAMA_URL)` 單例，3 個呼叫點改用它。
      連線失敗仍拋內建 `ConnectionError`，故代辦 D 建立的 503 包裝**不需修改**。
      ⚠️ **刻意不接 `OLLAMA_TIMEOUT`**：套件預設「永不逾時」，改 300 秒會中斷長生成
      （本機跑 `gemma-26b`），屬獨立的可靠性決策。
      前置查證已完成：全平台無任何**生效中**的設定依賴 `OLLAMA_HOST`
      （僅 `deploy/docker-compose.yml` 內的註解與 openspec 說明文字），前提成立。
      接手用的前情提要：平台根目錄 `前情提要-ollama連結來源修正.md`

### 🆕 執行代辦 A/B 時撞到的新問題

**刪除失敗訊息的前綴重複＋裸露狀態碼** —— ✅ **已修（2026-07-28）**
實測畫面上顯示的是「**刪除失敗: 刪除失敗: 500**」，成因是兩層各自加了一次前綴：
`persona-nexus-lobby/src/api.js` `throw new Error(\`刪除失敗: ${response.status}\`)`，
而 `src/conversation-history.js` 又寫 `\`刪除失敗: ${error.message}\``。
**使用者表示此問題此前已遇過、當時決定先不處理。**

**修法**（先寫進 delta spec 的〈錯誤訊息的層級責任〉需求再改碼）：
`conversation-history.js` 呼叫 `api.js`，故**前者是最外層、後者是內層**。
消除重複要**移除內層的動作名稱**而非外層的——外層才最接近使用者、知道使用者剛才在做什麼；
斷網時 `error.message` 是瀏覽器產生的 `Failed to fetch`，最前面的「刪除失敗」
是使用者唯一能得知是哪個動作出事的線索。
因此 `conversation-history.js` 維持「刪除失敗: 」，`api.js` 的 `deleteConversation()`
改與同檔的 `listMyCharacters()` 統一為 `error.message || \`HTTP ${response.status}\``
（優先用後端回傳的原因，取不到才退回帶 `HTTP` 前綴的狀態碼，原本的裸露 `500` 一併解決）。
實測：後端有回原因 → `刪除失敗: forced failure`；body 非 JSON → `刪除失敗: HTTP 500`。

> ⚠️ **過程記錄**：本輪一度把層級判斷寫反（誤以為該移除外層的動作名稱，
> 產出「error message: 刪除失敗: 500」），由使用者指出後更正。

---

### 代辦 A：`message-utils.js` body 級單例殘留，未隨 SPA 路由清除（Bug 2 遺留）
- **違反**：《前端系統設計原則》B 節「關注點分離 / 模組邊界」——body 級 UI 元素的生命週期
  沒有跟著 SPA 路由走，這正是 Bug 2 修復前 tooltip 犯的同一種錯誤。
- **證據**：`persona-nexus-lobby/src/message-utils.js` 的 `getMessageBox()`，在 `chat.html`／
  `character-edit.html`（不自帶 `#message-box` 的頁面）會 `document.body.appendChild()`
  出一個 body 級單例，且全檔沒有任何 `remove()`，只靠 `display:none` 隱藏（Bug 2 證據 5）。
  具體可觸發路徑：`persona-nexus-lobby/src/conversation-history.js:33` 的
  `showMessage('error', \`刪除失敗: ...\`)` 沒傳 `autoHideMs`，若在聊天室頁側邊欄刪除對話失敗，
  會留下一個不會自動隱藏、也不會在切頁時被清掉的錯誤訊息框。
- **狀態**：checklist 本身已承認「未處理、留作已知限制」，依先前回饋（不能因為文件自己
  承認了就跳過不提），這裡正式列為代辦，不只是註記。

#### 🔍 代辦 A 補充調查（2026-07-28，修法討論前的實地查證）

> 本節為修法討論時實地重讀原始碼的結果。**有兩點修正了上方稽核記載的細節**，
> 修法拍板前務必以本節為準。以下每一條都附可覆核的檔案與行號，無推測成分。

**查證 1｜全專案共 5 個 `showMessage()`／`clearMessage()` 呼叫點（上方稽核只提到 2 個）**

`grep -rn "showMessage\|clearMessage" src/ --include=*.js` 的完整結果：

| # | 呼叫點 | 執行當下所在頁面 | 抓到哪個 `#message-box` | 有無 `autoHideMs` |
|---|--------|-----------------|------------------------|------------------|
| 1 | `conversation-history.js:34`（刪除對話失敗） | **任何頁面**（側邊欄貫穿全站） | 視當下頁面而定，見查證 3 | ❌ 無 |
| 2 | `home.js:81`（無法獲取角色列表） | 首頁 | `home.html:8` 自帶 | ✅ 3000 |
| 3 | `main.js:86`（缺角色 ID） | 首頁（**刻意**先 `loadHomePage()` 才顯示） | `home.html:8` 自帶 | ✅ 4000 |
| 4 | `my-character.js:34`（載入角色清單中…） | 我的角色頁 | `my-character.html:8` 自帶 | ❌ 無（但由 #5 的 `clearMessage()` 收掉） |
| 5 | `my-character.js:39/42`（清除／載入失敗） | 我的角色頁 | `my-character.html:8` 自帶 | ❌ 無（`:42` 失敗訊息持續顯示，屬該頁常駐錯誤狀態） |

> ⚠️ **行號更正**：上方稽核原文寫的 `conversation-history.js:33` 實際為**第 34 行**
> （第 33 行是 `console.error`）。本節一律以實測行號為準。

**查證 2｜`chat.html`／`character-edit.html` 這兩個子頁「自己」不會呼叫 `showMessage()`——
上方稽核記載的觸發前提不成立**

`chat-page.js` 與 `character-edit.js` 兩支載入器全檔讀過，**都沒有 import
`message-utils.js`、也沒有任何 `showMessage()` 呼叫**；兩者只做三件事：抓 html 樣板塞進
`#content-area`、呼叫 `loadIframeWithToken()` 掛 iframe、推 history 狀態。
`public/src/chat.html` 與 `character-edit.html` 兩個樣板本身也只有一個包 iframe 的 `<div>`
（各 5 行），頁面內容其實是**另外兩個獨立的前端 app**（`/chat`、`/character`），
它們有各自的訊息機制，與 lobby 的 `message-utils.js` 無關。

→ 因此「幫這兩個子頁補 `<div id="message-box">` 插座」**無法解決代辦 A**：
這兩頁根本沒有自己的訊息要顯示，補了插座也不會有人用它。

**查證 3｜唯一真正會誤貼 body 的路徑，是側邊欄的 `conversation-history.js:34`**

`index.html`（SPA 外殼）本身**沒有** `#message-box`（`grep -c` 結果為 0），
`public/src/sidebar.html` 也**沒有**（同樣為 0）。外殼結構為：

```
<body>
  ├── #sidebar-container   ← 側邊欄，殼的一部分，換頁不會被清掉
  └── .main-content > #content-area   ← 換頁時只有這裡的內容被 innerHTML 換掉
```

側邊欄（含刪除對話按鈕）貫穿全站都在，所以 `conversation-history.js:34` 可能在任何頁面觸發：

- 在**首頁／我的角色頁**觸發 → `getMessageBox()` 找到子頁自帶的插座 → 插進 `#content-area`
  裡，換頁時會被一起清掉。**但因為沒傳 `autoHideMs`，切頁前會一直顯示**（代辦 B）。
- 在**聊天室頁／角色編輯頁**觸發 → 找不到插座 → `document.body.appendChild()` 建 body 級
  單例 → **換頁不會被清掉，且沒有 `autoHideMs`，會永久殘留**（代辦 A 的實際觸發路徑）。

**查證 4｜Bug 6 的修復已經意識到這個陷阱並刻意迴避，但只解決了它自己那一處**

`main.js:83-85` 有一段既有註解，直接寫明了這個 body 誤貼問題：

```js
// 已知路徑但缺少必要的 id 參數：不要靜默轉向，顯示訊息後再回首頁
// （在 loadHomePage() 之後才顯示，這樣抓到的是 home.html 自帶的
// #message-box，不會在 body 上留下第二個重複 id 的訊息框）
await loadHomePage();
history.replaceState({ page: 'home' }, '', '/');
showMessage('error', '❌ 缺少角色 ID，請從「我的角色」清單進入編輯頁。', 4000);
```

→ 證明這個陷阱**在 Bug 6 修復時就已被發現**，當時採取的是「調整呼叫順序來閃避」的
局部解法，沒有從 `message-utils.js` 本身根治，也沒有記進 checklist。
這佐證了代辦 A 是**結構問題**而非單一疏漏：每個呼叫點都得自己記得閃避，才不會踩到。

**查證 5｜`#message-box` 是常態排版元素，不是浮動提示**

`style.css:295-316`：只有 `margin-bottom`／`padding`／`border-radius`／`font-size`／
`text-align`／`display`，**沒有 `position: fixed`／`absolute`、沒有 `z-index`**。
代表它會占用所在位置的版面空間、跟著內容排版走，不是浮在畫面上的 toast。
→ 這也是為什麼它「掛到 body 最下方」時，視覺上會出現在頁面底部而非疊在畫面中央；
與 Bug 2 的 tooltip（`position: fixed` + `z-index: 1000`，會蓋在畫面最上層）性質不同，
**殘留的視覺表現不如 tooltip 明顯，但生命週期問題是同一型**。

#### 💡 代辦 A／B 的修法方向（依上方查證重新評估，未動手）

- **代辦 B 是獨立的單行修法**：`conversation-history.js:34` 補上 `autoHideMs`，
  與 `home.js:81` 的 3000 對齊即可。這條無論代辦 A 怎麼修都該做，且能**大幅降低**
  代辦 A 的實際傷害（訊息會自動隱藏，不再永久殘留在畫面上）——但注意這只是讓它
  「看不見」，DOM 節點仍留在 body，結構問題還在。
- **代辦 A 的修法選項**（尚未拍板）：
  1. **側邊欄自帶插座**：在 `index.html` 外殼或 `sidebar.html` 補一個屬於殼層級的
     訊息框容器，讓側邊欄的訊息有正當歸屬。需要處理與子頁自帶 `#message-box` 的
     **id 重複**問題（`getMessageBox()` 用 `getElementById`，會抓到 DOM 中的第一個）。
  2. **`message-utils.js` 內建清理**：改為每次顯示時先 `remove()` 舊節點，
     或提供 `removeMessageBox()` 供路由切換時呼叫。但 lobby 目前**沒有集中的切頁收口**
     （`main.js:55-92` 的 `restoreRouteFromUrl()` 只管初次載入，之後各頁各自
     `import` + `pushState`），與 Bug 2 當初評估「根本修法成本高」的結論一致。
  3. **維持現狀 + 只修代辦 B**：接受 body 級節點存在，靠 `autoHideMs` 讓它不可見。
     成本最低，但《前端系統設計原則》B 節的違反仍在。
- **已排除的修法**：「幫 `chat.html`／`character-edit.html` 補插座」——查證 2 已證明
  這兩頁不會呼叫 `showMessage()`，補了也沒有作用。

### 代辦 B：`conversation-history.js:33` 的錯誤訊息缺 `autoHideMs`，與 `home.js` 不一致
- **違反**：《前端系統設計原則》D 節「一致性與標準」——同一組件（錯誤訊息框）在不同呼叫點
  的行為不一致：`persona-nexus-lobby/src/home.js:81` 有傳 `autoHideMs=3000`（3 秒自動隱藏），
  `conversation-history.js:33` 沒有傳（永久停留，需搭配代辦 A 的 body 級殘留問題一併看）。
- **證據**：`persona-nexus-lobby/src/home.js:81` vs `persona-nexus-lobby/src/conversation-history.js:33`
  兩處呼叫 `showMessage()` 的參數不同，非刻意設計差異，只是遺漏。

### 代辦 C（有正當理由的例外，供覆核）：Bug 7 補 `keydown` 而非改用原生 `<button>`
- **違反（字面上）**：《前端系統設計原則》B 節「最低能力原則」——「是否用 JS 重新實作了
  瀏覽器原生就有的能力」，`persona-nexus-lobby/src/my-character.js:60-77` 與
  `src/conversation-history.js:18-33` 幫 `<div tabindex="0">` 補 `keydown` 監聽器，正是這個情境。
- **證據（已查證，理由成立）**：`persona-nexus-lobby/src/style.css:279-293` 確實有全域
  `button {}` 規則（`background-color: #238636`、`border`、`padding: 12px 24px`、
  `font-weight: bold`），而 `.conversation-menu-item`（`style.css:215-234`）只覆蓋
  `padding`/`color`/`font-size`/`cursor`/`transition`，**沒有覆蓋
  `background-color`/`border`/`font-weight`**——若改用原生 `<button>` 會被全域樣式污染，
  需要額外補一批 CSS override。這個 CSS 風險是真的，不是藉口。
- **建議**：不需要重修，但建議把「為什麼選 keydown 不選 button」與這段 CSS 證據一併寫進
  `persona-nexus-lobby` 的 `openspec/specs/lobby-ui/spec.md` 或 `CLAUDE.md`，作為日後稽核
  不必重查一次的紀錄。

### 代辦 D：`rag_controller._raise_for_error()` 用關鍵字字串比對決定 500／503（Bug 4 加深依賴）
- **違反**：《後端系統設計原則》D 節「契約設計 Design by Contract」——「API 的錯誤碼...是否有
  明確且穩定的契約」。`ai-service/src/controllers/rag_controller.py:12-20` 的
  `_raise_for_error()` 用 `("qdrant", "connect", "refused")` 關鍵字比對錯誤訊息字面內容來決定
  回 500 還是 503，是隱性、脆弱的契約。
- **背景**：這個機制是 2026-07-25 `simplify-ai-service` 這輪引入的既有問題，**不是 Bug 4
  新增的**。但 Bug 4 的修復沒有藉機修正它，反而加深依賴：
  `ai-service/src/rag/vector_store.py:88-95` 的 `ensure_collection()` 例外訊息刻意寫成含
  `"Qdrant"` 字樣（原始碼註解自己承認：「訊息刻意含 'Qdrant' 字樣，讓
  `rag_controller._raise_for_error()` 的關鍵字查表判為連線類錯誤回 503」），現在多了一處
  狀態碼判斷依賴錯誤訊息字面內容。
- **建議修法方向**：改用明確的例外型別（如 `QdrantUnavailableError` vs 其他 `Exception`）或
  顯式錯誤碼欄位，取代字串關鍵字比對。

### 代辦 E：`rag_repository` 三處繞過 `vector_store` 封裝、直接操作 `vector_store.client`
- **違反**：《後端系統設計原則》B 節「資訊隱藏」——呼叫方（`rag_repository`）依賴被呼叫方
  （`vector_store`）的內部實作細節（直接拿 `.client` 這個 Qdrant SDK 物件），而非透過
  `vector_store` 自己的封裝方法。
- **證據**：`ai-service/src/repositories/rag_repository.py` 的 `replace_protagonist_background()`／
  `get_latest_summary()`／`delete_conversation_data()` 三個方法直接用
  `vector_store.client` 操作（Bug 4「已修復」區塊自己列出這三處）。
- **背景**：同樣是既有問題、非 Bug 4 引入。但 Bug 4 的修法是在這三處各自加一次
  `ensure_collection()` 呼叫讓它們不撞 404，而不是把這三處收斂回 `vector_store` 的封裝方法。
  功能上正確（已有測試驗證），但等於在既有的資訊隱藏違反上繼續施工，沒有趁機收斂。

### 代辦 F：《微服務架構實作spec.md》的「HTTP Status Code 統一定義」表格缺 503
- **違反**：《微服務架構實作spec.md》第三部分「HTTP Status Code 統一定義」表格（原文件
  152-162 行）只列 200/400/401/403/404/409/500，沒有 503。
- **證據**：503 早已是平台既有、比 Bug 4 更早的使用模式——
  `chat-service/src/controllers/conversationController.js` 多處回 503（RAG 清理失敗、AI 服務
  不可用等，第 45/57/232/261/314/350 行附近）。Bug 4 的 `/health`
  （`ai-service/app.py:106-107`）是再多加一個 503 使用點，沒有藉這次修復把 503 補進這份
  平台層 spec 的表格。
- **建議**：把 503 加進 `微服務架構實作spec.md` 的狀態碼表格，並註明使用時機（依賴的下游
  服務不可用），讓文件與現行程式碼同步。

### 代辦 G（有疑慮，非明確違反）：`/health` 回應格式不是 spec 定義的任何一種形狀
- **疑慮**：《微服務架構實作spec.md》第三部分（原文件 183-208 行）只定義了「單一資源物件」
  「陣列」「`{success,message}`」「`{error,message}`」四種回應形狀，
  `ai-service/app.py:106-114` 的 `/health` 回應
  `{status, service, ollama_url, model, dependencies}` 都不吻合，是第三種未定義形狀。
- **背景**：這是刻意的設計選擇——`app.py:95-96` 的註解說明用 `JSONResponse` 而非
  `HTTPException`，理由是「健康檢查回報的是狀態不是錯誤，不該被全域 handler 轉成
  `{error, message}` 而丟失結構」。理由合理，但 spec 文件本身沒有明文豁免健康檢查端點。
- **建議**：若要讓這個例外站得住腳，建議在 spec 裡補一句「健康檢查端點的回應格式不受此節
  約束」，否則字面上仍不符合。

---

> 這份文件彙整《前端網頁手動測試task.md》全部 8 個階段（已於 2026-07-27 測完）實測過程中
> 發現的**真實 bug**，供之後集中排查/修復用。原始測試記錄（含通過的項目、完整現象描述、
> 根因分析）都保留在《前端網頁手動測試task.md》文末「發現的新問題」。
>
> 第 1～4 項來自第一輪測試（測到第五階段中途暫停時發現），已全部修復並驗證通過；
> 第 5～8 項來自接續完成第五～八階段時的第二輪測試，皆尚未修復。
>
> 2026-07-26 起，本文件已從「待辦摘要」擴充為**調查報告 + 修復記錄**，是這輪 debug 工作的
> 主文件。
>
> **修復時的共同提醒**：
> - 每項都先讀對應的原始碼確認現狀仍與下方描述一致（程式碼可能在這之間又變了）。
> - 修完之後要回頭在《前端網頁手動測試task.md》對應的測試項目重新實測一次，不是修完就結案。
> - 不要順便夾帶其他重構或優化，只修這裡列出的問題本身。

---

# 🔄 交接說明（2026-07-26，給接手的新聊天室）

> **先讀這一段，再往下看。** 前一個聊天室對話量到上限，以下是接手需要知道的全部狀態。

## 一句話現況

八個 bug（第 1～8 項）**全部已修復並完成瀏覽器測試**。第 1～4 項是**真人**瀏覽器實測驗證通過；
第 5～8 項（2026-07-27 接續完成第五～八階段測試時新發現）已於同日完成修復前根因重新核對
（見各項「🔍 修復前重新核對」區塊）、程式碼修復（見各項「✅ 已修復」區塊），並額外完成
**Playwright 自動化瀏覽器回歸測試**（無頭 Chromium 實際跑過整個流程，見《前端網頁手動測試
task.md》第九階段 9.1～9.4，四項全過）。

> ⚠️ **注意這兩者不完全等同**：Playwright 是真正的瀏覽器引擎在跑真正的前端程式碼，但**不是
> 真人肉身操作**——沒有人類視覺判斷、沒有真實螢幕報讀器。這輪測試已涵蓋畫面文字、Console
> 例外、DOM 狀態、鍵盤事件等可程式化驗證的部分；若使用者仍想針對可及性等主觀體感做一輪真人
> 複測，第九階段留的測項清單可以直接沿用。

詳見文末「第二輪：2026-07-27 手動測試新發現的問題」章節與下方進度總表。

## 進度總表

| Bug | 服務 | 狀態 | 已完成的驗證 | 還缺什麼 |
|---|---|---|---|---|
| **1** 跳轉雙斜線 | character | ✅ 已修 | URL 解析 5/5、語法檢查、grep 無殘留 | ✅ 真人實測（建立／更新／刪除三條） |
| **2** tooltip 殘留 | lobby | ✅ 已修 | 事件流程 8/8、`npm run build`、`openspec validate` | ✅ 真人實測（點卡片／瀏覽器上一頁兩條） |
| **3** 空陣列崩潰 | chat | ✅ 已修 | 4 條路徑 4/4、原重現腳本已失效、build 13 modules | ✅ 真人實測（聊天室建立逾時） |
| **4** Qdrant | ai-service + bat | ✅ 已修 | A/B/C/D 全做；實機驗證 11/11 + 10/10（含完整恢復情境） | ✅ 真人實測（走真實 uvicorn + 瀏覽器聊天） |
| **5** 重啟聊天室逾時未顯示 toast | chat | ✅ 已修 | 真人實測重現＋控制流程重現腳本＋build 13 modules＋Playwright 回歸測試 9.1 | 無（若要再補一輪真人肉身測試，由使用者決定） |
| **6** 編輯頁缺 id 靜默轉首頁 | lobby | ✅ 已修 | 真人實測重現＋build 19 modules＋openspec 2/2＋Playwright 回歸測試 9.2 | 無（同上） |
| **7** 「編輯」選單鍵盤按不動 | lobby | ✅ 已修（兩處） | 真人實測重現（編輯）＋keydown 邏輯重現腳本 2/2＋build 19 modules＋Playwright 回歸測試 9.3 | 無（同上，尤其可及性主觀體感建議真人複測） |
| **8** config 失敗後未捕捉例外 | lobby | ✅ 已修 | 真人實測重現＋控制流程重現腳本＋build 19 modules＋openspec 2/2＋Playwright 回歸測試 9.4 | 無（同上） |

**已改動但尚未 commit 的檔案**（四個前端與 ai-service 各自是獨立的巢狀 git repo）：
- `persona-nexus-character/src/create.js`、`src/edit.js`
- `persona-nexus-chat/src/virtualMessageList.js`
- `persona-nexus-lobby/src/character-tooltip.js`、`openspec/specs/lobby-ui/spec.md`
- `ai-service/app.py`、`src/rag/vector_store.py`、`src/repositories/rag_repository.py`、
  `src/services/rag_service.py`、`openspec/specs/ai-generation/spec.md`、`CLAUDE.md`
- 專案根目錄的 `start-all-services.bat`、`start-backend-services.bat` 與本文件

> ⚠️ 這幾個 repo 的工作區裡還有**上一輪前端優化（Phase 0–10）尚未 commit 的大量改動**
> （character 13 檔、chat 14 檔、lobby 19 檔），本輪 debug 只動了上面列的那幾個。
> 要 commit 時務必只挑本輪的檔案，不要整包 `git add .`。

## ✅ Bug 4 的兩個待決問題已拍板（2026-07-26）

**問題 1：A/B/C/D 怎麼走？** → 使用者選擇**四項全做**，startup 行為採 **D（維持不 crash）**。
（原文件寫的「待辦 3：不要吞掉 startup 失敗」方向是錯的，照做會違反 12-Factor IX
Disposability，讓 Qdrant 慢幾秒 ai-service 就整個起不來。）

| | 做什麼 | 解決什麼 | 狀態 |
|---|---|---|---|
| **C** | 啟動腳本拿掉 `--rm`（`start-all-services.bat` **與** `start-backend-services.bat` 兩支） | 證據 8 證明這正是「以前不會、現在會」的直接原因，等於回復到出問題前的狀態 | ✅ |
| **A** | collection 建立改成可在執行期補做的冪等 `ensure` | 讓「只重啟 Qdrant、不重啟 ai-service」真的能恢復 | ✅ |
| **B** | `/health` 接上已寫好卻零呼叫的 `check_connection()` | 讓壞掉的狀態看得見（並補上 `/health` 的規格） | ✅ |
| **D** | startup 維持不 crash | 保留 Disposability；因為有 A 與 B，吞例外不再是永久傷害 | ✅ |
| 順帶 | `rag_service.py` docstring 與實作落差 | 文末「順帶發現」第 3 項 | ✅ |

**問題 2：確認要動 `ai-service`（Python）與 `start-all-services.bat` 嗎？** → 確認要，
使用者指示「接受修 bug 4」，兩者都在範圍內。

## 這輪建立的工作約定（請延續）

1. **絕對不可以靠推測與猜測，一定要找到證據才能寫**（使用者明確要求）。查不到證據的
   一律標記「未證實」並寫明還缺什麼，不要升格成結論。這輪因此推翻了 3 項原本的錯誤描述。
2. **列出問題時不要自行做範圍分類去篩選或降權**。Bug 4 是後端問題，仍與其他三項平等調查、
   平等呈現；順帶發現的問題也全部列進「調查／修復中順帶發現」，由使用者決定取捨。
3. **修 bug 不可以違背設計原則與規格**。使用者特別確認過這點，已逐條比對
   《前端系統設計原則》《後端系統設計原則》《後端專案優化標準程序》與各服務 openspec，
   結論是四個 bug 都是**失誤**、不是原則的必然結果，且四項修法都**更**符合原則
   （詳見各 bug 的「已修復」區塊）。
4. **可觀察的行為改動要先反映在 spec 再改碼**（SOP 貫穿原則 #6）。Bug 2 就是先改
   `lobby-ui/spec.md` 才動 `character-tooltip.js`。
5. **驗證要用「跑起來」而不是「讀過了」**。特別注意：`persona-nexus-character` 的
   `npm run build` **不能當驗證**（見下方環境陷阱）。
6. **關鍵節點停下來跟使用者核對**，不擅自啟動服務、不擅自擴大範圍。

## 環境現況與陷阱（接手前務必知道）

**服務狀態（2026-07-26 交接當下）**：

```
8080  502（Caddy 容器還活著，但上游全掛）      5173/5174/5175/5176  down
8000  down（api-gateway）                      6001  down（ai-service）
6333  down（Qdrant）                           11434 up（Ollama）
docker: 只剩 nexus-caddy 在跑
```

要測試得先跑 `start-all-services.bat`（**必須先開 Docker Desktop**）。
前一個聊天室沒有擅自啟動這些服務。

**陷阱 1｜四個前端各有獨立的巢狀 git repo**
平台根目錄下 `git diff` 看不到前端的改動，必須 `git -C persona-nexus-<name> diff`。
這點害第一次查 Bug 1 時 `git diff` 查無結果、差點誤判。

**陷阱 2｜`persona-nexus-character` 的 `npm run build` 沒有驗證效力**
`vite.config.js` 沒設 `rollupOptions.input` 多頁入口，build 只涵蓋 `index.html`（7 modules），
**完全沒編譯到 `creator-create.html`／`creator-edit.html` 這兩個真正的主頁面**。
改 `create.js`／`edit.js` 後 build 通過**不代表任何事**。
（lobby 與 chat 的 build 則是完整的，可以用。）

**陷阱 3｜Qdrant 容器目前是 `--rm`**（bat 已於 2026-07-26 修好，但**舊容器不受影響**——
機器上若還跑著先前用 `--rm` 起的容器，下面這段仍然成立。先 `docker rm -f qdrant`
再跑一次 `start-all-services.bat` 才會換成新設定，`qdrant_storage` 資料卷不受影響。）
不要從 Docker Desktop 的 Containers 頁關掉它——`--rm` 會讓它直接消失，
而從 Images 頁按 ▶ 重開會得到一個**沒有 port 對應、沒有資料卷**的全新容器，
這正是 Bug 4 的成因。容器不見了就重跑 `start-all-services.bat`，
或手動下完整指令（`-v qdrant_storage:/qdrant/storage` 絕不能漏）。

## 驗證腳本放在哪

三份驗證腳本寫在前一個聊天室的 scratchpad，**已隨對話結束失效**，需要時請照下列說明重寫
（都不需要啟動任何服務，秒級可跑）：

- **Bug 1**：讀 `create.js`／`edit.js` 原始碼，正則抽出常數定義與所有
  `location.href = ...` 的運算式，用 `new URL(literal, base)` 解析，
  斷言結果為 `http://localhost:8080/my-characters`／`/login/`，並斷言運算式中不含
  `` ` `` 或 `+`（確保沒有拼接）。
- **Bug 2／3**：用最小 DOM stub（`globalThis.document = { createElement: ... }` 之類）
  在 Node 裡直接 `import` 真實模組來跑，不需要 jsdom、不需要 Vite。
  Bug 2 要模擬 `mouseenter` → `click`／`popstate` 的事件流程；
  Bug 3 要跑「空陣列建立」「非空建立」「刪光後 sync」「空↔非空來回」四條路徑。

詳細做法見文末〈調查方法備註〉。

## 建議的閱讀順序

1. **本文件**（就是這份）——四個 bug 的完整調查報告、證據、修復記錄。最重要。
2. 《前端網頁手動測試task.md》——測試主文件，第一～四階段完整記錄、第五階段測到 5.6 中斷。
   ⚠️ 文末「發現的新問題」**仍是舊版說法**，三項錯誤描述尚未同步回去（見「完成後的收尾動作」）。
3. 《前情提要-前端瀏覽器測試.md》——更早的背景脈絡。
4. 需要判斷「修法會不會違背原則」時才讀：《前端系統設計原則》《後端系統設計原則》
   《後端專案優化標準程序》＋ 對應服務的 `openspec/specs/*/spec.md`。

## 全部修完之後要做什麼

使用者的計畫是**四個 bug 全修完再一起做真人瀏覽器測試**。屆時：

1. 開 Docker Desktop → 跑 `start-all-services.bat` → 確認 8080 起得來。
2. 依各 bug 的「待辦 3」逐條實測（每個 bug 的待辦 3 都寫了具體要走哪幾條路徑）。
3. 接著回《前端網頁手動測試task.md》繼續第五階段剩餘的 5.6/5.7，再往第六～八階段走。
4. 收尾動作見本文件最後一節。

---

## 調查報告總覽（2026-07-26 補充）

四個 bug 已逐一追查到根因，每一項的結論都附可覆核的證據（原始碼行號、`git diff`、可執行的
重現腳本、實機實驗）。**凡是查不到證據的推測，一律標記為「未證實」並寫明還缺什麼**，沒有把
猜測寫成結論。

調查後有 **三項原本的描述被證據推翻或需要修正**，修復前務必先看：

| # | 原描述 | 調查結果 |
|---|--------|----------|
| 1 | 只有 `create.js:56` 一處，`edit.js`「可能」也有 | **實際有 3 處**（`create.js:56`、`edit.js:78`、`edit.js:101`），另有第 4 處相關但性質不同的 `edit.js:37`。已用 URL 解析器實測確認 |
| 3 | 例外「蓋掉」了原本該顯示的「建立失敗」錯誤訊息 | **不成立**。錯誤文字在 `chat.js:203` 已先設定完成，例外發生在其後的 `chat.js:632`，覆蓋層文字實際上有顯示。真正的後果是另外三項（見 Bug 3） |
| 4 | 根因是 `qdrant-client`／`httpx` 連線池快取了失效連線 | **已用實機實驗推翻**。同一個 client 物件在 Qdrant 回來後會自動恢復。真正的根因是另外三件事（見 Bug 4） |
| 4 | 隱含假設「是本輪（前端）優化造成的」 | **部分否定、部分證實**。ai-service 的三項根因可追到 2026-06-26 與 2026-07-03，早於各輪優化（證據 7）；但**觸發條件（Qdrant 容器的 `--rm`）確實是「佈署優化」`4d1a704`（2026-07-23）引入的**（證據 8）。與**前端**優化無關 |

**四個 bug 的嚴重度重新評估**：Bug 1 是唯一會 100% 讓使用者卡在打不開的錯誤頁的功能性故障，
應優先修。Bug 3 的實際使用者可見影響比原本記載的小。Bug 4 不是連線韌性問題，而是啟動順序 +
吞例外 + 健康檢查失真三者疊加。

> 說明：Bug 4 位於 `ai-service`（後端）。依先前的回饋，這裡不做「是不是前端範圍」的自行篩選或
> 降權，一律與其他三項平等調查、平等呈現，範圍與優先順序的取捨留給使用者決定。

---

## Bug 1：建立角色成功後，自動跳轉壞掉（雙斜線 URL 導致解析成錯誤網域）

> ### ✅ 已修復（2026-07-26，採 B 方案：完整路徑常數）
>
> **改動**：`src/create.js` 與 `src/edit.js` 移除 `LOGIN_APP_URL`／`LOBBY_APP_URL` 兩個
> 前綴常數，改為兩個完整路徑常數，**所有呼叫點不再做任何字串拼接**：
>
> ```js
> const LOGIN_URL = '/login/';                 // persona-nexus-auth
> const MY_CHARACTERS_URL = '/my-characters';  // persona-nexus-lobby 的「我的角色」頁
>
> window.location.href = LOGIN_URL;
> window.parent.location.href = MY_CHARACTERS_URL;
> ```
>
> 一次修掉 4 個點：`create.js:56`、`edit.js:78`、`edit.js:101`（雙斜線）與
> `edit.js:37`（`/login//`）。不拼接，這類 bug 結構上不可能再發生。
>
> **為什麼是 B 方案而不是把常數改成 `''`**：lobby 掛在網站根目錄，前綴本來就是空的，
> 「值等於空字串的前綴常數」不帶任何資訊，還把拼接陷阱留給下一個人。
> 符合 KISS、最低能力原則（能用普通常數就不用樣板字串插值）與 DRY／SSOT。
> lobby 的 `CHARACTER_APP_URL = '/character'` 等前綴常數維持不變——那些是**真前綴**且
> 底下掛多條路徑，適用前綴常數；規則一致，只是情況不同。
>
> **不需要改規格**：`character-ui/spec.md:84, 117, 149` 只規定可觀察行為「導向
> `/my-characters`」，未提及常數名稱或值，故本次屬純實作細節調整，不觸發 SOP
> 貫穿原則 #6「行為變更要顯性」。（另注意：那三行規格分別對應建立／更新／刪除，
> 正好佐證證據 3 說的「三條流程全壞」。）
>
> **驗證狀態**：
> - ✅ `node --input-type=module --check`：兩檔語法正確
> - ✅ 抽出原始碼實際字面值餵給 WHATWG URL 解析器（瀏覽器同一套規則）：
>   4 個跳轉點全部解析為 `http://localhost:8080/my-characters` 與
>   `http://localhost:8080/login/`，並確認已無任何 `` ` `` 或 `+` 拼接（5/5 通過）
> - ✅ `grep` 確認全專案無 `APP_URL` 殘留
> - ⚠️ **`npm run build` 不算數**：`vite.config.js` 沒有設 `rollupOptions.input`
>   多頁入口，build 只涵蓋 `index.html`（7 modules），**完全沒有編譯到
>   `creator-create.html`／`creator-edit.html` 這兩個真正的主頁面**。
>   這是本次順帶發現的既有問題，與 Bug 1 無關，另記於文末「調查中順帶發現」。
> - ⏳ **尚未經真人瀏覽器實測**——四個前端 dev server 當時皆已關閉，未擅自啟動。
>   仍須依下方待辦 3 走一次真實流程才算結案。

- **服務**：`persona-nexus-character`
- **檔案**：`src/create.js:23, 56`（`edit.js` 可能有同樣問題，待確認，見下方「待辦」）
- **嚴重度**：高——每次建立角色都會 100% 重現，使用者會被導到一個打不開的錯誤頁面
- **現象**：建立角色成功、訊息框顯示成功訊息後，1.5 秒自動跳轉時網址列變成
  `http://my-characters/`，出現 `ERR_NAME_NOT_RESOLVED`，沒有正確跳回大廳「我的角色」頁。
  已重現兩次（兩次建立角色都發生），確認穩定可重現。
- **根因**：`LOBBY_APP_URL` 定義成相對路徑常數 `'/'`（`create.js:23`），但第 56 行的拼接
  `` `${LOBBY_APP_URL}/my-characters` `` 在 `LOBBY_APP_URL === '/'` 時算出
  `'//my-characters'`——開頭雙斜線的字串被瀏覽器當成 protocol-relative URL（要連到叫
  `my-characters` 的網域），因此被導向 `http://my-characters/` 而非
  `http://localhost:8080/my-characters`。
- **確認方式**：`git diff -- persona-nexus-character/src/create.js`，確認這是本輪 SOP 優化
  尚未 commit 的改動；優化前用絕對網址拼接沒有這個問題。

### 🔍 調查報告（2026-07-26）

**結論：根因描述正確，但影響範圍被低估——實際有 3 處相同缺陷，不是 1 處。**

**證據 1｜`git diff` 確認是本輪優化引入（注意：四個前端各自有獨立的巢狀 git repo，
要在子目錄下跑 `git -C persona-nexus-character diff`，在平台根目錄跑 `git diff` 看不到）**

`create.js` 與 `edit.js` 的 diff 都顯示同一組改動：

```diff
-const LOGIN_APP_URL = configLoadError ? 'http://localhost:5173' : config.frontends.web;
-const LOBBY_APP_URL = configLoadError ? 'http://localhost:5175' : config.frontends.lobby;
+const LOGIN_APP_URL = '/login/';
+const LOBBY_APP_URL = '/';
```

而拼接那一行 `` `${LOBBY_APP_URL}/my-characters` `` **完全沒有跟著調整**。優化前
`LOBBY_APP_URL` 是 `http://localhost:5175`，拼出來是合法的
`http://localhost:5175/my-characters`；改成 `'/'` 之後才變成 `'//my-characters'`。
確認為本輪 SOP 優化引入、尚未 commit 的迴歸。

**證據 2｜用 WHATWG URL 解析器（瀏覽器用的同一套規則）實測解析結果**

以 `http://localhost:8080/character/creator-create.html` 為 base：

| 出處 | 字面值 | 解析結果 | 判定 |
|------|--------|----------|------|
| `create.js:56`、`edit.js:78`、`edit.js:101` | `"//my-characters"` | `http://my-characters/` | ❌ 壞掉 |
| `create.js:37` | `"/login/"` | `http://localhost:8080/login/` | ✅ 正確 |
| `edit.js:37` | `"/login//"` | `http://localhost:8080/login//` | ⚠️ 見證據 4 |
| `lobby/src/main.js:40`（對照組） | `"/login/"` | `http://localhost:8080/login/` | ✅ 正確 |

解析結果 `http://my-characters/` 與測試時實際觀察到的網址列內容、`ERR_NAME_NOT_RESOLVED`
完全吻合，根因確立，無推測成分。

**證據 3｜全域掃描，確認共有 3 處（不是待辦 2 說的「可能」，是確定有）**

對四個前端的 `src/` 全面 grep `APP_URL` 後，會產生雙斜線的共 3 處：

- `persona-nexus-character/src/create.js:56` — 建立角色成功後跳轉
- `persona-nexus-character/src/edit.js:78` — **更新**角色成功後跳轉
- `persona-nexus-character/src/edit.js:101` — **刪除**角色成功後跳轉

三處的字面值都是 `` `${LOBBY_APP_URL}/my-characters` ``，`LOBBY_APP_URL` 都是 `'/'`。
代表第六階段還沒測的「編輯角色」與「刪除角色」兩條流程，跳轉必定也是壞的。

對照組：`persona-nexus-lobby/src/main.js:19` 用 `'/login'`（結尾**不**帶斜線）+ `` `${...}/` ``，
`persona-nexus-chat/src/main.js:8` 同樣寫法，兩者都正確。問題只出在 character 這個服務。

**證據 4｜`edit.js:37` 是相關但性質不同的第 4 處，已實測，不是使用者遇到的故障**

`edit.js:37` 是 `` `${LOGIN_APP_URL}/` ``，`LOGIN_APP_URL = '/login/'` → 算出 `/login//`。
它只有**一個**開頭斜線，不是 protocol-relative URL，所以不會跑去解析網域。實際打過 Caddy 測：

```
GET http://localhost:8080/login/   -> HTTP 200, 1833 bytes
GET http://localhost:8080/login//  -> HTTP 200, 1823 bytes   ← 仍然能開
```

差異在於 Vite 對 `/login//` **沒有套用 base 改寫**，回傳的是未轉換的原始 HTML：

```diff
-  <link rel="stylesheet" href="/login/src/style.css">     # /login/  正確改寫
+  <link rel="stylesheet" href="./src/style.css">          # /login// 未改寫
```

相對路徑 `./src/style.css` 以 `/login//` 為 base 又剛好解析回 `/login//src/style.css`，
實測也是 HTTP 200，所以**目前碰巧仍能正常運作**。這是拼接不一致造成的非正規化網址，
建議一併修掉以免日後 base 設定一變就爆，但它**不是**使用者這次遇到的故障，
修復時不要把它跟前 3 處混為一談。另注意 `create.js:37` 寫的是 `` `${LOGIN_APP_URL}` ``
（沒有多加斜線）、`edit.js:37` 寫的是 `` `${LOGIN_APP_URL}/` ``——同一個專案裡兩個檔案
對同一個常數的用法就已經不一致，這正是缺陷的來源。

**~~建議修法~~（已被採用的方案取代，保留供對照）**：原先建議對齊 lobby／chat 的
「不帶結尾斜線的前綴常數 + `` `${CONST}/xxx` `` 拼接」。經與使用者討論後**改採 B 方案**
（完整路徑常數、呼叫點零拼接），理由見本節開頭的「已修復」區塊——關鍵差別在於
只要還留著拼接，這類 bug 就仍有再犯的空間。

- [x] ~~**待辦 1**：修正 `create.js:56` 的拼接邏輯，避免雙斜線。~~
  → **已完成**，且採用比原提案更根本的做法（B 方案，見本節開頭）。
  原提案的 `=== '/' ? ... : ...` 三元判斷寫法**未採用**：它只修得掉 1 處，
  還會讓 3 個呼叫點各自重複同一份判斷邏輯（違反 DRY）。
- [x] ~~**待辦 2**：檢查 `persona-nexus-character/src/edit.js` 是否有同樣的
  `LOBBY_APP_URL`/`LOGIN_APP_URL` 拼接 pattern~~ → **調查完成：確定有，見上方證據 3／4**。
  `edit.js:78`（更新後跳轉）與 `edit.js:101`（刪除後跳轉）與 `create.js:56` 完全相同，
  已一併修；`edit.js:37`（`/login//`）也同時處理掉了。
- [x] **待辦 3**：修完後回《前端網頁手動測試task.md》第三階段 3.2、第六階段 6.1/6.2 重新
  實測一次自動跳轉是否正常。**注意：第六階段本來就還沒開始測，證據 3 已證明編輯／刪除的
  跳轉必定也是壞的，重測時這兩條都要走到，不能只測建立。**
  → **✅ 2026-07-27 已完成真人瀏覽器實測**：三條路徑全部通過。
  * 建立角色 → 1.5 秒自動跳轉 → 網址 `http://localhost:8080/my-characters` ✅
  * 編輯角色 → 儲存後自動跳轉 → 網址 `http://localhost:8080/my-characters` ✅
  * 刪除角色 → 跳轉 → 網址 `http://localhost:8080/my-characters` ✅
  所有跳轉都停在正確位置，沒有 protocol-relative URL 導致的 `http://my-characters/` 錯誤。

---

## Bug 2：大廳角色卡片 tooltip 點擊進入聊天室後不會消失，殘留畫面

> ### ✅ 已修復（2026-07-26）
>
> **先確認了一件事：「把 tooltip 改成卡片的子元素、讓它隨卡片一起被移除」這個最結構性的
> 修法不可行。** 查 `src/style.css:337-340` 發現 `.character-card:hover` 帶
> `transform: translateY(-2px)`——transform 會讓 `position: fixed` 的後代改以卡片為定位
> 基準；`.character-card` 本身又有 `overflow: hidden`（`:331`）會裁切。兩者都剛好在浮窗
> 要顯示的那一刻發作。所以 body 級單例是**必要的**，不是可以順手改掉的結構。
>
> **既然生命週期無法結構性綁定，就補齊事件涵蓋範圍**，全部封裝在
> `src/character-tooltip.js` 內部——`home.js` 與 `main.js` 完全不用改，也不需要知道
> 浮窗的存在（符合模組邊界與資訊隱藏）：
>
> ```js
> function hideTooltip() {                     // 抽出共用隱藏函式
>   if (tooltipEl) tooltipEl.style.opacity = '0';
> }
>
> // getTooltip() 內，單例建立時一併註冊（一輩子只註冊一次）
> window.addEventListener('popstate', hideTooltip);
>
> // attachIntroTooltip() 內
> card.addEventListener('mouseleave', hideTooltip);
> card.addEventListener('click', hideTooltip);   // ← 新增，修復重點
> ```
>
> 涵蓋兩條「卡片在指標仍停留其上時被銷毀」的路徑：
> 1. **點卡片導頁**（實測 100% 重現的那條）—— `click` 與導頁在同一個事件裡，
>    不必等任何指標移動。
> 2. **瀏覽器上一頁／下一頁**（調查修法時另外想到並確認可觸發的路徑）——
>    `popstate` 同樣會在指標不動的情況下重繪內容區。
>
> **未採用原待辦 1 的寫法**（匯出 `hideTooltip()` 給 `home.js` 在導頁前呼叫）：
> 那會讓 `home.js` 反過來得知道浮窗的實作細節，而且只擋得住 `home.js` 那一條路徑。
> 現在的做法讓模組自己負責自己的生命週期，涵蓋範圍更廣、耦合更少。
>
> **規格已先行更新**（依 SOP 貫穿原則 #6「行為變更要顯性」，先改規格才改碼）：
> `openspec/specs/lobby-ui/spec.md` 的〈角色卡簡介浮窗〉需求新增了「不得只依賴
> `mouseleave`」的規定與掛 body 的理由，兩個 Scenario 改寫為修復後行為，
> 原本標記「已知缺陷」的 Scenario 改為歷史紀錄。`openspec validate --all` 全綠。
>
> **驗證狀態**：
> - ✅ 用最小 DOM stub 載入真實模組跑事件流程：**8/8 通過**——
>   hover 顯示、click 隱藏、popstate 隱藏、mouseleave 仍可隱藏（未退化）、
>   空 introduction 不綁事件、浮窗單例只建立一次、popstate 只註冊一次
> - ✅ `npm run build` 通過（lobby 是完整多入口建置，涵蓋本次改動）
> - ✅ `openspec validate --all` 全綠
> - ⏳ **尚未經真人瀏覽器實測**，見待辦 3
>
> **未處理、留作已知限制**：原待辦 2 的「SPA 路由切換時統一清理 body 級殘留元素」
> **沒有做**。理由是 lobby 目前沒有集中的切頁收口（`main.js:55-92` 的
> `restoreRouteFromUrl()` 只管初次載入，之後各頁各自 `import` + `pushState`），
> 要做得先建一個共用切頁入口，範圍遠超修這個 bug。證據 5 找到的
> `message-utils.js` 同型問題因此**仍然存在**，已列入文末「調查／修復中順帶發現」。

- **服務**：`persona-nexus-lobby`
- **檔案**：`src/character-tooltip.js`（`attachIntroTooltip()` 的 `mouseleave` handler）、
  `src/home.js`（卡片 click handler）
- **嚴重度**：中——不影響功能，但視覺上很明顯的殘留 bug，且是本輪新增模組的問題
- **現象**：大廳首頁滑鼠移到角色卡片上，右側浮現簡介 tooltip；點卡片進入聊天室後，tooltip
  沒有消失，殘留疊在聊天室畫面上，直到回大廳、對任一張卡片完整「滑入再滑出」一次才會消失。
- **根因**：tooltip 元素是掛在 `document.body` 下的全站共用單例，只靠 `mouseleave` 把
  `opacity` 設回 `'0'`「隱藏」，從未真的從 DOM 移除。lobby 是 SPA、切頁不整頁重載，
  `document.body` 跨頁延續；而唯一的隱藏路徑掛在點擊後隨即被銷毀的卡片元素上。

### 🔍 調查報告（2026-07-26）

**結論：根因成立，且可以只用原始碼證明，不需要依賴「瀏覽器搶不搶得到 `mouseleave`」這種
無法驗證的說法。原描述中「很可能搶在派發之前」的推測措辭已改寫為下方可覆核的事實。**

**證據 1｜全專案只有一條隱藏路徑，而它掛在會被銷毀的元素上**

對 `persona-nexus-lobby` 全專案 grep `tooltip`，命中只有兩個檔案：
`src/character-tooltip.js` 本身，以及 `src/home.js:2, 73`（唯一的使用者）。
`character-tooltip.js` 全檔 48 行，**把 `opacity` 設回 `'0'` 的地方只有第 46 行一處**：

```js
// character-tooltip.js:45-47
card.addEventListener('mouseleave', () => {
  if (tooltipEl) tooltipEl.style.opacity = '0';
});
```

也就是說：整個 lobby 沒有任何其他程式碼會隱藏這個 tooltip；沒有 `hideTooltip()` 匯出，
沒有路由層的清理，沒有 `remove()`。唯一的隱藏開關綁在 `card` 上。

**證據 2｜卡片在導頁時必定被銷毀，該監聽器再也不可能執行**

`home.js:56-60` 的點擊處理器：

```js
cardElement.addEventListener('click', async (e) => {
  e.preventDefault();
  const { loadChatPage } = await import('./chat-page.js');
  await loadChatPage(character.id);
});
```

`chat-page.js:9-12`：

```js
const contentArea = document.getElementById('content-area');
const response = await fetch('/src/chat.html');
const html = await response.text();
contentArea.innerHTML = html;      // ← 這一行把整個角色卡格線（含 cardElement）換掉
```

`contentArea.innerHTML = html` 會丟棄 `#content-area` 底下所有子節點，`cardElement`
連同它的 `mouseleave` 監聽器一起消失。而使用者是「滑上去→原地點下去」，滑鼠指標
全程沒有離開卡片，**不存在任何一次真正的指標移出動作**能在銷毀前觸發 `mouseleave`。

**證據 3｜tooltip 元素本身不在被清掉的範圍內，所以會留在畫面上**

`character-tooltip.js:12` 是 `document.body.appendChild(tooltipEl)`——掛在 `body` 下，
不是 `#content-area` 底下，因此 `contentArea.innerHTML = html` 清不到它。
`src/style.css:403-417` 的樣式進一步確認它會浮在最上層：

```css
#character-intro-tooltip {
  position: fixed;      /* 不隨內容區捲動，停在原本卡片的視窗座標 */
  opacity: 0;
  pointer-events: none;
  z-index: 1000;        /* 蓋在聊天室畫面之上 */
}
```

`tooltipEl` 是模組層級變數（`character-tooltip.js:5`），ES module 在 SPA 中只求值一次，
所以這個單例跨頁存活。三項合起來：**元素還在 body、`opacity` 仍是 `'1'`、`z-index:1000`
浮在最上層 → 殘留在聊天室畫面上**，與實測現象完全一致。

**證據 4｜「回大廳 hover 任一卡片才消失」也被同一組程式碼解釋**

回大廳時 `home.js:9` 同樣執行 `contentArea.innerHTML = html`，重新建立一批**新的**卡片並
重新綁定監聽器（`home.js:73`）。對新卡片滑入 → `mouseenter` 走 `getTooltip()`，因為
`tooltipEl` 非 null 而複用**同一個**元素（`character-tooltip.js:9`），重新定位後設回
`opacity = '1'`；滑出 → 新卡片的 `mouseleave` 才終於把它設成 `'0'`。使用者觀察到的
「一定要完整滑入再滑出一次才消失」被逐步對上，無殘留疑點。

**關於「瀏覽器會不會在元素被移除時補送 `mouseleave`」**：W3C UI Events 規格把 `mouseleave`
定義為「指標裝置移出元素邊界時」觸發，**元素被移除並不是指標移動**，規格沒有保證會補送，
各家瀏覽器行為也不一致。這一點無法在沒有瀏覽器自動化工具的情況下取得決定性證據（本機
未安裝 Playwright／Puppeteer）。但這不影響結論：使用者已 100% 重現殘留，代表在實際環境中
它確實沒有被送出或沒有起作用；而證據 1 已證明**不該把唯一的隱藏路徑押在這個不保證的事件上**，
這才是要修的地方。

**證據 5｜同類結構問題不只 tooltip 一處，`message-utils.js` 也中招（調查中額外發現）**

grep `document.body.appendChild`，lobby 全專案共 4 處，逐一查對生命週期：

| 位置 | 是否會殘留 | 依據 |
|------|-----------|------|
| `character-tooltip.js:12` | ❌ **會殘留** | 只設 `opacity`，全檔無 `remove()`（證據 1） |
| `my-character.js:76`（角色卡選單） | ✅ 安全 | `dismissMenu()` 有 `menu.remove()`（`:54-57`），且 `:66` 的編輯選項在導頁**之前**先呼叫 `dismissMenu()` |
| `conversation-history.js:42`（歷史選單） | ✅ 安全 | 同上，`dismissMenu()` 有 `menu.remove()`（`:13-16`） |
| `message-utils.js:6`（訊息框） | ⚠️ **條件性會殘留** | 見下方說明 |

`message-utils.js` 的 `getMessageBox()` 是「先找現有的 `#message-box`，找不到才建一個掛到
`document.body`」。而 `public/src/home.html:8` 與 `public/src/my-character.html:8` 這兩個樣板
**自帶** `<div id="message-box">`，所以在首頁／我的角色頁時它抓到的是 `#content-area` 內的那個，
導頁時會隨 `innerHTML` 一起被清掉，沒問題。但在**聊天室頁與角色編輯頁**（`chat.html`／
`character-edit.html` 樣板沒有這個 div）就會走到 `document.body.appendChild`，變成 body 級單例，
而且它同樣**沒有任何 `remove()`**，只靠 `display:none` 隱藏。

具體可觸發路徑：`conversation-history.js:33` 的 `showMessage('error', \`刪除失敗: ...\`)`
**沒有傳 `autoHideMs`**（對照 `home.js:81` 有傳 `3000`），側邊欄在所有頁面都在，
所以「人在聊天室 → 側邊欄刪除對話失敗」就會產生一個掛在 body、不會自動隱藏、
也不會在切頁時被清掉的錯誤訊息框。這條路徑目前**尚未實測驗證**（需要製造刪除失敗），
但結構與 tooltip 完全同型，先記錄在此。

**修法評估（依證據調整）**：原待辦 1（匯出 `hideTooltip()` 給 `home.js` 在導頁前呼叫）
能解決本次實測到的問題，但只擋得住「從首頁點卡片」這一條路徑，而且證據 5 顯示 body 級元素
殘留不是單一個案。問題的本質是「body 級 UI 元素的生命週期沒有跟著 SPA 路由走」，
因此**原待辦 2 應從「選擇性」升為建議的主要修法**：在路由切換的單一收口處統一清理。
可惜 lobby 目前沒有集中的路由切換函式（`main.js` 的 `restoreRouteFromUrl()` 只處理初次載入，
之後各頁是各自 `import` + `pushState`，見 `main.js:55-92` 與 `sidebar.js:76`），
要做根本修法得先有一個共用的「切頁」入口，成本比待辦 1 高。兩者的取捨留給使用者決定。

- [x] ~~**待辦 1**：`character-tooltip.js` 增加一個可從外部呼叫的隱藏函式（例如匯出
  `hideTooltip()`），在 `home.js` 的卡片 `click` handler 觸發導頁**之前**主動呼叫一次。~~
  → **已完成，但改成不匯出的做法**：`hideTooltip()` 留在模組內部，由模組自己綁在
  卡片的 `click` 與 window 的 `popstate` 上。原提案要 `home.js` 主動呼叫，會讓呼叫端
  反過來得知道浮窗的實作細節，且只擋得住 `home.js` 一條路徑。
- [ ] **待辦 2**（更根本，選擇性）：評估是否要把 tooltip 隱藏邏輯改成不依賴 `mouseleave`
  單一事件保證觸發，例如在每次 SPA 路由切換時統一清理殘留的 body 級 UI 元素。
  → **本次未做，維持開放**。tooltip 本身已透過 `click` + `popstate` 涵蓋所有已知路徑，
  但這條待辦真正的價值在於**一併解決 `message-utils.js` 的同型問題**（證據 5），
  那個問題目前仍然存在。需要先替 lobby 建立一個共用的切頁收口才能做，範圍較大。
- [x] **待辦 3**：修完後回《前端網頁手動測試task.md》第四階段 4.2 重新實測：hover 卡片 →
  點擊進入聊天室 → 確認 tooltip 立即消失、不殘留。
  **另外加測本次新涵蓋的第二條路徑**：hover 卡片 → 不移開滑鼠 → 按瀏覽器上一頁（或 Alt+←）
  → 確認 tooltip 同樣立即消失。
  → **✅ 2026-07-27 已完成真人瀏覽器實測**：兩條路徑全部通過。
  * 路徑 A（點卡片進聊天室）：浮窗立即消失 ✅
  * 路徑 B（按 Alt+← 回上一頁）：浮窗立即消失 ✅
  無任何殘留現象。

---

## Bug 3：聊天室輪詢逾時（空訊息陣列）時，`virtualMessageList.js` 拋出未捕捉例外

> ### ✅ 已修復（2026-07-26）
>
> **改動**：`persona-nexus-chat/src/virtualMessageList.js` 的 `computeRange()` 開頭
> 加上空陣列的提前返回：
>
> ```js
> if (items.length === 0) {
>   return { start: 0, end: -1, offsetTop: 0 };
> }
> ```
>
> `end` 回 `-1` 讓 `renderWindow()` 的 `for (let i = start; i <= end; i++)` 自然不執行，
> 同時仍會走「移除已離開視窗的節點」那一段，把上一輪殘留的氣泡清乾淨。
>
> **只做待辦 1，沒做待辦 2**：待辦 2（在 `chat.js:632` 加 `messages.length > 0` 判斷）
> 只擋得住其中一條路徑，而且會把「空陣列是特殊情況」這個知識重複到第二個地方
> （DRY／KISS）。待辦 1 是通用模組該自己守的邊界，一改就同時涵蓋證據 1 與證據 4 兩條路徑，
> 因此不再加第二道判斷。
>
> **標題已修正**：原標題後半「蓋掉原本該顯示的『建立失敗』錯誤訊息」經證據 2 確認不成立，
> 已刪除（錯誤文字在 `chat.js:203` 就已寫入 DOM，例外發生在其後）。
>
> **驗證狀態**：
> - ✅ 用最小 DOM stub 載入真實模組跑 4 條路徑：**4/4 通過**——
>   以空陣列建立（逾時路徑）、以非空陣列建立（正常流程未退化）、
>   非空→刪光成空後 `sync()`（證據 4 的回溯刪除路徑）、空↔非空來回切換
> - ✅ 修復前的重現腳本已無法再重現例外（原本必拋 TypeError）
> - ✅ `npm run build` 通過（13 modules，chat 是單頁完整建置，確實涵蓋本次改動）
> - ⏳ **尚未經真人瀏覽器實測**，見待辦 3

- **服務**：`persona-nexus-chat`
- **檔案**：`src/virtualMessageList.js`（`computeRange()`）、`src/chat.js:632`
- **嚴重度**：中——只在「聊天室初次建立就失敗/逾時」這個邊界情境觸發，不影響已建立成功的
  正常聊天流程，但一旦觸發，畫面會顯示未預期的 JS 錯誤而非設計中的錯誤訊息
- **現象**：聊天室輪詢滿 120 次逾時後，Console 出現
  `Uncaught TypeError: Cannot read properties of undefined (reading 'id') at keyOf (chat.js:78)`，
  呼叫鏈：`initChat → renderMessages → createVirtualMessageList → sync → computeRange → keyOf`。
  畫面沒有正確顯示規格設計中「聊天室建立失敗，請重新整理頁面再試」的錯誤覆蓋層文字。
- **根因**：`computeRange(items)` 處理空陣列（`items.length === 0`）時有漏洞：找不到任何
  項目的迴圈跑完後 `i === items.length`（`0 === 0`）成立，接著執行
  `start = Math.max(0, items.length - 1)`（空陣列時算出 `0`），再執行
  `startOffset = offset - slotHeight(keyOf(items[start]))`——但 `items[0]` 在空陣列上是
  `undefined`，`keyOf(undefined)` 也就是存取 `undefined.id`，直接拋出例外。
- **觸發路徑**：`chat.js:632`（`initChat` 尾端「初始化渲染」那行）在
  `await initializeChat(characterId)` 執行完後，**不論成功或失敗都無條件呼叫一次
  `renderMessages()`**。`initializeChat()` 逾時失敗時只顯示錯誤覆蓋層文字然後 `return`，
  `messages` 仍是初始值 `[]`，這次無條件呼叫就以空陣列觸發上述漏洞。

### 🔍 調查報告（2026-07-26）

**結論：崩潰本身完全屬實，已寫成可重複執行的腳本證明。但「蓋掉錯誤訊息」這個描述經查
不成立，實際後果是另外三項——修復前要先知道自己在修什麼。**

**證據 1｜可執行的重現腳本（不改動任何專案原始碼）**

用最小 DOM stub 直接 import 真實的 `virtualMessageList.js`，以 `chat.js:74-80` 完全相同的
參數呼叫，`getItems` 回傳空陣列：

```
✅ 重現成功
   例外類型 : TypeError
   訊息     : Cannot read properties of undefined (reading 'id')
   堆疊     :
     at keyOf         (呼叫端提供的 (m) => m.id)
     at computeRange  (persona-nexus-chat/src/virtualMessageList.js:86)
     at sync          (persona-nexus-chat/src/virtualMessageList.js:232)
     at createVirtualMessageList (persona-nexus-chat/src/virtualMessageList.js:255)

✅ 對照組（1 筆訊息）：未拋例外，證明問題專屬於空陣列路徑
```

堆疊與測試時 Console 觀察到的
`Uncaught TypeError: Cannot read properties of undefined (reading 'id') at keyOf (chat.js:78)`
完全對得上（`chat.js:78` 正是 `keyOf: (m) => m.id` 那一行）。根因與觸發點皆已確立，
不是推測。

逐行對照 `computeRange([])` 的算式：`for (; i < 0; i++)` 不執行 → `i` 維持 `0` →
`if (0 === 0)` 成立 → `start = Math.max(0, -1) = 0` → `keyOf(items[0])` 而 `items[0]`
是 `undefined` → 存取 `undefined.id` → 拋錯。

**證據 2｜⚠️ 修正原描述：錯誤覆蓋層文字其實有顯示，沒有被蓋掉**

原本記載「畫面沒有正確顯示『聊天室建立失敗，請重新整理頁面再試』」。讀 `chat.js` 的執行
順序後可確認**這個因果關係不成立**：

```js
// chat.js:200-205（initializeChat 內）
if (!conversation) {
  characterStatusEl.textContent = '離線';
  showInitializing('聊天室建立失敗，請重新整理頁面再試');   // ← 文字在這裡就已寫入 DOM
  return;
}
...
// chat.js:632（initChat 尾端，上面那行 return 之後才會走到）
renderMessages();                                          // ← 例外在這裡才發生
```

`showInitializing()` 的實作（`chat.js:28-33`）是同步的 `initializingMessage.textContent = message`
＋ `classList.remove('hidden')`，在 `initializeChat` 回傳前就完成了。例外發生在其後，
不可能回頭把已寫入的文字擦掉。原文件其實已自我標註「實際畫面行為待確認」
（見《前端網頁手動測試task.md》第 364-365 行），現在確認：**這個推測是錯的**。

**證據 3｜例外的真實後果（改用這三項評估嚴重度）**

例外從 `chat.js:632` 拋出後，`initChat` 的 Promise 被 reject，而 `main.js:26` 是
`await initChat(characterId)` 且**沒有 try/catch**，所以會成為未捕捉的 module 層級錯誤。
實際損失的是 632 行之後的東西：

1. **`chat.js:633` 的 `messageInput.focus()` 不會執行**——不過此情境下輸入框本來就被
   `showInitializing()` 設成 `disabled`，影響輕微。
2. **`vlist` 永遠停在 `null`**——`chat.js:74` 的 `vlist = createVirtualMessageList({...})`
   是在函式**拋出時**中斷，賦值從未完成。所以之後每一次 `renderMessages()` 都會重跑
   `createVirtualMessageList` 並在訊息仍為空時再崩一次。
3. **Console 出現未捕捉例外**——對使用者是雜訊，對開發是誤導（看起來像渲染層壞了，
   實際上是後端沒起來）。

反過來說，**設計中的錯誤覆蓋層文字有正常顯示、輸入框有正確保持禁用**，
所以使用者實際看到的畫面其實是符合設計的。**Bug 3 的嚴重度應下修**：它是一個真實且
必然發生的例外，值得修，但不像原描述那樣會讓使用者看不到錯誤提示。

**證據 4｜另有一條同源的觸發路徑，但目前被上游條件擋住（記錄備查，不需為它改設計）**

`chat.js:168-169` 的回溯式刪除：

```js
messages = messages.filter(m => !deletedIdSet.has(m.id));
renderMessages();
```

若 `messages` 被清成空陣列，這裡走的是 `vlist.sync()` → 同樣的 `computeRange([])` → 崩潰；
而且這段包在 `try/catch`（`:170-173`）裡，會被轉成
`showToast('刪除失敗: Cannot read properties of undefined...')`——**明明後端已刪除成功，
卻對使用者謊報刪除失敗**。

不過實測前先查了能不能真的走到：`chat-service/src/services/conversationService.js:332-338`
在建立聊天室時會把角色的 `opening` 存成第一則 `assistant` 訊息，而
`persona-nexus-character/creator-create.html:53` 的開場白欄位帶 `required`，
所以正常流程建立的角色一定有開場白 → 第一則訊息必為 assistant；
再加上 `chat.js:60-62` 的三點選單只在 `msg.role === 'user'` 時才渲染，
第一則訊息**沒有刪除入口**，`messages` 因此無法經 UI 被清空。

結論：這是一條**程式碼層面存在、但目前被兩個上游條件擋住**的路徑。它成立與否取決於
另一個服務（`chat-service`）和另一個前端（`persona-nexus-character`）的行為，
這種跨服務的隱含耦合本身就是風險。**只要照待辦 1 修 `computeRange()`，這條路徑會一併免疫**，
不需要額外處理。

**修法評估**：待辦 1（`computeRange()` 開頭對空陣列提前返回）是唯一必要的修法，
且能同時涵蓋證據 1 與證據 4 兩條路徑。待辦 2（在 `chat.js:632` 加 `messages.length > 0`
判斷）只擋得住其中一條，**不建議單獨採用**；若要做，就當成額外的防禦深度。

- [x] ~~**待辦 1**（根本修法，優先）：`computeRange()` 函式開頭加上對 `items.length === 0` 的
  提前返回~~ → **已完成**，回傳 `{ start: 0, end: -1, offsetTop: 0 }`。
- [x] ~~**待辦 2**（輔助修法，選擇性）：`chat.js:632` 那行無條件呼叫的 `renderMessages()`
  改成只在 `messages.length > 0` 時才呼叫。~~ → **決定不做**（原本寫「建議兩個都做」，
  調查後改變判斷）：待辦 1 已同時涵蓋證據 1 與證據 4 兩條路徑，再加這道判斷等於把
  「空陣列是特殊情況」的知識重複到第二個地方，違反 DRY／KISS，且會讓通用模組的邊界
  責任變得模糊。`chat.js:632` 維持無條件呼叫。
- [x] **待辦 3**：修完後需要重新製造一次「聊天室建立逾時」的情境（例如暫時關掉
  chat-service 或讓 ai-service/Qdrant 斷線）驗證：畫面正確顯示「聊天室建立失敗，請重新
  整理頁面再試」文字、Console 不再出現這個 TypeError。
  → **✅ 2026-07-27 已完成真人瀏覽器實測**：關掉 chat-service 模擬逾時。
  * 畫面顯示「聊天室建立失敗」訊息 ✅
  * Console 無 TypeError（只有預期的 502 錯誤，沒有 `undefined.id` 崩潰） ✅
- [x] **待辦 4**（新增）：修完 `computeRange()` 後，順手用調查時的重現腳本再跑一次確認
  空陣列不再拋例外（腳本邏輯見證據 1，用最小 DOM stub 直接 import 真模組，
  不需要啟動任何服務，秒級可驗）。
  → **已於靜態驗證階段完成**（重現腳本已失效，證實修復成功）。

---

## Bug 4：Qdrant 中斷後，ai-service 必須整套重啟才恢復

> **標題已依調查修正**。原標題「ai-service 與 Qdrant 斷線後無法自動重連」帶有錯誤的因果暗示
> ——證據 1 已證明連線層本來就會自動重連。現在的標題只描述觀察到的現象。

> ### ✅ 已修復（2026-07-26，A + B + C + D 全做）
>
> 修復前先逐條核對原始碼，四項證據描述與現況**完全一致**（`app.py:33-51`、`app.py:89-96`、
> `vector_store.py:233-248` 零呼叫、`start-all-services.bat:62` 的 `--rm`）。
>
> **A｜collection 於執行期自動補建**（核心）
> `src/rag/vector_store.py` 新增模組常數 `EMBEDDING_VECTOR_SIZE = 768` 與
> `REQUIRED_COLLECTIONS`（characters/fewshots/summaries），以及兩個冪等函式：
>
> ```python
> def ensure_collection(self, collection_name: str) -> None:
>     if not self.create_collection(collection_name, vector_size=EMBEDDING_VECTOR_SIZE):
>         raise Exception(
>             f"Qdrant collection '{collection_name}' is unavailable and could not be created"
>         )
>
> def ensure_collections(self) -> None:
>     for collection_name in REQUIRED_COLLECTIONS:
>         self.ensure_collection(collection_name)
> ```
>
> 呼叫點共 6 處。`vector_store` 內 3 處（涵蓋所有走封裝層的存取）：`upsert_documents()`、
> `search()`、`delete_points()` 開頭各 ensure 一次。`rag_repository` 內 3 處——這三個方法
> **繞過封裝層直接用 `vector_store.client`**，不補會在 collection 缺失時吃 404：
> `replace_protagonist_background()`（filter 刪除）、`get_latest_summary()`（scroll）、
> `delete_conversation_data()`（三個 delete，用 `ensure_collections()`）。
> `get_conversation_data()` 原本就把例外吞成空結果，不需要處理。
>
> **只 ensure 寫入路徑是不夠的**（這點差一步就漏掉）：`summaries` 只有在存摘要時才會被寫，
> 一個全新的 Qdrant 上，「初始化聊天室」只會補建 characters 與 fewshots，接著第一次生成回應
> 就會在 `search_summaries()`／`get_latest_summary()` 撞上缺失的 `summaries` 而崩掉。
> 所以讀取路徑也必須 ensure。
>
> **訊息刻意含 "Qdrant" 字樣**：`rag_controller._raise_for_error()` 是用關鍵字
> （`"qdrant"`/`"connect"`/`"refused"`）查表決定回 503 還是 500。若沿用
> `create_collection()` 那句泛用的失敗訊息，Qdrant 掛掉時會被誤判成 500，
> 破壞既有規格〈清理聊天室 RAG 資料〉的 503 情境。原始錯誤原因仍由
> `create_collection()` 的 `✗ Failed to create collection: ...` 日誌保留（實測有印出）。
>
> **B｜`/health` 接上既有的健康檢查鏈**
> `app.py:89-96` 改為呼叫 `rag_service.check_rag_health()` → `vector_store.check_connection()`
> ——這條鏈本來就寫好了，只是**兩層包裝都零呼叫點**，本次把它接起來，死代碼變成活代碼。
> 可達回 200 `{status:"ok", ..., dependencies:{qdrant:{status:"ok"}}}`；
> 不可達回 **503** `{status:"degraded", ..., dependencies:{qdrant:{status:"error", message}}}`。
> 刻意用 `JSONResponse` 而非 `HTTPException`：健康檢查回報的是「狀態」不是「錯誤」，
> 不該被全域 handler 轉成 `{error, message}` 而丟失結構。
> 只探測 Qdrant，不探測 Ollama（範圍刻意限縮於 RAG 依賴，已寫進規格）。
>
> **D｜startup 維持不 crash，但補上「吞得起」的理由**
> `app.py` 的 startup 改成呼叫 `ensure_collections()`（三段重複的 `create_collection` +
> `raise` 收斂成一行，768 這個魔術數字也不再散落三處），`except` 仍只印日誌不 raise，
> 並加註為什麼吞得起：有 A 就會在執行期補建、有 B 就看得見。多印一行提示現況。
>
> **C｜啟動腳本拿掉 `--rm`**
> 改為 `--restart unless-stopped`，並且**必須先試 `docker start`**——這是拿掉 `--rm` 後
> 新出現的情況：容器停止後會留在清單裡，直接 `docker run --name qdrant` 會撞名失敗。
>
> ⚠️ **起 Qdrant 的腳本有兩支，兩支都要改**：`start-all-services.bat:57-79` 與
> `start-backend-services.bat:57-80`（後者是前者那段的完整複本）。第一次修的時候只改了
> 前者，漏掉後者，等於只要改用 backend 那支腳本、`--rm` 陷阱就原封不動回來；
> 使用者問「啟動 Qdrant 寫在哪支腳本」時 grep 全平台才發現，已補齊。
> 兩處區塊現在逐字相同，並各自加了 `Keep this block in sync` 註記。
>
> ```bat
> docker start qdrant >nul 2>&1
> if errorlevel 1 (
>     docker run -d --name qdrant --restart unless-stopped -p 6333:6333 -p 6334:6334 -v qdrant_storage:/qdrant/storage qdrant/qdrant
> )
> ```
>
> **規格已先行更新**（SOP 貫穿原則 #6，先改規格才動碼）：
> `ai-service/openspec/specs/ai-generation/spec.md` 新增〈健康檢查〉與
> 〈Collection 於執行期自動補建〉兩個 Requirement（共 8 個 Scenario），改寫
> 〈服務啟動初始化〉並新增「啟動時 Qdrant 不可用」Scenario，同步更新架構圖。
> `openspec validate --all` 3/3 全綠。
>
> **驗證狀態**（都用實機跑，不是讀過就算；全程用 port 6399 的拋棄式容器，
> 沒有碰使用者的 Qdrant，測完已清除，`qdrant_storage` 資料卷完好）：
> - ✅ 四個 Python 檔 `py_compile` 通過
> - ✅ **A 方案 11/11**：ensure 建立（768 維）／重複 ensure 不清空既有資料／
>   對不存在的集合 upsert、search、delete_points 皆自動補建（search 回空陣列而非拋錯）／
>   `ensure_collections()` 補齊三個／Qdrant 不可用時拋錯且訊息實測可被
>   `_raise_for_error()` 判為 **503**／repository 三條繞過封裝的路徑全過／正常路徑未退化
> - ✅ **B + D + 完整恢復情境 10/10**：用 FastAPI TestClient 跑**真實的 `app.py`**——
>   Qdrant 停著啟動服務 → 不 crash（D）→ `/health` 回 **503 degraded** 並指出是 qdrant 壞了（B）
>   → `docker start` 把 Qdrant 拉回來（C：沒有 `--rm` 的容器可以原樣復活）→
>   **全程不重啟 ai-service**，`/health` 自動恢復 200 ok → RAG 寫入自動補建 collection
>   並成功寫入 2 筆（A）。**這就是待辦 6 要求的驗證情境**
> - ✅ **C 的批次語法**：把修改後的 Qdrant 區塊逐字同構複製成測試 bat 實跑兩次——
>   第 1 次走 `docker run`，`docker stop` 後容器**仍留在清單裡**（證明 `--rm` 確實沒了），
>   第 2 次走 `docker start` 原樣復活、無撞名。`docker inspect` 確認
>   `AutoRemove: false`、`RestartPolicy: unless-stopped`、port 對應與資料卷都在
> - ✅ 三支啟動腳本（`start-all-services` / `start-backend-services` / `start-frontend-services`）
>   全檔 0 個非 ASCII 位元組（新增的註解是英文，不會在 cmd.exe 的 ANSI 代碼頁下變成亂碼
>   指令——實測過中文註解確實會炸）
> - ⏳ **尚未經真人實測**：上述都是 TestClient + 拋棄式容器，還沒走過
>   「真實 uvicorn + 真實 6333 + 瀏覽器聊天」。見待辦 6。
>
> **一項與本次修復無關、但務必知道的現場狀況**：使用者機器上**目前正在跑的 Qdrant 容器
> （若有）仍是舊的 `--rm` 容器**，改 bat 不會追溯改變它。要讓新設定生效，得先
> `docker rm -f qdrant` 再跑一次 `start-all-services.bat`（`qdrant_storage` 資料卷不受影響，
> RAG 資料不會掉）。在那之前，交接說明的「陷阱 3」仍然成立。

- **服務**：`ai-service`（後端）；另涉及部署腳本
- **檔案**：`ai-service/app.py:33-51`（startup 建 collection 並吞例外）、
  `ai-service/app.py:89-96`（`/health` 不檢查 Qdrant）、
  `ai-service/src/rag/vector_store.py:233-248`（`check_connection()` 零呼叫點）、
  `start-all-services.bat:62` **與 `start-backend-services.bat:62`**（Qdrant 容器 `--rm`；
  兩支腳本的 Qdrant 區塊是複製貼上的同一段，行號為修復前的值）
- **嚴重度**：中高——不會每次都發生，但一旦 Qdrant 在 ai-service 啟動時不可用，
  服務會**安靜地**進入「自稱健康、實則 RAG 全掛」的狀態，且無法自行恢復
- **現象**：手動重啟 Qdrant docker 容器後，`ai-service` 仍持續回報
  `[WinError 10061] 無法連線，因為目標電腦拒絕連線`／`Failed to create collection: characters`，
  必須把所有服務（含 Docker）全部關閉、用 `start-all-services.bat` 從頭啟動一次讓它自動拉起
  Qdrant，聊天功能才恢復正常。
- **~~推測根因~~**：~~`qdrant-client`／`httpx` 的連線池可能快取了失效連線~~
  → **已用實機實驗推翻，見下方調查報告。**

### 🔍 調查報告（2026-07-26）

**結論：原本的「連線池快取失效連線」推測【不成立】，已用實驗證偽。真正的根因是三件事疊加，
而且沒有一件跟連線韌性有關。**

**證據 1｜實機實驗：直接證偽「連線池快取失效連線」**

為了不動到正在跑的環境，另外起一個拋棄式 Qdrant 容器（port 6399），在 ai-service 的
conda env 裡用**與 `vector_store.py:18-21` 完全相同的方式**建立一個長生命週期
`QdrantClient`，然後停掉容器、再啟動，全程沿用**同一個 client 物件**：

```
① 啟動拋棄式 Qdrant（port 6399）... 已就緒
② 建立長生命週期 client，第一次呼叫：
   呼叫#1: ✅ 成功 -> collections=[]
③ 停掉 Qdrant 容器後，用【同一個 client】呼叫：
   呼叫#2: ❌ 失敗
      例外型別: qdrant_client.http.exceptions.ResponseHandlingException
      訊息    : [WinError 10061] 無法連線，因為目標電腦拒絕連線。
④ 重新啟動 Qdrant 容器後，用【同一個 client】呼叫（關鍵步驟）：
   呼叫#3: ✅ 成功 -> collections=[]

結論：同一個 client 在 Qdrant 回來後【自動恢復】。
      => 『連線池快取失效連線』的推測不成立。
```

環境：`qdrant-client 1.18.0`、`httpx 0.28.1`（conda env `ai-service` 實際安裝版本）。

同時注意步驟③重現出了與測試時完全相同的錯誤訊息 `[WinError 10061] 無法連線，因為目標電腦
拒絕連線`。這個錯誤是 TCP 層的 **ECONNREFUSED**，語意是「對這個位址發起新連線、但沒有東西
在聽」——它只會在**真的沒人在 6333 監聽**時出現。快取的失效連線會產生別種錯誤
（連線被重置／伺服器未回應之類），不會是 10061。也就是說，**測試時看到 10061 就代表當下
Qdrant 確實不在監聽**，而不是連線池的問題。

**證據 2｜原始碼確認：確實沒有任何 retry／reconnect（原待辦 1 的答案）**

- `ai-service/src/rag/vector_store.py:262` 是 `vector_store = QdrantVectorStore()`，
  module 層級全域單例；`:18-21` 在 `__init__` 建立 `QdrantClient(url=..., api_key=...)`，
  **沒有傳 `timeout`，也沒有任何重試參數**，整個 process 生命週期只建一次。
- 往下追 `qdrant-client 1.18.0` 的實作
  （`site-packages/qdrant_client/http/api_client.py:71, 129-136`）：
  `self._client = Client(**kwargs)` 是一個長生命週期 `httpx.Client`；
  發送路徑 `send_inner()` 只是 `self._client.send(request)` 包一層 try/except 轉例外，
  **完全沒有重試邏輯**（只有 429 有特別處理，而且也只是換個例外拋出）。

所以「沒有 retry 機制」這個觀察是**正確的**。但證據 1 證明：因為 httpx 的連線池本來就會
淘汰失效連線、自動開新連線，**沒有 retry 不等於無法恢復**。原推測把這兩件事混為一談了。

**證據 3｜真正的根因（一）：collection 只在服務啟動時建立一次，失敗還被吞掉**

grep 全 `ai-service` 的 `create_collection` 呼叫點，**live 的只有 `app.py:40, 43, 46` 三行，
全部位於 `@app.on_event("startup")` 內**：

```python
# app.py:33-51
@app.on_event("startup")
async def startup_event():
    try:
        if not vector_store.create_collection(config.CHARACTER_COLLECTION, vector_size=768):
            raise Exception(f"Failed to create collection: {config.CHARACTER_COLLECTION}")
        ...
    except Exception as e:
        print(f"❌ [app.py] RAG 集合初始化失敗: {e}")   # ← 只印出來，然後就繼續啟動
```

（`src/repositories/rag_repository.py:69-71` 也有一個 `create_collection`，但 grep 確認
**零呼叫點，是死代碼**，不構成第二條建立路徑。）

這條證據非常關鍵，它直接解釋了測試時看到的現象：

1. 錯誤訊息 `Failed to create collection: characters` 字面上就來自 `app.py:41`，
   **只可能在服務啟動時印出**，不可能是執行期反覆重試在噴。
2. `except` 只 `print` 不 `raise`，所以 **Qdrant 掛掉時 ai-service 照樣啟動成功**，
   只是三個 collection 一個都沒建起來，而且**執行期永遠不會再補建**。
3. 因此「重啟 Qdrant 但不重啟 ai-service」對 collection 缺失的狀態毫無幫助——
   不是因為連不上，而是因為**根本沒有任何程式碼會再去建它**。

**證據 4｜真正的根因（二）：`/health` 完全不檢查 Qdrant，健康狀態是假的**

```python
# app.py:89-96
@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "ai-service", ...}   # 純字典，沒碰 Qdrant
```

`vector_store.py:233-248` 明明有寫好的 `check_connection()`。grep 全服務後，它的參照鏈是：

```
vector_store.check_connection()          # :233  實作
  ↑ rag_repository.check_connection()    # :58   薄包裝 → 0 個呼叫點（死代碼）
  ↑ rag_service.check_rag_health()       # :21   薄包裝 → 0 個呼叫點（死代碼）
```

也就是說：**函式本身有被兩個包裝函式參照，但那兩個包裝函式都沒有任何人呼叫**，
整條鏈從未被執行。所以 ai-service 在「collection 全缺、RAG 完全不能用」的狀態下，
`/health` 依然回 `{"status":"ok"}`。`start-all-services.bat` 與任何監控都因此看不出異常
——這正是為什麼問題只能靠使用者聊天失敗才被發現。

**附帶查到的文件與實作落差**：`rag_service.py:44-46, 57-58` 的 docstring 明寫初始化流程是
「1. 【新增】檢查 RAG 資料庫連接（同步，立即）／2. 如果不可用，立即返回 failed（HTTP 503）」，
但 `initialize_conversation()` 的實際實作（`:60-84`）**直接標記 pending 並啟動背景線程，
沒有做任何連線檢查**。文件描述的 fail-fast 行為並不存在。這解釋了 `check_rag_health()`
為何是死代碼——它應該是在這裡被呼叫的，但呼叫點後來消失了（或從未寫進去）。
**這是本次調查順帶發現、與原 bug 相關但獨立的問題，尚未評估影響範圍，先記錄。**

**證據 5｜真正的根因（三）：Qdrant 容器用 `--rm` 啟動，「手動重啟」在技術上做不到**

`start-all-services.bat:62`：

```bat
docker run -d --rm --name qdrant -p 6333:6333 -p 6334:6334 -v qdrant_storage:/qdrant/storage qdrant/qdrant
```

`docker inspect qdrant` 實測目前正在跑的容器：

```
AutoRemove(--rm): true
RestartPolicy   : no
Mounts          : volume:qdrant_storage -> /qdrant/storage
```

`--rm` 代表**容器一停止就會被 Docker 自動刪除**。所以：

- `docker stop qdrant` 之後，容器已經不存在，`docker start qdrant` 必定失敗
  （`No such container: qdrant`）——「手動重啟容器」這個動作**做不到**。
- `RestartPolicy: no` 代表 Docker 也不會自己把它拉回來。
- 要讓它回來只能重新 `docker run` 完整那一長串（**尤其 `-v qdrant_storage:/qdrant/storage`
  不能漏**，漏了就是一個空的資料庫，既有 RAG 資料全部讀不到）。

這完整解釋了「必須用 `start-all-services.bat` 從頭啟動才恢復」：那個 bat 的價值**不是**
重建連線，而是（a）它的 `curl` 探測發現 6333 沒回應，於是**用正確的完整參數重新 `docker run`**
把 Qdrant 真的拉回來；（b）它接著才啟動 ai-service（`:92`，在 Qdrant 的 `:62` 之後），
於是 `startup_event` 重跑一次、**把 collection 重新建起來**。兩件事都不是 ai-service
的連線層在起作用。

**證據 6｜使用者補述的實際操作路徑，直接解釋了 10061（原「尚未證實」欄已結案）**

使用者說明當時的操作**全程是在 Docker Desktop 圖形介面完成的**，不是下指令：

1. 到 **Containers** 頁把 qdrant 容器關掉 → 容器隨即從清單中消失
   （與證據 5 的 `AutoRemove: true` 完全吻合，`--rm` 讓它一停止就被刪除）。
2. 因為容器已經不在了，只好改到 **Images** 頁找到 `qdrant/qdrant` 這個 image，
   從那裡按 ▶ 把它啟動。

關鍵就在第 2 步：**從 Images 頁啟動，開出來的是一個全新的容器，套用的是預設值**——
除非展開 "Optional settings" 手動填，否則**沒有 `-p 6333:6333` 的 port 對應，
也沒有 `-v qdrant_storage:/qdrant/storage` 的資料卷**。

所以容器雖然在跑，它的 6333 卻沒有對應到 host 的 6333，`localhost:6333` **真的沒有東西在聽**。
ai-service 回報的 `[WinError 10061] 目標電腦拒絕連線` 是**字面意義上正確**的 ECONNREFUSED，
與證據 1 實驗步驟③重現出的錯誤是同一回事。

**結論：ai-service「認不到 Qdrant」不是因為它認不出來，是因為回來的根本不是原本那個容器。**
另外要提醒：就算之後補上了 port 對應，只要漏了 `-v qdrant_storage:...`，
拿到的也會是一個空資料庫，既有的 RAG 資料全部讀不到。

**證據 7｜⚠️ 溯源：這三項根因都【不是】任何一輪優化引入的**

使用者提到「優化工程之前並不會發生這樣的事情」。查 `ai-service` 的 git 歷史（它有獨立 repo）
逐 commit 比對後，這個印象**不能歸咎於優化**：

| 根因 | 最早出現 | 是否為優化引入 |
|------|---------|---------------|
| `startup_event` 吞掉 collection 建立失敗（證據 3） | `c3cdd47` **2026-06-26**（專案第一個 commit） | ❌ 否，從第一天就在 |
| `/health` 從不檢查 Qdrant（證據 4） | `c3cdd47` **2026-06-26**（同上，逐 commit 檢查皆為 0） | ❌ 否，從第一天就在 |
| 執行期沒有補建 collection 的路徑 | `src/rag/data_loader.py` 曾有 4 處呼叫，於 `74685a7` **2026-07-03** 隨該檔一起消失 | ❌ 否，比優化早三週 |

另外把優化區間（`2a2a43f` 2026-07-14 → HEAD，涵蓋**後端優化** `simplify-ai-service`
與**微服務互連優化** T16 兩輪）的 diff 整份拉出來逐項比對：

**（a）Qdrant 相關檔案完全沒被動過**

```
$ git diff --stat 2a2a43f HEAD -- src/rag/ src/repositories/
 src/repositories/conversation_repository.py | 20 --------------------
```

握有 Qdrant 連線與 collection 邏輯的兩個檔案——`src/rag/vector_store.py` 與
`src/repositories/rag_repository.py`——**一行都沒改**。唯一的異動是刪掉
`conversation_repository.py`（無關的死代碼）。

**（b）`app.py` 的兩個關鍵函式沒被動過**

`app.py` 的改動只有四處：新增 `HTTPException` handler、`CORS allow_origins` 改讀 config、
`root()` 端點清單更新、移除 `reply_controller`。
**`startup_event` 與 `health_check` 這兩個函式的內容一行都沒動過。**

**（c）唯一「看起來有關」的改動，實際上是刪除已停用的死註解**

後端優化那輪確實從 `rag_service.py` 的 `initialize_conversation()` 刪掉了一段健康檢查
程式碼（CLAUDE.md 記為「移除實驗性註解死碼」）。但逐版本追查後確認，**它從進 repo 的
第一天起就是被註解掉的**：

| commit | 日期 | `initialize_conversation()` 內的健康檢查 |
|---|---|---|
| `c3cdd47` | 2026-06-26 | 🔴 完全不存在 |
| `c9a00fd` | 2026-06-29 | 🔴 完全不存在 |
| `989e193` | 2026-07-01 | 🔴 完全不存在 |
| `74685a7` | 2026-07-03 | 🟡 **加進來時就已被註解停用** |
| `3d82544` | 2026-07-08 | 🟡 已被註解停用 |
| `d58a34c` | 2026-07-09 | 🟡 已被註解停用 |
| `2a2a43f` | 2026-07-14 | 🟡 已被註解停用 |
| `4b8d7f3` | 2026-07-25 | 🔴 註解文字被刪除（**後端優化**） |
| `9272cb5` | 2026-07-26 | 🔴 完全不存在 |

被註解的那段自己寫著原因：
`# 🆕 【實驗性註解】暫時停用健檢觸發，觀察無健檢時錯誤是否仍能正確傳播`。

也就是說，**這個 fail-fast 健康檢查在專案歷史上從來沒有生效過任何一天**。
後端優化刪掉的是一段早已失效的註解文字，**行為零改變**。

**（d）優化唯一該負的責任（很小，且不是 Bug 4 的成因）**

刪掉那段註解後，`initialize_conversation()` 的 docstring 仍寫著
「1. 檢查 RAG 資料庫連接（同步，立即）／2. 不可用就回 failed（503）」，
而唯一能解釋「為什麼沒做」的線索（那段自帶原因的註解）不見了。
文件與實作不符的狀況**在優化之前就已存在**（註解期間就對不上），優化只是讓它**更難被發現**。
這是真的、但很小的一筆帳，且與 Bug 4 的三項根因無關。

**證據 8｜⚠️ 更正證據 7：觸發條件確實是「佈署優化」引入的（`--rm`）**

> **這裡先記一筆調查失誤。** 證據 7 原本寫「`start-all-services.bat` 的 `--rm` 也不是優化
> 引入，因為該檔第一個 commit 就有這行」。這個推論**方法上是錯的**：那個檔案本身就是佈署
> 優化的產物，「它從第一版就有 `--rm`」當然成立，卻完全沒有回答真正該問的問題——
> **在這個檔案存在之前，Qdrant 是怎麼被啟動的？** 使用者指出「之前這樣測過不會有問題」
> 之後才回頭補查，結論反轉。

**（a）佈署優化之前，官方文件教的啟動方式沒有 `--rm`**

`ai-service/RAG_SETUP.md` 從優化前（`2a2a43f`）到現在，記載的啟動指令一字未改：

```bash
docker run -p 6333:6333 -p 6334:6334 \
  -v qdrant_storage:/qdrant/storage \
  qdrant/qdrant
```

**沒有 `--rm`、沒有 `--name`。** 這樣起的容器停掉之後**會留在 Containers 清單裡**，
`docker start`（或 Docker Desktop UI 的 ▶）會把**同一個容器**原樣復活，
port 對應與資料卷全都還在——ai-service 隨即自動重連（證據 1 已實驗證明連線層本來就會恢復）。
**這正是使用者記憶中「以前這樣測不會有問題」的狀態。**

**（b）`start-all-services.bat` 是佈署優化新建的檔案，且一建立就帶 `--rm`**

```
$ git show 4d1a704 -- start-all-services.bat
new file mode 100644                    ← 新檔案，不是修改
+docker run -d --rm --name qdrant -p 6333:6333 -p 6334:6334 -v qdrant_storage:/qdrant/storage qdrant/qdrant
```

`4d1a704`（**2026-07-23**）正是同源部署／Caddy 那一輪的 commit，標題與內文寫得很清楚：

> `Start Caddy from the .bat scripts; the old flow no longer works`
> 「Since the same-origin migration the frontends call the API with relative paths,
> so opening a Vite port directly is broken」

也就是說，這一輪**同時做了兩件事**：把 Qdrant 改成 `--rm` 的拋棄式容器，
並且讓「不透過這支 bat 的舊啟動方式」失效，等於強制所有人改走這條新路徑。

**（c）因果鏈**

| 層次 | 內容 | 來自 |
|---|---|---|
| **觸發條件** | Qdrant 容器加上 `--rm` → 一停止就被刪除 → 使用者只能從 Images 頁重開 → 得到一個**沒有 port 對應、沒有資料卷**的全新容器 → `localhost:6333` 真的沒人在聽 | **佈署優化**，`4d1a704`，2026-07-23 |
| **放大器** | collection 只在 startup 建、失敗被吞、`/health` 說謊 → 即使把 Qdrant 正確拉回來，ai-service 也不會自己補建 collection，必須整套重啟 | **專案第一天就有**（2026-06-26 / 07-03），非任何優化引入 |

**兩者缺一，這個 bug 都不會以「必須整套重啟」的形式出現**：
- 沒有 `--rm`（優化前）→ stop/start 同一個容器，一切照舊，三項缺陷永遠潛伏不發作。
- 沒有那三項缺陷 → 就算容器被刪、重建正確的新容器後，ai-service 也能自己恢復。

**所以「是哪一輪造成的」的答案是：佈署優化（2026-07-23）改變了 Qdrant 容器的生命週期，
把一個潛伏兩個月的缺陷推到了檯面上。** 後端優化（`simplify-ai-service`）與微服務互連優化
（T16）皆已逐項排除，見證據 7 的 (a)(b)(c)(d)。

**修法對照**：這也證實了待辦 5（拿掉 `--rm`）不是「順手改善」，而是**直接回復到出問題前的
狀態**，應該優先做；待辦 2/3/4（ai-service 那三項）則是把潛伏了兩個月的缺陷一併補掉。

**修法評估（依證據重寫，取代原待辦 2）**

原待辦 2 想做的「每次請求檢查連線健康度並視需要重建 client」「加 retry with backoff」
**方向是錯的**——證據 1 已證明 client 本來就會自己恢復，做這些不會解決任何實際問題。
依證據，真正該做的是：

1. **讓 collection 的建立不再只發生在啟動時**，或至少在 RAG 操作前確保它存在
   （證據 3）。這是最核心的一項。
2. **`startup_event` 不要吞例外**：Qdrant 不可用時要嘛讓服務啟動失敗、要嘛明確標記為
   unhealthy，不要假裝啟動成功（證據 3）。
3. **`/health` 接上已經寫好但沒人用的 `check_connection()`**，讓健康狀態反映真實情況
   （證據 4）。
4. **檢討 `start-all-services.bat:62` 的 `--rm`**：改成不加 `--rm`（容器可 `docker start`
   重啟）或加 `--restart unless-stopped`，讓「重啟 Qdrant」成為一個做得到的動作
   （證據 5）。

- [x] ~~**待辦 1**：讀 `ai-service` 裡建立 Qdrant client 的程式碼，確認連線是否為啟動時
  建立一次就不再重建、有無 retry/reconnect 機制。~~
  → **調查完成（證據 2）**：是啟動時建立一次的全域單例，且確實沒有任何 retry／reconnect。
  但**這不是本問題的根因**——證據 1 證明沒有 retry 也能自動恢復。
- [x] ~~**待辦 2**（依調查重寫）：修 collection 建立時機——不要只在 `app.py` 的 `startup_event`
  建一次。~~ → **已完成（A 方案）**：新增冪等的 `ensure_collection()`/`ensure_collections()`，
  6 個呼叫點涵蓋所有讀寫路徑（含 `rag_repository` 三處繞過封裝層的直接 client 操作）。
- [x] ~~**待辦 3**（依調查重寫）：`app.py:50-51` 不要吞掉 startup 失敗。~~
  → **決定不做，採 D 方案（維持不 crash）**，由使用者拍板。理由：讓服務啟動依賴 Qdrant
  就緒會違反 12-Factor IX Disposability（`start-all-services.bat` 只 `timeout 3` 就啟動
  ai-service，Qdrant 慢一點整個服務就起不來，且沒有自動重啟機制）。改成吞得起——
  有待辦 2 會在執行期補建、有待辦 4 讓狀態看得見，吞例外不再是永久傷害。
- [x] ~~**待辦 4**（依調查新增）：`app.py:89-96` 的 `/health` 接上既有的健康檢查
  （`rag_service.check_rag_health()` → `vector_store.check_connection()`，整條鏈已寫好但
  從未被呼叫，見證據 4）。順便決定 `rag_service.py:44-46` docstring 承諾但未實作的
  「初始化前同步檢查連線、不可用就回 failed」要補上還是把 docstring 改掉。~~
  → **已完成（B 方案）**：整條鏈接上，Qdrant 不可達回 503 `degraded`。
  docstring 落差**選擇改 docstring、不補實作**——補 fail-fast 會與 D 方案的方向打架
  （一個說「依賴沒好就別動」，一個說「依賴沒好也要能起來、之後自己恢復」）。
  已改寫 `initialize_conversation()` 的 docstring 為與實作一致，並註明即時健康狀態
  改看 `GET /health`。
- [x] ~~**待辦 5**（依調查新增，**依證據 6 提高優先度**）：`start-all-services.bat:62` 的 Qdrant
  容器移除 `--rm` 或改用 `--restart unless-stopped`，讓容器可以被單獨重啟。~~
  → **已完成（C 方案）**：`--rm` 移除、改 `--restart unless-stopped`，並改成先試
  `docker start`、失敗才 `docker run`（拿掉 `--rm` 之後容器會留在清單裡，直接 `docker run`
  同名會失敗——這是新出現的情況，已實跑兩次驗證）。
  ⚠️ **改的是兩支腳本**：`start-all-services.bat:57-79` 與 `start-backend-services.bat:57-80`。
  第一次只修了前者，漏掉後者（見「已修復」區塊 C 段的說明），已補齊。
  ⚠️ **這不會追溯改變機器上已經在跑的舊 `--rm` 容器**，見上方「已修復」區塊最後一段。
- [x] ~~**待辦 7**（依證據 6 新增，**在修好待辦 5 之前的臨時作法**）：不要從 Docker Desktop 的
  Images 頁啟動 Qdrant。容器不見了就直接重跑一次 `start-all-services.bat`
  （它的 `curl` 探測會發現 6333 沒回應，並用完整正確的參數重新 `docker run`），
  或手動下完整指令：
  ```
  docker run -d --rm --name qdrant -p 6333:6333 -p 6334:6334 -v qdrant_storage:/qdrant/storage qdrant/qdrant
  ```
  **`-v qdrant_storage:/qdrant/storage` 絕對不能漏**，漏了會得到一個空資料庫，
  既有 RAG 資料全部讀不到。且拉起 Qdrant 後仍須重啟 ai-service 一次（證據 3：
  collection 只在 startup 建立）。
  → **待辦 5 修好後這條臨時作法已不需要**。修好之後：容器 stop 不會消失，`docker start`
  或 Docker Desktop Containers 頁的 ▶ 都能原樣復活；且**不必再重啟 ai-service**
  （collection 會在執行期補建）。仍然要記得：**不要從 Images 頁啟動**，那永遠會產生一個
  沒有 port 對應、沒有資料卷的新容器。
- [x] **待辦 6**：修完後重新測試。**驗證步驟依證據調整**：不要只做「重啟 Qdrant 看有沒有恢復」
  （證據 1 已證明連線層本來就會恢復，這樣測會誤判成已修好）。要測的是
  「**Qdrant 完全停掉的期間啟動 ai-service**」→ 確認 `/health` 回報不健康（不是 `ok`）→
  再把 Qdrant 拉回來 → 確認 collection 有被補建、聊天功能自動恢復，**全程不重啟 ai-service**。
  → **✅ 2026-07-27 已完成真人瀏覽器實測**：
  * Qdrant 停止 → ai-service 重啟 → `/health` 回 503 degraded（**B 方案驗證**） ✅
  * `docker start qdrant` → `/health` 自動回 200 ok（不重啟 ai-service）（**A 方案驗證**） ✅
  * 新建聊天室→聊天恢復正常（collection 自動補建）（**A 方案完整驗證**） ✅
  * C 方案（bat 改 `--restart unless-stopped`）已於構建階段驗證通過 ✅

---

## 第二輪：2026-07-27 手動測試新發現的問題（尚未修復）

> 以下 4 項是接續完成《前端網頁手動測試task.md》第五～八階段測試時新發現的，**皆尚未修復**，
> 只記錄現象、根因與（如適用）與《前端系統設計原則》的對照，修法與是否修復留給使用者決定。
> 與第 1～4 項不同，這裡沒有另外寫可執行的重現腳本，根因判斷依據是直接讀原始碼比對真人瀏覽器
> 實測時的實際反應（Console 訊息、畫面截圖）得出。

### Bug 5：重啟聊天室時「建立新聊天室」步驟逾時失敗，不會顯示 toast，卡在懸浮層

> ### ✅ 已修復（2026-07-27）
>
> **改動**：`persona-nexus-chat/src/chat.js:599-602`，把逾時失敗的 `return` 改成 `throw`，
> 讓這條路徑統一走到外層 `catch`（第 615-619 行）：
>
> ```js
> if (!conversation) {
>   // 建立失敗或超時：丟給外層 catch 統一處理（toast + 解除懸浮層），
>   // 不要在這裡 return——否則永遠走不到 catch，toast 架構上不可能顯示。
>   throw new Error('聊天室建立失敗，請重新整理頁面再試');
> }
> ```
>
> 沿用《前端網頁debug_task_checklist.md》原記載的修法建議（DRY：不另外維護第二套
> 「懸浮層 vs. toast」失敗呈現邏輯），`catch` 區塊本來就會用 `error.message` 組 toast
> 文字，所以錯誤文字沿用同一句，使用者會同時看到 toast「重啟失敗：聊天室建立失敗，
> 請重新整理頁面再試」與 `hideInitializing()` 解除懸浮層、重新啟用輸入框。
>
> **驗證狀態**：
> - ✅ `node --check`：語法正確
> - ✅ 用 Node 完整重現修復後的控制流程（`pollForConversation` 回傳 `null`）：
>   `toastCalled: true`、`hideInitializing called: true`（輸入框會被重新啟用），
>   與修復前的驗證腳本（`toastCalled: false`）對照，證實這條路徑現在確實會走到 catch
> - ✅ `npm run build` 通過（13 modules，chat 是完整多入口建置，涵蓋本次改動）
> - ✅ **2026-07-27 已完成瀏覽器回歸測試**（Playwright 自動化無頭 Chromium，非真人肉身操作，
>   見文件開頭「一句話現況」的說明）：用 `page.route()` 攔截建立聊天室的輪詢請求回 503
>   （與逾時走同一個 `return null` 分支），實測 toast 正確顯示「重啟失敗: 聊天室建立失敗，
>   請重新整理頁面再試」、3.5 秒後自動消失、懸浮層解除、輸入框恢復可用，不需整頁重新整理。
>   對應《前端網頁手動測試task.md》第九階段 9.1。

- **服務**：`persona-nexus-chat`
- **檔案**：`src/chat.js:599-603`（`restartBtn` click handler 內「步驟 2：建立新聊天室」）
- **嚴重度**：中——只在使用者重啟聊天室、且後端剛好在「建立新聊天室」這一步失敗/逾時時觸發，
  但一旦發生，畫面會卡在「聊天室建立失敗」的懸浮層、輸入框永久停用，只能整頁重新整理才能恢復
- **現象**：點 ♻️ → 確認 → 顯示「聊天室重啟中...」→ 刪除舊聊天室成功 → 顯示「聊天室準備
  中...」開始建立新聊天室 → 此時若後端不可達（實測：按下確定的瞬間關閉 chat-service），
  輪詢逾時後畫面顯示「聊天室建立失敗，請重新整理頁面再試」（沿用建立聊天室共用的置中懸浮層
  文字），**沒有 toast**，也沒有呼叫 `hideInitializing()`，輸入框維持停用。
- **根因**：
  ```js
  // chat.js:596-603
  showInitializing('聊天室準備中...');
  const conversation = await pollForConversation(characterId);

  if (!conversation) {
    // 建立失敗或超時：維持懸浮層並顯示錯誤
    showInitializing('聊天室建立失敗，請重新整理頁面再試');
    return;                          // ← 直接跳出整個 async 函式
  }
  ```
  `pollForConversation()` 逾時時回傳 falsy（不是 `throw`），這裡對此直接 `return`，跳出整個
  click handler 的 async 函式，永遠不會執行到後面第 615 行的 `catch` 區塊，因此
  `showToast('重啟失敗: ...')`（第 617 行）在這條路徑上架構上就不可能被呼叫到。只有
  「刪除舊聊天室失敗」（第 589-591 行，真的會 `throw`）才會走到 catch → 顯示 toast。
- **判定**：先前 debug 輪次修 `alert()`→toast 時沒覆蓋到的漏網路徑，不在原本 4 個已知
  bug 名單內。**沒有復發 `alert()`**，但沒有達成「重啟失敗顯示 toast」的預期行為。
- **可能修法（待使用者拍板，未動手）**：把第 599-602 行的 `return` 改成 `throw`（例如
  `throw new Error('聊天室建立失敗，請重新整理頁面再試')`），讓這條路徑統一走到 catch，
  同時顯示 toast 與呼叫 `hideInitializing()`，行為與其他失敗路徑一致（DRY：不用維護
  兩套「懸浮層 vs. toast」的失敗呈現邏輯）。
- **驗證狀態**：✅ 2026-07-27 真人瀏覽器實測重現（見《前端網頁手動測試task.md》5.6）。
  ✅ 已修復（見上方「已修復」區塊），✅ 2026-07-27 已完成 Playwright 自動化瀏覽器回歸測試
  （見上方「已修復」區塊末段與《前端網頁手動測試task.md》9.1）。

### 🔍 修復前重新核對（2026-07-27，開始修復前）

**結論：根因確認成立，程式碼與上方記載逐字相符，無漂移。**

讀取現行 `persona-nexus-chat/src/chat.js:574-621`（`restartBtn` click handler）與
`chat.js:225-276`（`pollForConversation()`），確認：
- 第 597-603 行與上方記載逐字相同，`if (!conversation) { showInitializing(...); return; }` 仍在。
- `pollForConversation()` 的三個失敗分支（503／非預期狀態碼／輪詢逾時，第 261、266、275 行）
  全部 `return null`，全函式**沒有任何 `throw`**，確認逾時只會產生 falsy 回傳值，不會拋例外。

用 Node 完整重現 `chat.js:574-621` 的控制流程（`pollForConversation` 換成回傳 `null` 的
stub，其餘邏輯逐字照抄），實際執行後：

```
toastCalled: false
hideInitializing (正常結束路徑) called: false
```

證實 `return`（chat.js:602）確實不會被外層 `try/catch`（:576/:615）攔截，`catch` 區塊
（含第 617 行的 `showToast()`）在這條路徑上**架構上不可能執行到**，與原記載完全吻合。
不需修改重現腳本即可驗證，過程未啟動任何服務。

### Bug 6：編輯頁未帶 `?id=` 參數時，lobby 路由 gate 靜默轉向回首頁，沒有任何錯誤提示

> ### ✅ 已修復（2026-07-27）
>
> **改動**：`persona-nexus-lobby/src/main.js`，把 `/my-characters/edit` 拆成獨立分支，
> 缺 `id` 時不再落到通用的「無法辨識路徑」fallback，而是先回首頁、再顯示明確錯誤訊息：
>
> ```js
> if (pathname === '/my-characters/edit') {
>   if (params.get('id')) {
>     const { loadCharacterEditPage } = await import('./character-edit.js');
>     await loadCharacterEditPage(params.get('id'), { replace: true });
>     return;
>   }
>   // 已知路徑但缺少必要的 id 參數：不要靜默轉向，顯示訊息後再回首頁
>   // （在 loadHomePage() 之後才顯示，這樣抓到的是 home.html 自帶的
>   // #message-box，不會在 body 上留下第二個重複 id 的訊息框）
>   await loadHomePage();
>   history.replaceState({ page: 'home' }, '', '/');
>   showMessage('error', '❌ 缺少角色 ID，請從「我的角色」清單進入編輯頁。', 4000);
>   return;
> }
> ```
>
> **順序刻意選在 `loadHomePage()` 之後才呼叫 `showMessage()`**：`home.html` 樣板自帶
> `<div id="message-box">`（`home.js:3, 81` 已在用），若在 `loadHomePage()` 之前呼叫，
> `message-utils.js` 的 `getMessageBox()` 會因為當下抓不到既有的 `#message-box` 而在
> `document.body` 上另外新建一個，造成畫面上出現兩個重複 `id` 的訊息框——這正是「調查／
> 修復中順帶發現」第 2 項提到的同型結構問題，這裡刻意避開，不多引入一個新案例。
>
> **規格已先行更新**（SOP 貫穿原則 #6）：`openspec/specs/lobby-ui/spec.md` 在〈路由還原〉
> 需求新增「訪問編輯頁但缺少必要的 id 參數」Scenario，與既有「導向無法辨識的路徑」
> Scenario 並列且說明差異（已知路徑缺參數 vs. 完全無法辨識）。`openspec validate --all` 2/2 全綠。
>
> **驗證狀態**：
> - ✅ `node --check`：語法正確
> - ✅ `npm run build` 通過（19 modules，lobby 是完整多入口建置，涵蓋本次改動）
> - ✅ `openspec validate --all` 2/2 全綠
> - ✅ **2026-07-27 已完成瀏覽器回歸測試**（Playwright 自動化無頭 Chromium）：訪問
>   `http://localhost:8080/my-characters/edit`（不帶 `id`），實測落地首頁、正確顯示
>   「❌ 缺少角色 ID，請從「我的角色」清單進入編輯頁。」、3 秒內自動隱藏、Console 無異常，
>   且未出現重複 `#message-box` 的副作用；對照組（帶正確 `id`）仍正常運作。
>   對應《前端網頁手動測試task.md》第九階段 9.2。

- **服務**：`persona-nexus-lobby`（根因）／`persona-nexus-character`（受影響但自身邏輯正確）
- **檔案**：`persona-nexus-lobby/src/main.js:68`（`restoreRouteFromUrl()`）
- **嚴重度**：低中——只在使用者手動改網址、直接訪問編輯頁但缺少 `id` 參數這種非典型操作路徑
  觸發，不影響正常操作流程；但體驗上完全沒有回饋，使用者不會知道發生了什麼事
- **現象**：直接在網址列輸入 `http://localhost:8080/my-characters/edit`（不帶 `id`）並
  Enter，畫面**靜默轉向回首頁**，沒有出現任何錯誤訊息或提示，也不知道正確進入編輯頁的方式
  （應從角色列表進入）。
- **根因**：
  ```js
  // main.js:67-72
  // /my-characters/edit?id={characterId} — 角色編輯
  if (pathname === '/my-characters/edit' && params.get('id')) {
    const { loadCharacterEditPage } = await import('./character-edit.js');
    await loadCharacterEditPage(params.get('id'), { replace: true });
    return;
  }
  ...
  // 其餘（含 / 本身與任何無法辨識的路徑）一律回首頁
  await loadHomePage();
  ```
  路由判斷要求 `id` 參數為真值才會進入編輯頁流程；不成立時直接落到「其餘一律回首頁」的
  fallback，**連 iframe 都還沒載入**。`persona-nexus-character/src/edit.js:41-43` 確實有寫
  正確的「缺少角色 ID」錯誤訊息邏輯（`messageBox.textContent = '錯誤：缺少角色 ID，請從角色
  列表進入此頁面。'`），但因為 lobby 這一層路由 gate 先攔截，那段邏輯在這條路徑下永遠執行
  不到，形同死碼。
- **與《前端系統設計原則》的關係**：
  - **D 節「錯誤預防與明確回饋」**：靜默轉頁沒有給任何錯誤說明或修正路徑，比顯示一個
    「笨」但清楚的錯誤訊息更差。
  - **D 節「一致性與標準」**：對照《前端網頁手動測試task.md》3.3 節已驗證的案例——瀏覽器
    上一頁回到「id 存在但角色已被刪除」的編輯頁時，`edit.js` 的 404 處理**確實會顯示**
    「✕ 載入失敗，請稍後重試。」錯誤訊息。同樣是「進不了編輯頁」的情境（id 缺失 vs. id
    存在但角色不存在），兩條路徑的使用者體驗完全不一致。
- **可能修法（待使用者拍板，未動手）**：讓 `main.js` 的 fallback 邏輯區分「完全無法辨識的
  路徑」與「已知路徑但缺少必要參數」兩種情況，後者應先顯示訊息（例如複用
  `message-utils.js` 的 `showMessage`）再導頁，而非靜默轉向。
- **驗證狀態**：✅ 2026-07-27 真人瀏覽器實測重現（見《前端網頁手動測試task.md》6.1）。
  ✅ 已修復（見上方「已修復」區塊），✅ 2026-07-27 已完成 Playwright 自動化瀏覽器回歸測試
  （見上方「已修復」區塊末段與《前端網頁手動測試task.md》9.2）。

### 🔍 修復前重新核對（2026-07-27，開始修復前）

**結論：根因確認成立，程式碼與上方記載逐字相符，無漂移。**

讀取現行 `persona-nexus-lobby/src/main.js` 全檔（134 行）確認：
- 第 68 行 `if (pathname === '/my-characters/edit' && params.get('id'))` 與記載相同，
  仍要求 `id` 為真值才進入編輯頁分支。
- 第 89-91 行「其餘（含 `/` 本身與任何無法辨識的路徑）一律回首頁」的 fallback
  （`await loadHomePage(); history.replaceState(...)`）與記載相同，中間沒有任何
  區分「已知路徑缺參數」與「完全無法辨識路徑」的邏輯，也沒有呼叫
  `message-utils.js` 顯示任何提示。
確認 `params.get('id')` 為 `null`（URL 無 `id` 查詢參數時 `URLSearchParams.get()`
的標準回傳值）在 JS 中即為 falsy，`&&` 短路後整個 if 判斷為 false，直接落到
第 89 行的 fallback——這是 JS 語言規格層級的行為，非推測。

### Bug 7：角色卡片「⋮」選單「編輯」選項無法用鍵盤（Enter/Space）觸發

> ### ✅ 已修復（2026-07-27，兩處都修）
>
> **改動**：`my-character.js:60-77`（編輯選項）與 `conversation-history.js:18-33`
> （刪除選項）都補上 `keydown` 監聽器，判斷 `Enter`／`Space` 時呼叫與 `click` 相同的
> 處理函式（抽成具名函式 `activateEditOption()`/`activateDeleteOption()`，`click` 與
> `keydown` 共用，避免複製一份邏輯）：
>
> ```js
> editOption.addEventListener('click', activateEditOption);
> // <div tabindex="0"> 不像原生 <button> 會在 Enter/Space 自動觸發 click，需自行補上
> editOption.addEventListener('keydown', (e) => {
>   if (e.key === 'Enter' || e.key === ' ') {
>     e.preventDefault();
>     activateEditOption();
>   }
> });
> ```
>
> **選了「補 keydown」而非「改用原生 `<button>`」這個備案**：`style.css:279-293` 有一條
> 全域 `button {}` 規則（綠底、粗體、`padding: 12px 24px`），`.conversation-menu-item`
> 目前只覆蓋 `padding`/`color`/`font-size`/`cursor`/`transition`，沒有覆蓋
> `background-color`/`border`/`font-weight`，若改用 `<button>` 會被全域樣式污染，
> 需要額外補一批 CSS override 才能維持原本外觀，且視覺結果無法在目前環境下用瀏覽器
> 覆核。補 `keydown` 純粹是行為層修法，零 CSS 風險，範圍最小。
>
> **不需要改規格**：`lobby-ui/spec.md:151`（刪除選項的鍵盤焦點管理 Scenario）本來就寫著
> 「鍵盤使用者可直接按 Enter 確認」——這是既有規格早就承諾、但實作沒做到的行為，
> 這次修復是讓程式碼補上規格已經要求的行為，不是新增或變更可觀察行為，不觸發 SOP
> 貫穿原則 #6。
>
> **驗證狀態**：
> - ✅ `node --check`：兩檔語法正確
> - ✅ 用最小 DOM stub 逐字複製修復後的 `keydown` 判斷邏輯實測：
>   `Enter`／`Space` 觸發 2/2，`Tab`／其餘按鍵不觸發（0 次），`preventDefault()` 只在
>   觸發時呼叫（2 次）
> - ✅ `npm run build` 通過（19 modules，lobby 是完整多入口建置，涵蓋本次改動）
> - ✅ `openspec validate --all` 2/2 全綠（未變更 spec，確認沒有連帶弄壞既有規格）
> - ✅ **2026-07-27 已完成瀏覽器回歸測試**（Playwright 自動化無頭 Chromium），兩處、
>   Enter 與 Space 共 4 條路徑全過：編輯選項開選單後焦點正確落在「編輯」，Enter／Space
>   皆成功進入編輯頁；側邊欄刪除選項（**首次實測**）開選單後焦點正確落在「刪除」，
>   Enter／Space 皆正確跳出 `confirm()` 對話框。對應《前端網頁手動測試task.md》第九階段 9.3。

- **服務**：`persona-nexus-lobby`
- **檔案**：`src/my-character.js:60-69`（編輯選項）；同一套寫法也出現在
  `src/conversation-history.js:18-22`（側邊欄對話歷史的「刪除」選項，**未實測，但程式碼
  結構相同，判斷會有同樣問題**）
- **嚴重度**：中——違反 WCAG 可操作性，鍵盤使用者（含螢幕報讀器使用者）完全無法透過
  「⋮」選單完成編輯角色這條路徑
- **現象**：純鍵盤操作「我的角色」清單頁——Tab 移到某張角色卡片的「⋮」選單按鈕、按 Enter
  開啟選單後，焦點確實自動移到「編輯」選項，但接著按 Enter **沒有任何反應**，無法進入編輯頁，
  鍵盤操作在此卡住。建立新角色的流程純鍵盤操作沒有問題，問題只出在「既有角色的編輯入口」。
- **根因**：
  ```js
  // my-character.js:60-69
  const editOption = document.createElement('div');
  editOption.className = 'conversation-menu-item';
  editOption.textContent = '✏️ 編輯';
  editOption.setAttribute('tabindex', '0');
  editOption.addEventListener('click', async () => { ... });
  ```
  `editOption` 是用 `<div>` 建立、加 `tabindex="0"`（讓它能被 Tab 移入焦點），只綁了
  `click` 監聽器，沒有另外綁 `keydown` 處理 Enter/Space。瀏覽器只有原生 `<button>` 元素
  會在 Enter/Space 按下時自動觸發 `click`；`<div>` 加 `tabindex` 只解決「能不能被 Tab
  移入」，並不會讓鍵盤按鍵自動等效於滑鼠點擊，這裡遺漏了後者。
  `conversation-history.js:18-22` 的 `deleteOption` 是逐字相同的寫法（同樣
  `createElement('div')` + `tabindex="0"` + 只綁 `click`）。
- **與《前端系統設計原則》的關係**：D 節 WCAG——「互動元素（tab 切換、按鈕）是否能用鍵盤
  （Tab / Enter）操作，而不是只在滑鼠點擊時綁事件」，這裡正是只綁了滑鼠事件的案例。
- **可能修法（待使用者拍板，未動手）**：兩處擇一，且**兩個檔案要一起修**，避免修一次漏一次：
  1. 補上 `keydown` 監聽器（判斷 `e.key === 'Enter' || e.key === ' '` 時執行同一段邏輯）
  2. 改用原生 `<button>` 取代 `<div tabindex="0">`（更符合「最低能力原則」，順便拿到瀏覽器
     原生的鍵盤等效行為與內建的可及性語意，不用自己補）
- **驗證狀態**：✅ 2026-07-27 真人瀏覽器實測重現「編輯」選項（見《前端網頁手動測試task.md》
  6.3）。「刪除」選項（`conversation-history.js`）當時**未實測**，僅依程式碼結構判斷同樣有問題。
  ✅ 已修復（見上方「已修復」區塊，兩處都修），✅ 2026-07-27 已完成 Playwright 自動化瀏覽器
  回歸測試（見上方「已修復」區塊末段與《前端網頁手動測試task.md》9.3）——「刪除」選項首次
  實測，Enter/Space 皆正確跳出 `confirm()`。

### 🔍 修復前重新核對（2026-07-27，開始修復前）

**結論：根因確認成立，程式碼與上方記載逐字相符，無漂移；「刪除」選項仍維持未實測狀態，
不升格為已證實。**

讀取現行 `persona-nexus-lobby/src/my-character.js:60-69`（編輯選項）與
`conversation-history.js:18-22`（刪除選項）：
- 兩處都是 `document.createElement('div')` + `setAttribute('tabindex', '0')`，
  且**全檔案搜尋 `keydown`/`keyup` 無任何命中**——確認 lobby 全專案沒有任何程式碼
  幫這兩個 `<div>` 補上鍵盤等效觸發邏輯。
- 兩處各自只綁了一個 `addEventListener('click', ...)`，與記載逐字相同。

依 WHATWG HTML 規格，Enter/Space 觸發 `click` 事件的自動等效行為（activation behavior）
只定義在原生互動元素（如 `<button>`、`<a href>`）上；一般 `<div>` 加 `tabindex` 只讓它能
被鍵盤移入焦點，不會取得這個自動等效行為，需要額外綁 `keydown` 才能補上——這不是本專案
特有的臆測，是 HTML 標準行為。「編輯」選項已有 2026-07-27 真人瀏覽器實測佐證（見上方
「驗證狀態」）；「刪除」選項因結構完全相同（同一套 `createElement('div')` +
`tabindex` + 純 `click`），依 HTML 標準判斷會有同樣結果，但**仍未經真人操作驗證**，
維持標記為未實測，不寫成已證實結論。

### Bug 8：lobby 的 `/api/config` 失敗時缺一個提前結束執行的判斷，導致後續對已清空 DOM 操作拋出未捕捉例外

> ### ✅ 已修復（2026-07-27）
>
> **改動**：`persona-nexus-lobby/src/main.js` 整段初始化邏輯包成 `async function init()`，
> `configLoadError` 分支顯示錯誤訊息後立刻 `return` 中止：
>
> ```js
> if (configLoadError) {
>   document.body.innerHTML = '<div ...>❌ 無法連線至服務器，請稍後重試。</div>';
>   // body 已被整個換掉，後面的登入檢查、initSidebar() 都會操作已不存在的
>   // DOM 節點（例如 #sidebar-container），必須在此中止，不能繼續往下執行。
>   return;
> }
> ```
>
> **為什麼要包成函式**：`main.js` 是 `type="module"`（`index.html:28`），ES module 頂層
> 不允許 `return`，這是唯一能提前結束的方式。包函式之外的邏輯（登入檢查、`initSidebar()`、
> `restoreRouteFromUrl()`、history 追蹤、`popstate` 監聽）逐字保留，只是整體往內縮一層，
> 沒有變更任何其他行為。
>
> **不需要改規格**：`openspec/specs/lobby-ui/spec.md:83, 92`〈頁面初始化與設定載入〉
> 早就寫著「若探測失敗，系統 MUST 顯示連線失敗訊息並停止後續初始化」——這次修復是讓
> 程式碼補上規格本來就要求、但實作沒做到的行為，跟 Bug 7 是同一種情況（規格先於程式碼
> 存在），不觸發 SOP 貫穿原則 #6。
>
> **副作用揭露（不自行篩選，如實記錄）**：修復前，`configLoadError` 為真且**未登入**時，
> 原本的程式碼會先寫入錯誤訊息，接著仍執行到第 40 行的 `if (!userId)` 分支並
> `window.location.href` 導向 `/login/`，等於錯誤畫面一閃即逝、隨即跳轉登入頁。
> 修復後這條路徑會停在錯誤畫面，不再跳轉登入頁。這是原本程式碼從未刻意設計、也沒有
> 出現在任何規格或測試記錄裡的偶然行為，修復後的「停在錯誤畫面」與規格
> 「停止後續初始化」的字面要求更相符，但視為行為變動的一部分，在此如實揭露。
>
> **順帶觀察到、與本次修復無關的建置警告**：`npm run build` 這次多印出一行
> `[INEFFECTIVE_DYNAMIC_IMPORT] src/home.js is dynamically imported ... but also
> statically imported`。追查後確認 `home.js` 在 `main.js` 頂部就有靜態 `import`（供
> `else` 分支的 fallback 使用），`popstate` 監聽器內又對同一個檔案做了一次動態
> `import()`（本次未改動這行），這個靜態＋動態重複匯入的結構在改動前就已存在；
> 這次只是把外層程式碼包進 `init()` 函式，改變了 Vite 對可達性的分析方式，才讓原本
> 沒被標記的重複匯入被印出警告。純屬建置期的最佳化提示，不影響任何執行期行為，
> 也不是本次修復引入的新問題，依範圍限制本次未處理。
>
> **驗證狀態**：
> - ✅ `node --check`：語法正確
> - ✅ 用 Node 重現 `init()` 精簡版控制流程（`loadConfig()` 拋錯模擬 config 探測失敗）：
>   `initSidebarCalled: false`，證實提前 `return` 確實擋下了 `initSidebar()` 呼叫
> - ✅ `npm run build` 通過（19 modules，lobby 是完整多入口建置，涵蓋本次改動）
> - ✅ `openspec validate --all` 2/2 全綠
> - ✅ **2026-07-27 已完成瀏覽器回歸測試**（Playwright 自動化無頭 Chromium）：分別對
>   `/my-characters/create`（原觸發路徑）與 `/`（回頭補測 7.5）封鎖 `/api/config`，兩者畫面
>   皆正確整頁替換為錯誤文字，且 Console 都**沒有**出現 `TypeError: Cannot set properties
>   of null`，也沒有任何未捕捉例外——確認 7.5 當時的疑慮不成立。對應《前端網頁手動測試
>   task.md》第九階段 9.4。

- **服務**：`persona-nexus-lobby`
- **檔案**：`src/main.js:21-23`（`configLoadError` 分支）、`:43`（`initSidebar()` 呼叫點）
- **嚴重度**：低——視覺上使用者看到的錯誤畫面沒有壞（錯誤文字在崩潰前已寫入 DOM），但
  Console 會留下一個未捕捉例外，影響開發除錯，也代表《前端網頁手動測試task.md》第八階段
  「Console 無非預期錯誤」這項判定可能有漏網之魚
- **現象**：在已登入狀態下，任何 lobby 路由（實測於 `/my-characters/create`）若
  `/api/config` 失敗，畫面正確顯示「❌ 無法連線至服務器，請稍後重試。」，但 Console 同時
  出現：
  ```
  Uncaught TypeError: Cannot set properties of null (setting 'innerHTML')
    at initSidebar (sidebar.js:46:30)
    at async main.js:43:3
  ```
- **根因**：
  ```js
  // main.js:21-23
  if (configLoadError) {
    document.body.innerHTML = '<div>...❌ 無法連線至服務器，請稍後重試。</div>';
  }
  // ⚠️ 沒有 return/中止，執行繼續往下走

  const userId = getCurrentUserId();
  if (!userId) {
    window.location.href = `${LOGIN_APP_URL}/`;
  } else {
    await initSidebar();   // ← :43，這裡才真正炸掉
  ```
  把 `document.body.innerHTML` 換成錯誤訊息之後，程式碼沒有停下來，仍會繼續執行到
  `initSidebar()`；但這時候 `<body>` 已經被整個換掉，`initSidebar()` 要找的側邊欄容器
  元素不存在，對 `null` 設 `innerHTML` 直接拋出未捕捉例外。
- **附帶提醒**：這代表《前端網頁手動測試task.md》第八階段「全程操作中 Console 分頁沒有
  出現非預期的 JS 錯誤」這項的判定可能需要修正——7.5 測「封鎖 `/api/config` → 整頁替換
  錯誤訊息」時（同樣是登入狀態下 `/api/config` 失敗的情境），很可能也悄悄觸發了同一個例外，
  只是當時只檢查了畫面文字對不對，沒有特別去查 Console。
- **可能修法（待使用者拍板，未動手）**：在 `configLoadError` 分支顯示錯誤訊息後，確保後續
  程式碼不再執行（例如把整段初始化邏輯包成一個函式，`configLoadError` 為真時提早 `return`
  略過剩餘的登入檢查與 `initSidebar()` 呼叫）。
- **驗證狀態**：✅ 2026-07-27 真人瀏覽器實測重現（Console 截圖）。
  ✅ 已修復（見上方「已修復」區塊），✅ 2026-07-27 已完成 Playwright 自動化瀏覽器回歸測試
  （見上方「已修復」區塊末段與《前端網頁手動測試task.md》9.4）。

### 🔍 修復前重新核對（2026-07-27，開始修復前）

**結論：根因確認成立，程式碼與上方記載逐字相符，無漂移。**

讀取現行 `persona-nexus-lobby/src/main.js:1-134` 全檔與 `sidebar.js:39-46`：
- `main.js:21-23` 的 `configLoadError` 分支與記載相同，設完 `document.body.innerHTML`
  後**沒有 `return` 或任何中止語句**，往下第 37 行 `getCurrentUserId()`、
  第 39-43 行的 if/else 都會照常執行。
- `sidebar.js:39` 的 `initSidebar()` 第 43 行
  `const sidebarContainer = document.getElementById('sidebar-container');`，
  第 46 行 `sidebarContainer.innerHTML = html;`——`#sidebar-container` 是原本
  `<body>` 底下的元素，`configLoadError` 分支已把整個 `body.innerHTML` 換掉，
  此時 `getElementById('sidebar-container')` 必為 `null`，與記載一致。

用 Node 直接執行 `sidebarContainer = null; sidebarContainer.innerHTML = '...'`：

```
TypeError: Cannot set properties of null (setting 'innerHTML')
```

與《前端網頁手動測試task.md》記錄的 Console 錯誤文字**逐字相同**，確認因果鏈成立，
不是巧合或另一個原因造成的類似錯誤。

---

## 完成後的收尾動作

- [x] 四個 bug 全部修完並各自重新實測通過後，回到《前端網頁手動測試task.md》繼續未完成的
      測試階段（第五階段剩餘部分 → 第六～八階段）。
      → **已完成（2026-07-27）**：第五～八階段全部測完，過程中新發現第 5～8 項問題（見上方
      「第二輪」章節），已同步記錄到《前端網頁手動測試task.md》對應測項與文末「發現的新問題」。
- [ ] 视情况評估是否需要把這些 bug 的修復記錄回對應服務的 `openspec/specs/*/spec.md`
      與 `mistake.md`（依循先前 SOP 的「規格是單一真相」慣例）。
- [x] 把本輪調查修正掉的三項錯誤描述同步回《前端網頁手動測試task.md》文末「發現的新問題」
      （該文件目前仍記載著舊版說法）：第 1 項要補上 `edit.js` 的兩處、第 4 項要拿掉
      「蓋掉錯誤訊息」、第 3 項要拿掉「連線池快取失效連線」。
- [x] 第 5～8 項已於 2026-07-27 完成修復前根因重新核對＋程式碼修復（比照第 1～4 項流程：
      先重新核對根因 → 改規格（Bug 6 新增 Scenario；Bug 7／8 確認規格早已要求、程式碼補上
      即可，不需改規格）→ 改程式碼 → `node --check`／控制流程重現腳本／`npm run build`／
      `openspec validate` 全數通過）。
- [x] 第 5～8 項已於 2026-07-27 完成瀏覽器回歸測試（見《前端網頁手動測試task.md》第九階段
      9.1～9.4，四項全過）。啟動方式：Docker Desktop + PowerShell `Start-Process` 逐一啟動
      9 個 dev server（`start-all-services.bat` 內建的 `start cmd /k` 在自動化環境下失敗，
      改用此法），用 Playwright 驅動無頭 Chromium 實測。
- [ ] **新增**：本輪是 **Playwright 自動化瀏覽器測試**，不是真人肉身操作（差異見上方「一句話
      現況」）。若使用者需要針對可及性等主觀體感另外安排一輪真人複測，可直接沿用第九階段
      9.1～9.4 的測項清單。

---

## 調查／修復中順帶發現（不在原本四個 bug 範圍內，未處理，僅記錄）

依先前回饋，這裡一律平等列出，不自行判斷範圍或優先度。

1. **`persona-nexus-character` 的正式建置漏掉兩個主頁面**
   `vite.config.js` 沒有設定 `build.rollupOptions.input` 多頁入口，`npm run build` 只編譯
   `index.html`（7 modules），**`creator-create.html` 與 `creator-edit.html` 這兩個真正的
   主頁面完全沒有進 `dist/`**（實測 `ls dist/` 只有 `index.html` + assets）。
   目前走 dev server + Caddy 所以沒被發現。兩個影響：（a）正式建置產物是不完整的；
   （b）**`npm run build` 對這兩個檔案沒有任何驗證效力**，修改 `create.js`／`edit.js`
   後不能拿 build 通過當成驗證。與《前端系統設計原則》C 節「建置產物精簡」相關但方向相反
   ——這是該進去的東西沒進去。
2. **`persona-nexus-lobby` 的 `message-utils.js` 有與 Bug 2 同型的結構問題**
   在 `chat.html`／`character-edit.html` 這兩個不自帶 `#message-box` 的頁面上，
   訊息框會被 `document.body.appendChild()` 成 body 級單例、不隨導頁清除，
   且 `conversation-history.js:33` 的刪除失敗訊息未傳 `autoHideMs`。詳見 Bug 2 證據 5。
   尚未實測觸發。已如實記入 `lobby-ui/spec.md` 的 as-is 規格。
3. ~~**`ai-service` 的 `rag_service.py` docstring 與實作不符**~~
   docstring 承諾初始化前會「同步檢查 RAG 資料庫連接、不可用就回 failed（503）」，
   實作沒有做。詳見 Bug 4 證據 4。
   → **已於 Bug 4 一併修掉**（使用者勾選）：改 docstring 使其與實作一致，不補 fail-fast 實作
   （補了會與 D 方案的 Disposability 方向打架），並註明即時健康狀態改看 `GET /health`。
4. **Caddy 容器也還是 `--rm`**（本次修 Bug 4 時順帶看到）
   `start-all-services.bat:144` 與 `start-frontend-services.bat:38` 的 `nexus-caddy`，
   與 Qdrant 修改前是同一個寫法，同樣會「一停就消失」。影響比 Qdrant 小——Caddy 沒有
   資料卷，重建不會掉資料，重跑 bat 就會回來——所以**本次沒有動它**（使用者這次勾選的
   範圍只有 Qdrant）。要不要一併改由使用者決定。
6. **三支啟動腳本有大量重複區塊**（本次踩到才發現）
   `start-all-services.bat` = `start-backend-services.bat` + `start-frontend-services.bat`
   的內容複製貼上，Ollama/Qdrant/Caddy 三個區塊各存在兩份。這正是 C 方案第一次只修一半的
   原因。要根本解決得把共用區塊抽成獨立的 `.bat` 由三支互相 `call`，屬結構調整，未做。
5. **ai-service 的 `/health` 沒有逾時保護**（本次修 B 時確認）
   `QdrantClient` 建立時沒傳 `timeout`（`vector_store.py:18-21`），所以若 Qdrant「連得上但
   不回應」（而非拒絕連線），`/health` 會一直等。實務上不致命：唯一的呼叫端
   `chat-service/src/lib/serviceClient.js:88` 自己設了 5 秒 timeout，逾時同樣被視為不健康。
   另外本服務所有端點都是 `async def` 卻呼叫同步阻塞的 Qdrant/Ollama 程式碼，
   這是既有的全服務性問題，**不在本次範圍**，未動。
7. **`persona-nexus-chat` 的 `protagonistModal.js` 有一段實際上不可能被觸發的防禦性 guard**
   （2026-07-27 補測《前端網頁手動測試task.md》5.4「對話室未就緒時開啟彈窗」時發現）
   `openModal()` 開頭的 `if (!conversationId) { showToast('聊天室尚未就緒'); return; }`，
   用 `page.route()` 延遲對話室就緒輪詢、在「conversationId 尚未設定」的空窗期分別用滑鼠
   `.click()`、鍵盤 `focus()+Enter`、原生 `btn.click()` 三種方式觸發 `#protagonistBtn`，
   結果：
   - 滑鼠 `.click()`：`.initializing-overlay`（`style.css:439-450`，`z-index:1000`，
     沒有 `pointer-events:none`）在對話室未就緒期間會完全覆蓋整個畫面，Playwright 判定按鈕
     當下不可點擊而自動等待，等到的時候輪詢早已完成——**真人滑鼠在這個時間窗根本點不到
     這顆按鈕**。
   - 鍵盤 `focus()+Enter`／原生 `btn.click()`：兩者都繞開了 overlay 的視覺阻擋，但彈窗依然
     沒開、也沒有跳出 toast。追查 `chat.js:624` 發現 `initProtagonistModal(...)`（掛上
     `protagonistBtn` 的 `click` 監聽器）是在 `initializeChat()` 輪詢**成功之後**才呼叫——
     對話室未就緒之前，這顆按鈕根本沒有綁定任何點擊事件，點了是純粹的 no-op。
   結論：這段 guard 在目前的呼叫順序下是**實際上不可能被觸發到的防禦性程式碼**，不論滑鼠或
   鍵盤都沒有機會走到它。不影響任何實際功能（使用者感覺不到差異），是否要一併整理掉留給
   使用者判斷，本次僅記錄，未動手改。

---

## 調查方法備註（供日後重現）

本輪四項調查用到的手法，記在這裡是因為它們不需要啟動整套服務就能驗證，日後排查同類問題可直接沿用：

- **四個前端各自有獨立的巢狀 git repo**，平台根目錄的 `git` 看不到它們的改動。
  要看前端的 diff 必須 `git -C persona-nexus-<name> diff`。這點在 Bug 1 一度讓
  `git diff` 查無結果，容易誤判成「沒有改動」。
- **URL 拼接問題**用 Node 的 `new URL(href, base)` 驗證即可——它就是瀏覽器用的
  WHATWG URL 規則，比在瀏覽器裡手動點一次更快也更精確（Bug 1 證據 2）。
- **前端純邏輯模組**（如 `virtualMessageList.js`）可以用最小 DOM stub 在 Node 裡直接
  `import` 真檔案來跑，不需要 jsdom、不需要啟動 Vite，秒級就能拿到真實堆疊（Bug 3 證據 1）。
- **要驗證某個外部依賴的行為**（如 qdrant-client 斷線後會不會自動恢復），開一個
  **不同 port 的拋棄式容器**做對照實驗，不要動正在跑的環境（Bug 4 證據 1）。
- **看到某條錯誤訊息，先 grep 它的字面來源**再推論。Bug 4 就是靠這招發現
  `Failed to create collection` 只可能在 startup 印出，一舉推翻了「執行期反覆重試」的想像。
- **「以前不會這樣」不能直接當成迴歸的證據，但也不能當成雜訊丟掉**。Bug 4 兩邊都踩到了：
  逐 commit 比對確實排除了三項 ai-service 根因（早於各輪優化），但我一度因此整個否定
  使用者的記憶，結果漏掉真正的觸發條件。判斷「是不是這輪弄壞的」要用
  `git show <commit>:<file>` 逐版本比對，不要靠印象；同時**使用者說「以前不會」時，
  要當成一條待查線索追到底**，而不是拿 git 證據把它否掉就算了。
- **⚠️ 查「某個設定是不是這輪引入的」時，不能只看該檔案自己的 git 歷史。**
  Bug 4 就是這樣查錯的：看到 `start-all-services.bat` 第一個 commit 就有 `--rm`，
  便下結論「不是優化引入」——但**那個檔案本身就是該輪優化新建的產物**，
  這個推論等於什麼都沒證明。正確問法是「**在這個檔案存在之前，這件事是怎麼做的？**」
  （答案在 `ai-service/RAG_SETUP.md`：原本的指令沒有 `--rm`）。
  遇到 `new file mode` 的 commit 尤其要警覺，一定要去別處找舊做法的痕跡（文件、README、
  其他腳本）。
- **問清楚使用者實際做了什麼操作**。Bug 4 卡在「手動重啟 Qdrant」這句話上很久，
  直到問出是「從 Docker Desktop 的 Images 頁按 ▶」才真相大白——同樣一句「重啟容器」，
  用指令做和用 UI 做，結果天差地遠。
