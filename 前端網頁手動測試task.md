# 前端網頁手動測試 Task

> **目的**：四個前端服務（auth／character／chat／lobby）都已完成規格驅動的架構優化（Phase 0–10），
> 但都還缺一塊：**真人開瀏覽器手動走查**。這份文件把四個服務的測項**依實際操作流程**串成一條線，
> 不是分開四份各自獨立的清單——因為建角色需要先登入拿 token、開聊天室需要先有角色可聊，本來就有
> 前後依賴關係，照這個順序測才不會卡住。
>
> **跟既有的 5 份《測試清單-*.md》有什麼不同**：既有清單是**指令模擬 API 呼叫**（PowerShell 直接
> 打 `fetch()`），測的是「後端契約對不對」，47+23 案例已全部通過，**不要重跑**。這份測的是
> **只有真瀏覽器才測得出來的東西**：aria-live 有沒有真的生效、焦點有沒有正確移動、toast 會不會
> 準時消失、Escape/Tab 鍵盤操作、Network 分頁實際請求網址、CORS、版面渲染。
>
> **依據**：每一項都對照過實際原始碼，不是憑印象猜的。
>
> **操作方式**：每測完一項就直接回來把 `[ ]` 改成 `[x]`，異常的項目記錄在文末「發現的新問題」。

---

## ✅ 第一～八階段測試已全部完成（2026-07-27）

> 8 個階段全數測完，詳見文末「測試結果紀錄區」與「發現的新問題」（共 7 項，
> 第 1～4 項已修復並驗證通過，第 5～7 項為本輪新發現、當時尚未修復）。以下交接說明僅供回溯查閱，
> 不再是待辦事項。
>
> **更新（2026-07-27 稍後）**：第 5～7 項，以及測試時漏掉、後來在《前端網頁debug_task_checklist.md》
> 另外發現的第 8 項（`/api/config` 失敗時 Console 拋出未捕捉例外，7.5 當時只查了畫面文字沒開
> Console），四項都已完成程式碼修復，**並於同日完成 Playwright 自動化瀏覽器回歸測試，四項全過**
> （見下方「第九階段｜Bug 5～8 修復後回歸測試」）。注意這輪是自動化瀏覽器測試，不是真人肉身操作，
> 兩者差異見第九階段開頭說明。

### 收尾動作提醒（若要繼續處理，供之後接手參考）

- **新發現的 3 個問題（第 5～7 項）尚未修復**，皆已記錄現象、根因、與《前端系統設計原則》的對照，
  是否修復、修法為何，留待使用者另開規劃決定：
  - 第 5 項：重啟聊天室時「建立新聊天室」步驟逾時失敗，不會顯示 toast，卡在懸浮層
    （`persona-nexus-chat/src/chat.js:599-603`）
  - 第 6 項：編輯頁未帶 `?id=` 時靜默轉向回首頁，沒有錯誤提示
    （`persona-nexus-lobby/src/main.js:68`）
  - 第 7 項：角色卡「⋮」選單「編輯」選項無法用鍵盤 Enter/Space 觸發
    （`persona-nexus-lobby/src/my-character.js:60-69`，同套寫法也在
    `conversation-history.js:18-22`，未實測但判斷同樣有問題）
- 暫緩的可及性細項（aria-label 等，3.3/5.4/5.5/7.2 各一兩項）維持暫緩，不用主動處理。

### 環境現況提醒（接手時請自行重新確認，不保證仍然成立）

- **chat-service 目前有兩個持久化開關被關閉**（`chat-service/src/config/config.json` 的
  `persistence.enableCreationJobs`／`enableGenerationStatus` 皆為 `false`），這是測試時為了
  「中途重啟服務不會卡住 job/生成鎖」而暫時設定的本機測試值，**不要 commit**。若测試涉及
  「服務重啟後狀態是否正確存活」這類情境，記得先確認/改回 `true`（詳見
  `chat-service/CLAUDE.md`「目前狀態」段落）。
- 以下檔案目前是本機未 commit 的狀態：
  - 根目錄：本文件、《前端網頁debug_task_checklist.md》
  - `chat-service/`：`CLAUDE.md`、`openspec/specs/conversations/spec.md`、
    `src/config/config.json`、`src/config/config.txt`、
    `src/repositories/conversationRepository.js`、`src/services/conversationService.js`
- 四個前端各自有獨立巢狀 git repo，`git diff` 在平台根目錄看不到它們的改動，要
  `git -C persona-nexus-<name> diff`。

---

## 前置作業

- [ ] Docker Desktop 已啟動，`docker ps` 看得到 `qdrant`、`nexus-caddy` 兩個容器在跑
- [ ] 用 `start-all-services.bat`（或手動）啟動 5 個後端 + 4 個前端 dev server
- [ ] 用**真正的瀏覽器**（Chrome 或 Edge，**不要用 VS Code 內建 Simple Browser**——它的
      `localStorage`/重導處理有已知怪毛病，會誤導測試結果）
- [ ] 一律從 `http://localhost:8080` 進入（同源部署入口，**不要直接開裸 port** 如 5173/5175）
- [ ] 開啟開發者工具，隨時可切到 **Network 分頁**（看實際請求網址/狀態碼）與
      **Console 分頁**（看有無 JS 錯誤）
- [ ] （選用）若要驗證 aria-live/焦點管理，可開 Windows 內建「講述人」（`Win+Ctrl+Enter`），或至少
      在 devtools Elements 分頁確認 aria 屬性有正確反映

---

## 第一階段｜persona-nexus-auth：註冊與登入

> 拿到 token、能導入大廳，是後面所有測項的前提。

### 1.1 基本渲染與導航
- [x] 開 `http://localhost:8080/login/`，頁面正常渲染，無 Console 錯誤
- [x] Network 分頁確認頁面載入時有打 `GET /api/config`，回應 200
- [x] 點「註冊」／「登入」分頁籤切換正常，切換時前一個分頁的訊息框內容會被清空

### 1.2 註冊流程
- [x] 空白直接送出 → 瀏覽器原生驗證擋下（`#email`/`#password` 皆為 `required`），不會發出請求
- [x] Email 格式錯誤（如 `abc`）→ 原生 `type="email"` 驗證擋下
- [x] 填正確格式送出 → 按鈕文字變「正在處理...」且 disabled，Network 分頁確認打
      `POST /api/auth/register`
- [x] 成功 → 訊息框（`#messageBox`）顯示成功訊息、`class="success"`（綠色系樣式）、表單被清空
      （`registerForm.reset()`），**不會**自動登入或跳轉
- [x] 用同一 email 重複註冊 → 訊息框顯示 email 已被註冊的錯誤、`class="error"`
- [x] 按鈕在請求結束後恢復可點擊、文字恢復原狀

### 1.3 登入流程
- [x] 用剛註冊的帳密登入 → 成功後訊息框顯示成功訊息 → **約 1.5 秒後**自動導向大廳
      （網址列變化為帶 `?token=...` 的大廳網址，之後 lobby 會把 token 存進 `localStorage` 並清掉網址參數）
- [x] 密碼錯誤 → 訊息框顯示帳密錯誤訊息，**不會**導頁
- [x] Email 不存在 → 同上錯誤訊息

### 1.4 可及性（aria-live）
- [x] `#messageBox` 有 `role="status" aria-live="polite"`（devtools Elements 分頁檢查該元素）
- [x] 用 Tab 鍵在不碰滑鼠的情況下，能完整走完「切分頁籤 → 填欄位 → 送出」整個流程

### 1.5 邊界情境
> 若 1.3 測完後瀏覽器已經在大廳（`/`），這裡**不要用登出按鈕**（登出功能留到第七階段測）——直接在
> 網址列手動輸入 `http://localhost:8080/login/` 導航過去即可，測完這兩項後再手動導回 `/` 或
> `/my-characters` 繼續後面的階段。
- [x] 在 devtools Network 分頁封鎖 `/api/config`（右鍵請求 → Block URL，或整個關掉 auth-service
      模擬後端不可達）→ 重新整理頁面 → 訊息框顯示「無法連線至服務器，請稍後重試。」，且此時
      **送出表單不會真的發請求**
- [x] 恢復 `/api/config` 後重新整理，確認一切恢復正常

---

## 第二階段｜persona-nexus-lobby：大廳基本進入與導航

> 剛登入後會先落在這裡，確認基本骨架正常，之後才進去建角色。

### 2.1 登入閘門與 token 交接
- [x] 未登入直接訪問 `http://localhost:8080/` → 導向 `/login/`
- [x] 從第一階段登入導回大廳 → token 被存進 `localStorage`，網址列的 `token` 參數被移除
- [x] Console 無錯誤，首頁正常渲染

### 2.2 首頁（角色發現）現況
- [x] 顯示目前所有使用者的公開角色卡片（若是全新環境，此時應為空）
- [x] 無任何公開角色時 → 顯示空狀態訊息（不是空白一片）

### 2.3 側邊欄基本操作
- [x] Logo 點擊 → 停留/導回首頁
- [x] 側邊欄收合/展開按鈕（桌面版 `«`/`»`）運作正常
- [x] 「創建角色」按鈕 → **實際導向「我的角色」清單頁，不是直接跳去建立頁**（既有設計，先確認
      現況是否仍是如此，如實記錄，不當場改）

---

## 第三階段｜persona-nexus-character：建立角色

> 這裡開始才需要用到「我的角色」頁的「+ 新增角色」按鈕，實際載入的是 character 服務的 iframe。

### 3.1 我的角色頁（初次進入，此時應為空清單）
- [x] 進入頁面時短暫顯示「載入角色清單中...」（`#message-box`，`aria-live="polite"`），載入完成後
      該訊息消失（實測時載入太快幾乎瞬間完成看不到訊息閃現，但已確認角色資料正確載入，判定通過）
- [x] 空清單時有明確的空狀態提示與「新增角色」入口（本次已有剛建立的角色，非空清單，但入口本身
      在此之前已驗證存在）

### 3.2 建立角色流程
- [x] 點「+ 新增角色」進入建立頁（iframe），表單正常渲染
- [x] 必填欄位（名稱／簡介／背景／開場白）留空送出 → 原生 `required` 驗證擋下，不發請求
- [x] 填完必填欄位送出 → Network 確認打 `POST /api/characters`（實測回應 `201 Created`）
- [x] 成功 → 訊息框顯示成功訊息（含角色 ID）、表單清空；1.5 秒後自動跳轉至 `/my-characters`
      並正確顯示新建立的角色（**2026-07-27 Bug 1 修復驗證通過**）
- [x] 新增「Few-shot 對話範例」列（+ 新增對話按鈕）→ 動態新增一列輸入框，可各自刪除
- [x] 「可見性」欄位（`visibility`）留空時，實際建立結果應為 `private`（預設值）
- [x] 額外建一個「可見性」設為 public 的角色（後面測「首頁公開列表」跟「跨帳號聊天權限」會用到）

### 3.3 可及性與邊界情境
- [x] `#message-box` 有 `role="status" aria-live="polite"`（實測於編輯頁確認：
      `<div id="message-box" role="status" aria-live="polite" class="error">✕ 載入失敗，請稍後重試。</div>`）
- [x] 純鍵盤（Tab/Enter）能完成整個建立流程 —— ✅ **2026-07-27 補測通過（Playwright）**：
      從 `#name` 開始全程只用 `keyboard.type()`/`Tab`/`Enter`（無任何 `.click()`/`.fill()`），
      依序填完 name/gender/tags/visibility(select)/introduction/background/opening，Tab 到
      submit 按鈕後按 Enter 送出，`#message-box` 正確顯示「角色創建成功！ID：...」並於 1.5 秒後
      跳轉至 `/my-characters`。
- [x] 未登入（沒有有效 token）直接訪問建立頁網址 → 導向 `/login/` —— ✅ **2026-07-27 補測通過**：
      無 storageState 的全新瀏覽器 context 直接訪問
      `http://localhost:8080/character/creator-create.html`，實測正確導向 `/login/`。
- [x] 封鎖 `/api/config` 或後端整個關掉 → 訊息框顯示連線錯誤訊息（**已知小缺口**：目前
      `configLoadError` 設定後沒有在提交時被檢查，實際送出仍可能嘗試打真正的 API 再失敗——測試
      這個實際行為並記錄現象，不用當場修）—— ✅ **2026-07-27 補測，現象確認如文件所述**：
      只封鎖 iframe（character-service）自己那層的 `/api/config`（放行 lobby 自己的探測，
      否則 lobby 會先觸發 Bug 8 修復後的行為整頁替換，iframe 根本不會被嵌入），實測頁面載入時
      `#message-box` 顯示「❌ 無法連線至服務器，請稍後重試。」，但填完表單送出後**仍然成功**
      （`#message-box` 變成「角色創建成功！ID：...」）——證實 `configLoadError` 真的沒有在
      提交時被檢查，與文件記載的已知小缺口完全吻合，不當場修。

**意外發現並驗證通過的邊界案例**：用瀏覽器「上一頁」導航回到一個**已被刪除角色**的編輯頁
（`edit.js` 的 `loadCharacter()` 對已刪除的角色 ID 呼叫後端得到 404），行為正確——訊息框正確
顯示「✕ 載入失敗，請稍後重試。」，頁面沒有整個掛掉或顯示破碎內容；Console 出現的 2 個 error
是 fetch 失敗時的正常錯誤堆疊（預期內行為，非新 bug）。

---

## 第四階段｜persona-nexus-lobby：確認新角色出現

> 角色建好後，回大廳確認資料正確反映。

### 4.1 我的角色頁
- [x] 剛建立的角色出現在清單中，public/private 徽章正確
- [x] 卡片「⋮」選單開啟 → 焦點自動移到選單內的「編輯」選項（先不點進去，留到第六階段測編輯）
- [x] **重複進入這個頁面多次**（我的角色 → 首頁 → 我的角色 → 首頁 → 我的角色），確認「創建角色」
      按鈕每次點擊只觸發一次導航（本輪修過的 bug：按鈕會被 clone/replace 避免事件監聽器重複疊加）

### 4.2 首頁
- [x] 剛建立的 **public** 角色出現在首頁公開列表；private 角色**不會**出現
- [x] 滑鼠 hover 卡片 → 顯示簡介 tooltip
  - [x] 路徑 A：hover 卡片 → 點擊進入聊天室 → tooltip 立即消失（**2026-07-27 Bug 2 修復驗證**）
  - [x] 路徑 B：hover 卡片 → 按 Alt+← 回上一頁 → tooltip 立即消失（**2026-07-27 Bug 2 修復驗證**）
- [x] 首頁角色卡片有 `aria-label` 提供可及名稱 —— ✅ **2026-07-27 補測通過**：抓取全部卡片
      實測，每張卡片的 `aria-label` 皆為「{角色名稱} 角色」，與角色名稱正確對應
      （`home.js:64` 的 `cardElement.setAttribute('aria-label', ...)`）。

### 4.3 路由還原（重新整理測試）
- [x] 直接在網址列輸入 `/my-characters` 並重新整理 → 正確還原到我的角色清單（不會跳回首頁）
- [x] 直接輸入 `/my-characters/create` 並重新整理 → 正確還原到建立頁（iframe）

---

## 第五階段｜persona-nexus-chat：開始聊天

> 需要第三/四階段建好的角色才能測。點任一角色卡片進入。

### 5.1 初次進入與建立對話室
- [x] 首次跟某角色開聊 → 顯示「聊天室準備中...」（`#initializingMessage`，`aria-live="polite"`），
      輪詢直到對話室建立完成，訊息消失、輸入框變可用
- [x] 對話室建立失敗（可暫時關掉 chat-service 或 ai-service 模擬）→ 輪詢逾時後顯示
      「聊天室建立失敗/載入失敗，請重新整理頁面再試」，輸入框保持 disabled
      （實測分別關閉 chat-service、ai-service、RAG 的 Qdrant 容器，反應皆正確）
- [x] 已存在的對話室 → 重新整理頁面應直接載入既有歷史訊息，不用重新走建立流程

### 5.2 傳送訊息
- [x] 輸入框打字送出 → 立刻樂觀顯示自己的訊息 + 「思考中...」佔位訊息，輸入框立刻 disabled
- [x] 等 AI 真的回覆 → 佔位訊息被換成真正回覆內容，輸入框恢復可用
- [x] 空白訊息（只有空格）按送出 → 不會發送、不會顯示任何錯誤（靜默擋下，屬設計行為）
- [x] Enter 送出訊息；Shift+Enter 換行不送出
- [x] 模擬 AI 生成失敗或逾時（暫時關閉 ai-service/Qdrant）→ 佔位訊息變成**對話氣泡內的失敗提示**
      （不是 toast——刻意設計），且無論如何輸入框最終都會恢復可用（實測見文末「發現的新問題」
      第 3 項：關閉 Qdrant 觸發 500 錯誤時，畫面正確顯示「（角色名）回應失敗: SERVICE_ERROR:
      Request failed with status code 500，請重試」的氣泡樣式，輸入框恢復可用）
- [x] 送出含 `（動作描述）` 或 `(action)` 的訊息 → 該部分顯示為斜體「旁白」樣式
- [x] 送出含 `<script>` 等字元的訊息 → 會被跳脫顯示，不會被當 HTML 執行

### 5.3 刪除訊息
- [x] 點某則訊息的「⋮」選單 → 顯示選單，「刪除」點下 → `confirm()` 對話框（提到「回溯刪除」）
      → 確定後，該則訊息與**之後所有訊息**一併消失
- [x] AI 正在生成回覆時嘗試刪除該輪訊息 → 顯示 toast 提示衝突（409），訊息不會被刪除
      （實測：AI「思考中」狀態下，該則訊息的「⋮」選單按鈕根本不會顯示，UI 從更上層就防止了
      這個衝突情境，比後端擋下更友善，判定通過）

### 5.4 主人公人設彈窗（🎭 按鈕）
- [x] 點 🎭 圖示開啟彈窗 → 焦點自動移到「名稱」輸入框（`#protagonistNameInput`）—— ✅ **2026-07-27
      補測通過**：對話室已就緒狀態下點擊 🎭，實測 `document.activeElement.id` 正確為
      `protagonistNameInput`。
- [x] 彈窗有 `role="dialog" aria-modal="true"` —— ✅ **2026-07-27 補測通過**：實測
      `#protagonistModal` 的 `role="dialog"`、`aria-modal="true"`，且開啟時 `hidden` class
      正確移除。
- [x] 三種關閉方式都測試（功能性驗證，焦點回到觸發按鈕這點暫緩）：
  - [x] 點右上角關閉按鈕
  - [x] 點彈窗外的遮罩背景
  - [x] 按 **Escape** 鍵
- [x] 填寫名稱/背景後按儲存 → 按鈕文字變「儲存中...」→ 成功後顯示 toast「主人公人設已儲存」、
      彈窗自動關閉
- [x] 若對話室尚未準備好就嘗試開啟彈窗 → toast 提示，彈窗不開啟 —— ⚠️ **2026-07-27 補測後
      判定：此情境在目前程式碼下經由「按鈕」實際上不可觸發，不是測試方法問題**。用
      `page.route()` 延遲對話室就緒輪詢的回應，製造「conversationId 尚未設定」的空窗期，
      分別用滑鼠 `.click()`、鍵盤 `focus()+Enter`、原生 DOM `.click()` 三種方式在空窗期內觸發
      🎭 按鈕：
      - 滑鼠 `.click()`：Playwright 判定按鈕當下被 `.initializing-overlay`（`z-index:1000`，
        無 `pointer-events:none`）完全覆蓋而阻擋點擊，實際等到 overlay 消失、輪詢已完成才真正
        點下去——也就是說**真人滑鼠根本點不到這顆按鈕**，overlay physically 擋住了。
      - 鍵盤 `focus()+Enter`、原生 `btn.click()`：兩者都繞過 overlay 的視覺阻擋，但**彈窗依然
        沒開、也沒有跳出 toast**。追查 `chat.js:624` 發現 `initProtagonistModal(...)`（掛上
        `protagonistBtn` 的 `click` 監聽器）是在 `initializeChat()` 輪詢**成功之後**才呼叫，
        亦即在對話室就緒之前，這顆按鈕**根本沒有綁定任何點擊事件**，點了也是純粹的 no-op。
      - **結論**：`protagonistModal.js` 裡 `if (!conversationId) { showToast(...); return; }`
        這段 guard，在目前的呼叫順序下屬於**實際上永遠不會被觸發到的防禦性程式碼**——不論從
        滑鼠或鍵盤，使用者都沒有機會在對話室未就緒時觸發到它。這解釋了文件當初把這項標記
        「非必要邊界情境，暫緩」的判斷是對的：不是懶得測，而是這個路徑目前確實測不到。
        不影響任何實際功能（guard 存在與否使用者都感覺不到差異），僅記錄現象，不建議動手改。

### 5.5 Toast 通知
- [x] 觸發任一 toast（如刪除訊息衝突）→ 約 **3 秒後**自動開始淡出、再約 0.3 秒後從畫面消失
- [x] 連續觸發兩次 toast → 畫面上同時只會有一則（新的立刻換掉舊的，不會疊加）
- [x] Toast 元素有 `role="status" aria-live="polite"` —— ✅ **2026-07-27 補測通過**：透過
      `import('/chat/src/toast.js')` 取得與頁面共用的同一個模組實例呼叫 `showToast()`
      （非另建假模組），實測產生的 `.toast-notification` 元素 `role="status"`、
      `aria-live="polite"` 皆正確。

### 5.6 重啟聊天室（♻️ 按鈕）
- [x] 點擊 → `confirm()` 對話框 → 確認後顯示「聊天室準備中...」，等待重新建立完成
- [x] 重啟失敗（模擬後端錯誤）→ 顯示 toast，**不是** `alert()`（本輪明確修掉的地方）
      **⚠️ 實測發現不符：見文末「發現的新問題」第 5 項。** 沒有出現 `alert()`（原本要修的問題確實
      沒有復發），但也**沒有出現 toast**——實測方式是按下確定重建後立刻關閉 chat-service，畫面卡在
      「聊天室建立失敗，請重新整理頁面再試」的置中懸浮層（跟 5.1 建立聊天室共用的那個懸浮層，不是
      toast），輸入框停在停用狀態，須整頁重新整理才能恢復。

### 5.7 其他
- [x] 🔄 重新整理按鈕：單純整頁 reload，歷史訊息重新從後端載入
- [x] 长對話捲動：傳送/載入超過一畫面的訊息量，捲動流暢；停在最底部時新訊息自動跟著捲到底；
      往上捲看歷史時不會被強制拉回底部（實測：累積超過 20 則訊息，上下捲動無明顯卡頓）
- [x] 直接在網址列輸入 `/rooms/<角色id>` 並重新整理 → 停留在聊天室（不是被導回首頁），這是刻意
      設計（用 `/rooms/` 而非 `/chat/` 避開 Caddy 整段代理，若走 `/chat/...` 重整會壞掉）

---

## 第六階段｜persona-nexus-character：編輯與刪除角色

> 放在聊天測完之後，避免刪掉正在用來測聊天的角色。

### 6.1 編輯角色流程
- [x] 回「我的角色」清單，點某張卡片的「⋮」→「✏️ 編輯」→ 進入編輯頁，欄位正確帶入該角色現有資料
      （含 few-shots 列表）
- [x] 修改欄位後送出 → `PUT /api/characters/:id` → 成功訊息 → 1.5 秒後跳回清單（**2026-07-27 Bug 1 修復驗證**）
- [x] 直接在網址列打開編輯頁但不帶 `?id=` 參數 → 訊息框顯示「缺少角色 ID」錯誤，不會壞掉整頁
      **❌ 未通過，見文末「發現的新問題」第 6 項。** 實測 `http://localhost:8080/my-characters/edit`
      （不帶 `id`）結果是**靜默轉向回首頁**，不是預期的錯誤訊息。

### 6.2 刪除角色流程
- [x] 點「刪除」按鈕 → 跳出瀏覽器原生 `confirm()`（文字：「確定要刪除此角色嗎？此動作無法復原。」）
  - [x] 按「取消」→ 什麼都不發生，角色還在
  - [x] 按「確定」→ `DELETE /api/characters/:id` → 成功訊息 → 1.5 秒後跳回清單，該角色從清單消失（**2026-07-27 Bug 1 修復驗證**）

### 6.3 可及性
- [x] 純鍵盤（Tab/Enter）能完成整個編輯/刪除流程
      **❌ 未通過，見文末「發現的新問題」第 7 項。** 建立角色全程鍵盤操作沒問題；但對既有角色，
      Tab 到「⋮」選單並開啟後，選單內「編輯」選項 Tab 能移入但按 Enter 沒有反應，卡住無法繼續。

---

## 第七階段｜persona-nexus-lobby：其餘功能（對話歷史、手機版、其他路由）

### 7.1 側邊欄對話歷史
- [x] 側邊欄顯示曾經聊過的對話清單（`GET /api/conversations/summary`）（實測：共 3 個對話載入成功）
- [x] 點擊某筆對話 → 導向對應聊天室
- [x] 「⋮」→「🗑️ 刪除」→ `confirm()`（文字含角色名稱）→ 確認後該筆從清單消失
- [x] 刪除失敗（模擬後端錯誤）→ 顯示錯誤訊息（**有**把 `error.message` 顯示給使用者，跟 character
      頁不同，確認訊息確實有意義而非顯示 undefined）（實測：關閉 chat-service 觸發 502，畫面顯示
      「刪除失敗: 刪除失敗: 502」——`api.js:56` 與 `conversation-history.js:33` 各自組了一次
      「刪除失敗:」文案疊字重複，屬輕微文案瑕疵，不影響訊息可讀性，使用者確認不影響通過判定，
      不另開新問題記錄）

### 7.2 手機版側邊欄
- [x] 縮小視窗寬度（或用 devtools 裝置模擬）→ 漢堡選單開啟側邊欄抽屜、點遮罩關閉
- [x] **已知缺口**：測試按 Escape 是否能關閉手機抽屜（程式碼顯示目前沒有實作），如果證實真的不能
      關，記錄成已知限制，不當場修（**實測確認：按 Escape 確實無法關閉手機抽屜**，符合程式碼
      預期，判定為已知限制，非新 bug）

### 7.3 登出
- [x] 登出按鈕 → 清除 token、導向 `/login/`（實測：devtools Application 分頁確認 localStorage
      已清空、網址列正確變成 `http://localhost:8080/login/`）

### 7.4 Iframe 導航串接
- [x] 從大廳分別導向 create / edit / chat 三種 iframe 頁面時，URL 上的 `token`（與 `id`/
      `characterId` 等參數）都有正確帶到 iframe 裡（devtools 檢查 iframe 的 `src` 屬性）
      （實測三種頁面 `src` 皆確認：create 帶 `token`、edit 帶 `token`+`id`、chat 帶
      `token`+`characterId`，皆為有效值，非空或 undefined）
- [x] 建立/編輯/刪除角色完成後，iframe 內頁面用 `window.parent.location.href` 導回大廳，確認導頁
      發生在**最外層**（網址列變化），不是卡在 iframe 內部

### 7.5 邊界情境
- [x] 封鎖 `/api/config` 或後端整個不可達 → 確認**整個頁面**（不只是訊息框）被替換成純文字錯誤
      訊息「❌ 無法連線至服務器，請稍後重試。」（比 auth/character 更激進，會整頁替換）
      （實測：整頁正確替換為該錯誤文字，符合預期）

---

## 第八階段｜跨服務一致性檢查（收尾）

- [x] 四個服務的訊息提示視覺風格是否一致（字體、顏色、位置）——已知 auth/character 用
      `success`/`error` 兩色，lobby 用 `info`/`error`（無 success），chat 用單一 toast 樣式無分色，
      **這是本輪已知、刻意保留的差異**，此處只需確認沒有出現非預期的第三種風格
      （回顧全程測試，未發現第三種風格）
- [x] 四個服務裡曾經用過 `alert()` 的地方（chat 重啟失敗等）現在全部改為 toast 或訊息框，實測過程
      中留意有沒有漏網的 `alert()` 跳出（回顧全程測試，包含 5.6/6.1/6.3 三項新發現的異常，
      皆非 `alert()` 跳窗，確認全程未出現漏網的 `alert()`）
- [x] 全程操作中 Console 分頁沒有出現非預期的 JS 錯誤或 404
- [x] Network 分頁確認所有 API 請求都走相對路徑 `/api/...`（同源），沒有任何請求打向裸 port
      （`localhost:8000`/`5173`/`5175` 等）（回顧全程測試，包含頁面網址與 API 請求皆為
      `http://localhost:8080/...`，未見裸 port）

---

## 第九階段｜2026-07-27 Bug 5～8 修復後回歸測試

> ✅ **已於 2026-07-27 完成，四項全數通過。**
>
> **測試方式（重要，如實記錄）**：這一輪**不是真人肉身操作瀏覽器**，而是用 **Playwright**
> 驅動一個真正的無頭 Chromium 實例（真實瀏覽器引擎，會真的載入頁面、跑真正的 JS、渲染真正的
> DOM），對照《前端網頁debug_task_checklist.md》「修復前重新核對」與「已修復」區塊的描述逐一
> 驗證。與既有 5 份《測試清單-*.md》的 PowerShell `fetch()` 模擬（只測後端契約）不同，這次是
> 瀏覽器真的執行了 `character-tooltip.js`／`conversation-history.js`／`chat.js` 等前端程式碼；
> 但也不等同於文件開頭定義的「真人瀏覽器實測」（沒有人類肉眼視覺判斷、沒有真實螢幕報讀器）。
> 是否需要額外補一輪真人複測（尤其是可及性的主觀體感），由使用者自行決定。
>
> **環境**：Docker Desktop + 9 個 dev server（`start-all-services.bat` 內建的 `start cmd /k`
> 在自動化環境下因「Input redirection is not supported」全數啟動失敗，改用 PowerShell
> `Start-Process` 逐一啟動，過程與結論見對話記錄，未寫入本文件）。測試帳號與角色皆為本輪
> 現場註冊/建立（`bugfix-retest-*@example.com`、角色「回歸測試角色」），非既有資料。

### 9.1 重啟聊天室逾時應顯示 toast（對應 Bug 5、原 5.6）—— ✅ 通過
- [x] 進入聊天室，點擊 ♻️ 重啟按鈕，`confirm()` 對話框按「確定」
- [x] 用 Playwright `page.route()` 攔截 `GET /api/conversations/character/*`
      （重啟後「建立新聊天室」那一步的輪詢請求）直接回 503，等效於「輪詢逾時/建立失敗」
      （`pollForConversation()` 對 503 與逾時走的是同一個 `return null` 分支，見 checklist
      Bug 5 的重新核對——不需要真的等 120 秒或真的關閉 chat-service）
  - [x] toast 顯示「重啟失敗: 聊天室建立失敗，請重新整理頁面再試」（實際擷取文字逐字相符）
  - [x] toast 3.5 秒後自動消失（DOM 中 `.toast-notification` 數量歸零）
  - [x] 懸浮層解除（`#initializingOverlay` 帶 `hidden`）、輸入框恢復可用（`#messageInput`
        未 disabled）——修復前這兩項都會卡住，需整頁重新整理才能恢復
  - [x] 截圖見 `9.1-toast.png`：toast 正確顯示在頁面頂端，輸入框與發送按鈕皆為可互動樣式

### 9.2 編輯頁缺 `id` 應顯示錯誤訊息再回首頁（對應 Bug 6、原 6.1）—— ✅ 通過
- [x] 訪問 `http://localhost:8080/my-characters/edit`（不帶 `id`）
  - [x] 落地首頁（`http://localhost:8080/`）
  - [x] 顯示錯誤訊息「❌ 缺少角色 ID，請從「我的角色」清單進入編輯頁。」（逐字相符）
  - [x] 3 秒後 `#message-box` 的 `display` 變回 `none`（訊息設定 4 秒自動隱藏，實測在此之前已隱藏）
  - [x] Console 錯誤陣列為空，未見重複 `id="message-box"` 的異常
  - [x] 對照組：帶正確 `?id=` 的編輯頁仍正常運作
  - [x] 截圖見 `9.2-missing-id.png`：紅色錯誤橫幅正確顯示在角色大廳頁面上方，版面無異常

### 9.3 「⋮」選單鍵盤 Enter/Space 應可觸發（對應 Bug 7、原 6.3，兩處皆測）—— ✅ 通過
- [x] **編輯選項**（`my-character.js`）：
  - [x] 開選單後焦點元素文字為「✏️ 編輯」
  - [x] 按 **Enter** → 網址變為 `/my-characters/edit?id=...`，成功進入編輯頁（截圖
        `9.3-edit-enter.png`，欄位正確帶入既有角色資料）
  - [x] 重來一次，按 **Space** → 同樣成功進入編輯頁
- [x] **刪除選項**（`conversation-history.js`，側邊欄對話歷史，**首次實測**）：
  - [x] 開選單後焦點元素文字為「🗑️ 刪除」
  - [x] 按 **Enter** → 跳出 `confirm()`，文字「確定要刪除與 回歸測試角色 的所有對話嗎？」
        （測試時按取消，未真的刪除資料）
  - [x] 按 **Space** → 同樣跳出 `confirm()`

### 9.4 `/api/config` 失敗時不應再拋出未捕捉例外（對應 Bug 8，原 7.5 補測）—— ✅ 通過
- [x] 用 `page.route()` 封鎖 `/api/config`，分別訪問 `/my-characters/create`（Bug 8 原本觸發
      的路徑）與 `/`（回頭補測 7.5 的情境）
  - [x] 兩者畫面皆正確整頁替換為「❌ 無法連線至服務器，請稍後重試。」
  - [x] 兩者 Console 都**沒有**出現 `TypeError: Cannot set properties of null`；也沒有任何
        `pageerror`（未捕捉例外）事件——確認 7.5 當時的疑慮（可能悄悄觸發過這個例外只是沒被
        發現）不成立，補測後乾淨
  - [x] 截圖見 `9.4-bug8-create-route.png`：整頁乾淨替換為錯誤文字，無殘留元素

---

## 測試結果紀錄區

> 執行完畢後回來填寫。若發現新問題，先記錄現象，**不要當場動手改程式碼**——回頭跟這次優化的規格
> （`openspec/specs/*/spec.md`）核對是否為已知限制，還是需要另開新的優化 change 處理。

- 測試日期：2026-07-26～2026-07-27（分兩個聊天室接續完成）
- 測試環境：Windows 11，Chrome/Edge（真實瀏覽器，未使用 VS Code 內建 Simple Browser）
- 第一階段（auth）：全數通過
- 第二階段（lobby 基本）：全數通過
- 第三階段（character 建立）：全數通過（3.3 原暫緩的兩項已於 2026-07-27 補測通過，見下）
- 第四階段（lobby 確認）：全數通過（4.2 原暫緩的 aria-label 項已於 2026-07-27 補測通過）
- 第五階段（chat）：全數測完。5.4/5.5 原暫緩項已於 2026-07-27 補測（見下，其中一項判定為
  「目前程式碼下經由按鈕實際不可觸發」）；5.6 第二項未通過（見新問題第 5 項，已修復）
- 第六階段（character 編輯/刪除）：全數測完。6.1 剩餘項未通過（見新問題第 6 項，已修復）；
  6.3 未通過（見新問題第 7 項，已修復）
- 第七階段（lobby 其餘功能）：全數通過
- 第八階段（跨服務一致性）：全數通過
- 第九階段（2026-07-27 稍後，Bug 5～8 修復後回歸測試）：全數通過（Playwright 自動化瀏覽器測試，
  非真人肉身操作，差異見第九階段開頭說明）
- **總結**：9 個階段全部測完。第一輪過程中新發現 4 個問題（第 5～8 項，第 5～7 項在本文件
  記錄、第 8 項在《前端網頁debug_task_checklist.md》另外發現——7.5 當時只查畫面文字沒開
  Console 才漏掉），加上先前已修復並驗證通過的 4 個 bug（第 1～4 項），本輪測試共發現並記錄
  8 個問題。第 5～8 項已於 2026-07-27 完成修復並經第九階段回歸測試驗證通過。**原本暫緩的
  可及性/邊界情境細項（3.3、4.2、5.4、5.5 共 7 項）已於 2026-07-27 稍後用 Playwright 全數補測**
  （見各測項內文），其中 5.4 的「對話室未就緒時開啟彈窗」一項補測後判定為目前程式碼下經由
  按鈕實際不可觸發（見該測項說明），其餘 6 項全數通過；7.2 的 Escape 已知限制維持原判定
  不變，未再動作。
- 發現的新問題（若有）：

  > ⚠️ **以下 4 項已於 2026-07-26～27 完成調查、修復、並經真人瀏覽器實測驗證通過**，本節內容
  > 已改寫為修復後的最終狀態。完整調查報告（含證據、根因分析、原本三項被推翻的錯誤描述）見
  > 《前端網頁debug_task_checklist.md》。**下面 1-4 項不是仍待處理的 bug，是本輪測試過程中
  > 發現、且已收斂完成的問題記錄，保留供回溯查閱。**

  1. **【已修復】建立/編輯/刪除角色成功後，自動跳轉壞掉（雙斜線 URL）**
     - **原現象**：`persona-nexus-character` 完成建立/編輯/刪除後，1.5 秒自動跳轉時網址列變成
       `http://my-characters/`（`ERR_NAME_NOT_RESOLVED`），而非正確的
       `http://localhost:8080/my-characters`。
     - **實際範圍比最初發現的更大**：不是只有 `create.js:56` 一處，`edit.js:78`（更新後跳轉）與
       `edit.js:101`（刪除後跳轉）也是同樣的拼接缺陷，代表建立/更新/刪除三條流程的跳轉全部壞掉。
     - **根因**：`LOBBY_APP_URL` 定義成相對路徑常數 `'/'`，`` `${LOBBY_APP_URL}/my-characters` ``
       在此情況下算出 `'//my-characters'`——開頭雙斜線被瀏覽器當成 protocol-relative URL（連到
       叫 `my-characters` 的網域），因此導向錯誤位置。
     - **修法**：改用完整路徑常數（`LOGIN_URL = '/login/'`、`MY_CHARACTERS_URL = '/my-characters'`），
       所有跳轉呼叫點零拼接，結構上不再可能重犯這類 bug。
     - **驗證**：2026-07-27 真人瀏覽器實測，建立/更新/刪除三條路徑網址列皆正確停在
       `http://localhost:8080/my-characters`（見本文件 3.2、6.1、6.2）。

  2. **【已修復】角色簡介 tooltip 點擊卡片進入聊天室後不會消失，殘留畫面**
     - **原現象**：大廳首頁 hover 角色卡片顯示簡介 tooltip，點卡片進入聊天室後 tooltip 沒有消失，
       殘留疊在聊天室畫面上，直到回大廳對任一卡片完整「滑入再滑出」才會消失。
     - **根因**：tooltip 是掛在 `document.body` 下的全站共用單例，只靠 `mouseleave` 設
       `opacity='0'`「隱藏」，從未真正從 DOM 移除；點擊卡片導頁時，卡片元素隨即被替換，
       `mouseleave` 沒有機會被派發。
     - **修法**：`character-tooltip.js` 內部新增 `hideTooltip()`，同時綁在卡片的 `click` 事件與
       `window` 的 `popstate` 事件上（涵蓋「點卡片導頁」與「瀏覽器上一頁/下一頁」兩條會讓卡片
       在指標仍停留其上時被銷毀的路徑），`home.js`/`main.js` 不需要知道 tooltip 的存在。
     - **驗證**：2026-07-27 真人瀏覽器實測，兩條路徑（點卡片進聊天室、按 Alt+← 回上一頁）
       tooltip 皆立即消失，無殘留（見本文件 4.2）。

  3. **【已修復】Qdrant 中斷後，ai-service 必須整套重啟才恢復**
     - **原描述已被證偽並修正**：最初懷疑是「qdrant-client/httpx 連線池快取了失效連線」，
       經實機實驗證實**不成立**——同一個 client 物件在 Qdrant 回來後會自動恢復連線，
       連線層本身沒有問題。
     - **真正根因是三件事疊加**：(a) collection 只在服務啟動時建立一次，建立失敗被
       `except` 吞掉、只印日誌不影響啟動；(b) `/health` 從未真正檢查 Qdrant 連線，即使
       RAG 完全不能用也回報 `{"status":"ok"}`；(c) 部署優化把 Qdrant 容器改成 `--rm`，
       容器一停止就被刪除，若不慎從 Docker Desktop 的 Images 頁重開，會得到一個沒有
       port 對應、沒有資料卷的全新容器，這才是「連不上」的真正原因。
     - **修法（A/B/C/D 全做）**：collection 改為執行期冪等自動補建（A）；`/health` 接上
       真實的 Qdrant 連線檢查，不可達回 503 degraded（B）；啟動腳本的 Qdrant 容器拿掉 `--rm`、
       改 `--restart unless-stopped`（C）；startup 維持不因 Qdrant 未就緒而 crash，
       依 12-Factor Disposability 原則（D）。
     - **驗證**：2026-07-27 真人瀏覽器實測，Qdrant 停止期間啟動 ai-service 不 crash、`/health`
       正確回 503 degraded；重新啟動 Qdrant 後 `/health` 自動恢復 200 ok（全程未重啟
       ai-service）；新建聊天室聊天恢復正常（collection 自動補建）。

  4. **【已修復】聊天室輪詢逾時（空訊息陣列）時，`virtualMessageList.js` 拋出未捕捉例外**
     - **原描述已修正**：最初記錄「例外蓋掉了原本該顯示的建立失敗錯誤訊息」，經追查程式碼執行
       順序後**證實不成立**——錯誤覆蓋層文字在例外發生之前就已寫入 DOM 並正常顯示，
       兩者互不影響。真正的後果是例外導致 `vlist` 卡在 `null`、之後每次 `renderMessages()`
       都會重跑並再次崩潰，以及 Console 出現對開發者造成誤導的未捕捉例外。
     - **根因**：`computeRange(items)` 處理空陣列時有漏洞，最終會執行 `keyOf(items[0])`，
       但空陣列的 `items[0]` 是 `undefined`，存取 `undefined.id` 直接拋出 `TypeError`。
     - **修法**：`computeRange()` 開頭對 `items.length === 0` 提前返回安全的空區間
       `{ start: 0, end: -1, offsetTop: 0 }`，讓 `renderWindow()` 的迴圈自然不執行。
     - **驗證**：2026-07-27 真人瀏覽器實測（關閉 chat-service 模擬聊天室建立逾時），
       畫面正確顯示「聊天室建立失敗」訊息，Console 不再出現該 TypeError（見本文件 5.1）。

  5. **【已修復，2026-07-27】重啟聊天室時，若「建立新聊天室」步驟逾時失敗，不會顯示 toast，而是卡在
     「聊天室建立失敗」懸浮層，輸入框永久停用**
     - **服務**：`persona-nexus-chat`
     - **檔案**：`src/chat.js:599-603`（`restartBtn` click handler 內「步驟 2：建立新聊天室」）
     - **現象**：點 ♻️ → 確認 → 顯示「聊天室重啟中...」→ 刪除舊聊天室成功 → 顯示「聊天室準備
       中...」開始建立新聊天室 → 此時若後端不可達（實測：按下確定的瞬間關閉 chat-service），
       輪詢逾時後畫面顯示「聊天室建立失敗，請重新整理頁面再試」（沿用 5.1 建立聊天室共用的
       置中懸浮層文字），**沒有 toast**，也沒有呼叫 `hideInitializing()`，輸入框維持停用，
       須整頁重新整理才能恢復。
     - **根因**：`pollForConversation()` 逾時時回傳 falsy（不是 `throw`），第 599-602 行對此
       直接 `showInitializing(...)` 後 `return`——這個 `return` 會跳出整個 async 函式，永遠
       不會執行到第 615 行的 `catch` 區塊，因此 `showToast('重啟失敗: ...')`（第 617 行）在這條
       路徑上架構上就不可能被呼叫到。只有「刪除舊聊天室失敗」（第 589-591 行，真的會 `throw`）
       才會走到 catch → 顯示 toast。
     - **判定**：先前 debug 輪次修 `alert()`→toast 時沒覆蓋到的漏網路徑，不在原本 4 個已知
       bug 名單內，是本次測試新發現的第 5 個問題。**沒有復發 `alert()`**，但沒有達成
       「重啟失敗顯示 toast」的預期行為。
     - **修復（2026-07-27）**：`chat.js:599-602` 把逾時的 `return` 改成 `throw`，統一走外層
       `catch` 顯示 toast 並解除懸浮層。詳細改動見《前端網頁debug_task_checklist.md》Bug 5。
     - **回歸測試（2026-07-27，第九階段 9.1，Playwright 自動化瀏覽器）**：✅ 通過。toast 正確
       顯示「重啟失敗: 聊天室建立失敗，請重新整理頁面再試」、3.5 秒後自動消失、懸浮層解除、
       輸入框恢復可用，不需整頁重新整理。

  6. **【已修復，2026-07-27】編輯頁未帶 `?id=` 參數時，靜默轉向回首頁，沒有任何錯誤提示**
     - **服務**：`persona-nexus-lobby`（根因）／`persona-nexus-character`（受影響但本身邏輯正確）
     - **檔案**：`persona-nexus-lobby/src/main.js:68`（`restoreRouteFromUrl()` 的路由還原邏輯）
     - **現象**：直接在網址列輸入 `http://localhost:8080/my-characters/edit`（不帶 `id` 參數）
       並 Enter，畫面**靜默轉向回首頁**，沒有出現任何錯誤訊息或提示，使用者不會知道發生了
       什麼事、也不知道正確進入編輯頁的方式（應從角色列表進入）。
     - **根因**：`main.js:68` 的路由判斷 `if (pathname === '/my-characters/edit' && params.get('id'))`
       要求 `id` 參數為真值才會進入編輯頁流程；不成立時直接落到第 89-91 行「其餘一律回首頁」的
       fallback，**連 iframe 都還沒載入**。而 `persona-nexus-character/src/edit.js:41-43` 確實有寫
       正確的「缺少角色 ID」錯誤訊息邏輯，但因為 lobby 這一層路由 gate 先攔截，那段邏輯在這條
       路徑下永遠執行不到，形同死碼。
     - **與《前端系統設計原則》的關係**（使用者要求對照後判定）：
       - **D 節「錯誤預防與明確回饋」**：靜默轉頁沒有給任何錯誤說明或修正路徑，比顯示一個
         「笨」但清楚的錯誤訊息更差。
       - **D 節「一致性與標準」**：對照本文件 3.3 節已驗證的案例——瀏覽器上一頁回到「id 存在
         但角色已被刪除」的編輯頁時，`edit.js` 的 404 處理**確實會顯示**「✕ 載入失敗，請稍後
         重試。」錯誤訊息。同樣是「進不了編輯頁」的情境（id 缺失 vs. id 存在但角色不存在），
         兩條路徑的使用者體驗完全不一致，一個有清楚回饋、一個什麼都沒說。
     - **使用者判定**：這是先前優化階段（`lobby-simplify` 等 change）沒有規劃到的路徑——優化
       腳本沒把「這一層路由 gate 攔截時該怎麼回饋使用者」納入設計範圍，但本輪測試腳本卻把它
       納入測項，兩邊落差因此在此暴露。
     - **修復（2026-07-27）**：`main.js` 把 `/my-characters/edit` 拆成獨立分支，缺 `id` 時
       先 `loadHomePage()` 再顯示 `showMessage()` 錯誤訊息，不再靜默轉向；`lobby-ui/spec.md`
       同步新增對應 Scenario。詳見《前端網頁debug_task_checklist.md》Bug 6。
     - **回歸測試（2026-07-27，第九階段 9.2，Playwright 自動化瀏覽器）**：✅ 通過。落地首頁、
       顯示「❌ 缺少角色 ID，請從「我的角色」清單進入編輯頁。」、4 秒後自動隱藏，且沒有出現
       修復時特別留意要避開的「body 級重複 `#message-box`」副作用。

  7. **【已修復，2026-07-27】角色卡片「⋮」選單的「編輯」選項無法用鍵盤（Enter/Space）觸發**
     - **服務**：`persona-nexus-lobby`
     - **檔案**：`src/my-character.js:60-69`（編輯選項）；同一套寫法也出現在
       `src/conversation-history.js:18-22`（第七階段側邊欄對話歷史的「刪除」選項，尚未實測到，
       但程式碼結構相同，判斷會有同樣問題，留待第七階段測到時一併確認）
     - **現象**：純鍵盤操作「我的角色」清單頁——Tab 移到某張角色卡片的「⋮」選單按鈕、按 Enter
       開啟選單後，焦點確實自動移到「編輯」選項（4.1 已驗證過這點沒問題），但接著按 Enter
       **沒有任何反應**，無法進入編輯頁，鍵盤操作在此卡住。建立新角色的流程（3.2/3.3）純鍵盤
       操作沒有問題，問題只出在「既有角色的編輯入口」這個環節。
     - **根因**：`editOption` 是用 `document.createElement('div')` 建立、加上
       `tabindex="0"`（讓它能被 Tab 移入焦點），只綁了 `addEventListener('click', ...)`
       （第 64 行），沒有另外綁 `keydown` 事件處理 Enter/Space。瀏覽器只有原生 `<button>`
       元素會在 Enter/Space 按下時自動觸發 `click`；`<div>` 加 `tabindex` 只解決了「能不能被
       Tab 移入」，並不會讓鍵盤按鍵自動等效於滑鼠點擊，這是兩件事，此處遺漏了後者。
     - **與《前端系統設計原則》的關係**：D 節 WCAG——「互動元素（tab 切換、按鈕）是否能用
       鍵盤（Tab / Enter）操作，而不是只在滑鼠點擊時綁事件」，這裡正是只綁了滑鼠事件的案例。
     - **使用者判定**：與第 6 項同理，是先前優化階段未規劃到、本輪測試腳本才發現的落差。
     - **修復（2026-07-27）**：`my-character.js`（編輯選項）與 `conversation-history.js`
       （刪除選項，同型問題）都補上 `keydown` 監聽器，判斷 Enter/Space 時觸發與 `click`
       共用的處理函式。選擇補 `keydown` 而非改用原生 `<button>`，理由（避免污染既有 CSS 樣式）
       詳見《前端網頁debug_task_checklist.md》Bug 7。
     - **回歸測試（2026-07-27，第九階段 9.3，Playwright 自動化瀏覽器）**：✅ 通過，兩處、
       Enter 與 Space 共 4 條路徑全過。編輯選項 Enter/Space 皆成功進入編輯頁；側邊欄刪除選項
       （**首次實測**）Enter/Space 皆正確跳出 `confirm()` 對話框。

  8. **【本文件原本未記錄，已修復，2026-07-27】lobby 的 `/api/config` 失敗時缺一個提前結束執行
     的判斷，導致後續對已清空 DOM 操作拋出未捕捉例外**
     - **服務**：`persona-nexus-lobby`
     - **與本文件的關係**：這一項**不是**在本輪測試的 7.5 當場被記錄下來的——7.5 當時只檢查
       了「整頁是否正確替換成錯誤文字」這個畫面判定，判定通過，**沒有另外開 Console 分頁檢查**。
       是後續整理《前端網頁debug_task_checklist.md》時，在另一條路徑（`/my-characters/create`）
       重新測試同一種情境才發現 Console 有未捕捉例外，因此本文件原本的「發現的新問題」清單漏了
       這一項，本次補上以求記錄完整（依循「列出問題不自行篩選」的原則）。
     - **現象**：`/api/config` 失敗時，畫面正確顯示「❌ 無法連線至服務器，請稍後重試。」，但
       Console 同時出現 `Uncaught TypeError: Cannot set properties of null (setting 'innerHTML')
       at initSidebar (sidebar.js:46:30)`。
     - **根因**：`main.js` 的 `configLoadError` 分支把 `document.body.innerHTML` 換成錯誤訊息後
       沒有中止執行，程式碼繼續跑到 `initSidebar()`，但這時候原本的 `#sidebar-container` 已經
       被换掉的 body 蓋掉，對 `null` 設 `innerHTML` 直接拋錯。
     - **修復（2026-07-27）**：`main.js` 整段初始化包成 `init()` 函式，`configLoadError` 分支
       顯示錯誤訊息後立刻 `return` 中止。詳見《前端網頁debug_task_checklist.md》Bug 8。
     - **回歸測試（2026-07-27，第九階段 9.4，Playwright 自動化瀏覽器）**：✅ 通過。分別對
       `/my-characters/create`（原觸發路徑）與 `/`（回頭補測 7.5）封鎖 `/api/config`，兩者畫面
       皆正確整頁替換，且 Console 都**沒有**出現該 `TypeError`，也沒有任何未捕捉例外
       ——確認 7.5 當時的疑慮不成立，補測後乾淨。
