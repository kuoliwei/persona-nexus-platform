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
- [x] 成功 → 訊息框顯示成功訊息（含角色 ID）、表單清空；**已知 bug**：1.5 秒後的自動跳轉目前是
      壞的（見文末「發現的新問題」第 1 項），手動導航到 `/my-characters` 後確認角色清單正確顯示
      新建立的角色，代表建立本身成功、只有跳轉這段壞掉
- [x] 新增「Few-shot 對話範例」列（+ 新增對話按鈕）→ 動態新增一列輸入框，可各自刪除
- [x] 「可見性」欄位（`visibility`）留空時，實際建立結果應為 `private`（預設值）
- [x] 額外建一個「可見性」設為 public 的角色（後面測「首頁公開列表」跟「跨帳號聊天權限」會用到）

### 3.3 可及性與邊界情境
- [x] `#message-box` 有 `role="status" aria-live="polite"`（實測於編輯頁確認：
      `<div id="message-box" role="status" aria-live="polite" class="error">✕ 載入失敗，請稍後重試。</div>`）
- [ ] 純鍵盤（Tab/Enter）能完成整個建立流程
- [ ] 未登入（沒有有效 token）直接訪問建立頁網址 → 導向 `/login/`
- [ ] 封鎖 `/api/config` 或後端整個關掉 → 訊息框顯示連線錯誤訊息（**已知小缺口**：目前
      `configLoadError` 設定後沒有在提交時被檢查，實際送出仍可能嘗試打真正的 API 再失敗——測試
      這個實際行為並記錄現象，不用當場修）

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
- [ ] 首頁角色卡片有 `aria-label` 提供可及名稱（需開發者工具檢查，暫緩，留待批次處理）

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
- [ ] 點 🎭 圖示開啟彈窗 → 焦點自動移到「名稱」輸入框（`#protagonistNameInput`）（需開發者工具/
      鍵盤焦點檢查，暫緩，留待批次處理）
- [ ] 彈窗有 `role="dialog" aria-modal="true"`（需開發者工具檢查，暫緩）
- [x] 三種關閉方式都測試（功能性驗證，焦點回到觸發按鈕這點暫緩）：
  - [x] 點右上角關閉按鈕
  - [x] 點彈窗外的遮罩背景
  - [x] 按 **Escape** 鍵
- [x] 填寫名稱/背景後按儲存 → 按鈕文字變「儲存中...」→ 成功後顯示 toast「主人公人設已儲存」、
      彈窗自動關閉
- [ ] 若對話室尚未準備好就嘗試開啟彈窗 → toast 提示，彈窗不開啟（未測，非必要邊界情境，暫緩）

### 5.5 Toast 通知
- [x] 觸發任一 toast（如刪除訊息衝突）→ 約 **3 秒後**自動開始淡出、再約 0.3 秒後從畫面消失
- [x] 連續觸發兩次 toast → 畫面上同時只會有一則（新的立刻換掉舊的，不會疊加）
- [ ] Toast 元素有 `role="status" aria-live="polite"`（需開發者工具檢查，暫緩）

### 5.6 重啟聊天室（♻️ 按鈕）
- [ ] 點擊 → `confirm()` 對話框 → 確認後顯示「聊天室準備中...」，等待重新建立完成
- [ ] 重啟失敗（模擬後端錯誤）→ 顯示 toast，**不是** `alert()`（本輪明確修掉的地方）

### 5.7 其他
- [ ] 🔄 重新整理按鈕：單純整頁 reload，歷史訊息重新從後端載入
- [ ] 长對話捲動：傳送/載入超過一畫面的訊息量，捲動流暢；停在最底部時新訊息自動跟著捲到底；
      往上捲看歷史時不會被強制拉回底部
- [ ] 直接在網址列輸入 `/rooms/<角色id>` 並重新整理 → 停留在聊天室（不是被導回首頁），這是刻意
      設計（用 `/rooms/` 而非 `/chat/` 避開 Caddy 整段代理，若走 `/chat/...` 重整會壞掉）

---

## 第六階段｜persona-nexus-character：編輯與刪除角色

> 放在聊天測完之後，避免刪掉正在用來測聊天的角色。

### 6.1 編輯角色流程
- [ ] 回「我的角色」清單，點某張卡片的「⋮」→「✏️ 編輯」→ 進入編輯頁，欄位正確帶入該角色現有資料
      （含 few-shots 列表）
- [ ] 修改欄位後送出 → `PUT /api/characters/:id` → 成功訊息 → 1.5 秒後跳回清單
- [ ] 直接在網址列打開編輯頁但不帶 `?id=` 參數 → 訊息框顯示「缺少角色 ID」錯誤，不會壞掉整頁

### 6.2 刪除角色流程
- [ ] 點「刪除」按鈕 → 跳出瀏覽器原生 `confirm()`（文字：「確定要刪除此角色嗎？此動作無法復原。」）
  - [ ] 按「取消」→ 什麼都不發生，角色還在
  - [ ] 按「確定」→ `DELETE /api/characters/:id` → 成功訊息 → 1.5 秒後跳回清單，該角色從清單消失

### 6.3 可及性
- [ ] 純鍵盤（Tab/Enter）能完成整個編輯/刪除流程

---

## 第七階段｜persona-nexus-lobby：其餘功能（對話歷史、手機版、其他路由）

### 7.1 側邊欄對話歷史
- [ ] 側邊欄顯示曾經聊過的對話清單（`GET /api/conversations/summary`）
- [ ] 點擊某筆對話 → 導向對應聊天室
- [ ] 「⋮」→「🗑️ 刪除」→ `confirm()`（文字含角色名稱）→ 確認後該筆從清單消失
- [ ] 刪除失敗（模擬後端錯誤）→ 顯示錯誤訊息（**有**把 `error.message` 顯示給使用者，跟 character
      頁不同，確認訊息確實有意義而非顯示 undefined）

### 7.2 手機版側邊欄
- [ ] 縮小視窗寬度（或用 devtools 裝置模擬）→ 漢堡選單開啟側邊欄抽屜、點遮罩關閉
- [ ] **已知缺口**：測試按 Escape 是否能關閉手機抽屜（程式碼顯示目前沒有實作），如果證實真的不能
      關，記錄成已知限制，不當場修

### 7.3 登出
- [ ] 登出按鈕 → 清除 token、導向 `/login/`

### 7.4 Iframe 導航串接
- [ ] 從大廳分別導向 create / edit / chat 三種 iframe 頁面時，URL 上的 `token`（與 `id`/
      `characterId` 等參數）都有正確帶到 iframe 裡（devtools 檢查 iframe 的 `src` 屬性）
- [ ] 建立/編輯/刪除角色完成後，iframe 內頁面用 `window.parent.location.href` 導回大廳，確認導頁
      發生在**最外層**（網址列變化），不是卡在 iframe 內部

### 7.5 邊界情境
- [ ] 封鎖 `/api/config` 或後端整個不可達 → 確認**整個頁面**（不只是訊息框）被替換成純文字錯誤
      訊息「❌ 無法連線至服務器，請稍後重試。」（比 auth/character 更激進，會整頁替換）

---

## 第八階段｜跨服務一致性檢查（收尾）

- [ ] 四個服務的訊息提示視覺風格是否一致（字體、顏色、位置）——已知 auth/character 用
      `success`/`error` 兩色，lobby 用 `info`/`error`（無 success），chat 用單一 toast 樣式無分色，
      **這是本輪已知、刻意保留的差異**，此處只需確認沒有出現非預期的第三種風格
- [ ] 四個服務裡曾經用過 `alert()` 的地方（chat 重啟失敗等）現在全部改為 toast 或訊息框，實測過程
      中留意有沒有漏網的 `alert()` 跳出
- [ ] 全程操作中 Console 分頁沒有出現非預期的 JS 錯誤或 404
- [ ] Network 分頁確認所有 API 請求都走相對路徑 `/api/...`（同源），沒有任何請求打向裸 port
      （`localhost:8000`/`5173`/`5175` 等）

---

## 測試結果紀錄區

> 執行完畢後回來填寫。若發現新問題，先記錄現象，**不要當場動手改程式碼**——回頭跟這次優化的規格
> （`openspec/specs/*/spec.md`）核對是否為已知限制，還是需要另開新的優化 change 處理。

- 測試日期：
- 測試環境：（作業系統／瀏覽器版本）
- 第一階段（auth）：
- 第二階段（lobby 基本）：
- 第三階段（character 建立）：
- 第四階段（lobby 確認）：
- 第五階段（chat）：
- 第六階段（character 編輯/刪除）：
- 第七階段（lobby 其餘功能）：
- 第八階段（跨服務一致性）：
- 發現的新問題（若有）：

  1. **【真實 bug，本輪 SOP 優化引入，尚未 commit】建立角色成功後跳轉失敗**
     - **現象**：在 `persona-nexus-character` 建立角色成功後，1.5 秒自動跳轉時網址列變成
       `http://my-characters/`，顯示 `ERR_NAME_NOT_RESOLVED`，沒有正確跳回大廳「我的角色」頁。
     - **根因**：`persona-nexus-character/src/create.js:23` 把 `LOBBY_APP_URL` 從舊版的絕對網址
       （`config.frontends.lobby`，如 `http://localhost:5175`）改成相對路徑常數 `'/'`（本輪 SOP
       明確要做的改動），但第 56 行的拼接邏輯沒有同步調整：
       `` `${LOBBY_APP_URL}/my-characters` `` 在 `LOBBY_APP_URL='/'` 時算出來是
       `'//my-characters'`——開頭雙斜線的字串在瀏覽器眼中是「protocol-relative URL」（協定相對
       網址，代表要連到叫 `my-characters` 的網域），於是被導去 `http://my-characters/`，而不是
       `http://localhost:8080/my-characters`。
     - **確認方式**：`git diff -- persona-nexus-character/src/create.js` 顯示這行是本輪優化改的、
       尚未 commit；優化前的舊版用絕對網址拼接沒有這個問題。
     - **待辦**：`create.js:56` 需要改成不會產生雙斜線的拼法（例如
       `LOBBY_APP_URL === '/' ? '/my-characters' : \`${LOBBY_APP_URL}/my-characters\`` ，或乾脆讓
       `LOBBY_APP_URL` 定義成空字串 `''` 而非 `'/'`）。**`persona-nexus-character/src/edit.js` 很可能
       有同樣的拼接問題（跳轉邏輯是同一套 pattern，抄自 create.js），下次修的時候要一併檢查**。
     - **狀態**：使用者決定先記錄、之後再回頭修，暫不影響繼續往後測試。
     - **補充（第二次重現）**：3.2 測試建立第二個角色時，Network 分頁證實 `POST /api/characters`
       回應 `201 Created`（建立本身沒問題），緊接著同一個跳轉 bug 又發生一次（`create.js:56`
       發出的 `my-characters` 文件請求失敗，頁面卡在 `chrome-error://chromewebdata/`），確認是
       穩定可重現、非偶發。

  2. **【真實 bug】角色簡介 tooltip 點擊卡片進入聊天室後不會消失，殘留畫面**
     - **現象**：在大廳首頁滑鼠移到角色卡片上，右側會浮現簡介 tooltip；直接點卡片進入聊天室後，
       這個 tooltip **沒有消失**，會一路殘留、疊在聊天室畫面上，一直到使用者回大廳、對任一張卡片
       完整做一次「滑入再滑出」才會消失。
     - **根因**：`persona-nexus-lobby/src/character-tooltip.js` 把 tooltip 元素建成掛在
       `document.body` 下的**全站共用單例**，靠 `mouseleave` 事件把 `style.opacity` 設回 `'0'`
       來「隱藏」，**從未真的從 DOM 移除**（見 `attachIntroTooltip()` 內的 `mouseleave` handler，
       檔案開頭註解也寫明是靠「移出卡片即淡出」這個機制，未考慮導頁情境）。因為 lobby 是 SPA、
       切頁不會整頁重載，`document.body` 跨頁延續，若點擊卡片觸發的導頁搶在瀏覽器真正派發
       `mouseleave` 事件之前就把卡片元素換掉/移除，`mouseleave` 就不會確實執行，tooltip 的
       `opacity` 便永遠卡在 `'1'`。
     - **確認方式**：使用者實測重現：大廳 hover 角色卡 → 點擊進入聊天室 → tooltip 殘留在聊天室
       畫面上；回大廳、對任一卡片完整 hover 一次後才消失。
     - **待辦**：`home.js` 的卡片 `click` handler 觸發導頁前，應主動呼叫一次讓 tooltip 隱藏（例如
       匯出一個 `hideTooltip()` 供外部呼叫），或導頁時機統一在別處清理殘留的 body 級 UI 元素，
       不要只依賴 `mouseleave` 這個不保證觸發的事件。
     - **狀態**：先記錄現象，暫不修復，待後續統一處理。

  3. **【非前端 bug，後端/基礎設施韌性問題，順便記錄】ai-service 與 Qdrant 斷線後無法自動重連**
     - **現象**：測試 5.2「模擬 AI 生成失敗」情境時，手動關閉 Qdrant docker 容器後再重新啟動，
       `ai-service` 仍然連不回去（持續噴 `[WinError 10061] 無法連線，因為目標電腦拒絕連線`／
       `Failed to create collection: characters`），必須把所有服務（含 Docker）全部關閉，
       用 `start-all-services.bat` 從頭啟動一次、讓它自動拉起 Qdrant，聊天功能才恢復正常。
     - **範圍澄清**：這不是本輪前端 SOP 優化要處理的範圍（前端行為本身完全正確，見下方
       「前端行為驗證通過」），是 `ai-service`／Qdrant client 連線管理的韌性問題（可能是
       qdrant-client 或 httpx 的連線池快取了失效連線、沒有重試或重建連線的機制），跟四個前端
       服務的程式碼無關。
     - **前端行為驗證通過（這才是本測項真正要驗證的）**：AI 生成失敗時，聊天介面正確顯示
       「（角色名稱）回應失敗: SERVICE_ERROR: Request failed with status code 500，請重試」
       的**對話氣泡內失敗提示**，符合設計（不是 `alert()`、不是 toast，這種錯誤刻意走氣泡樣式），
       輸入框也確認有恢復可用。5.2 該項目判定通過。
     - **狀態**：僅記錄現象供之後排查 ai-service／Qdrant 連線韌性用，不影響本輪前端測試結論。

  4. **【真實 bug】聊天室輪詢逾時（空訊息陣列）時，`virtualMessageList.js` 會丟出未捕捉例外，
     蓋掉原本該顯示的「建立失敗」錯誤訊息**
     - **現象**：測試 5.6 重啟聊天室時，恰好撞上後端卡在 `202 preparing` 狀態（見上方第 3 項的
       ai-service/Qdrant 連線問題），輪詢滿 120 次逾時後，Console 出現：
       `Uncaught TypeError: Cannot read properties of undefined (reading 'id') at keyOf (chat.js:78)`，
       呼叫鏈是 `initChat → renderMessages → createVirtualMessageList → sync → computeRange → keyOf`。
       畫面沒有正確顯示規格設計中「聊天室建立失敗，請重新整理頁面再試」的錯誤覆蓋層文字。
     - **根因**：`persona-nexus-chat/src/virtualMessageList.js` 的 `computeRange(items)` 函式處理
       **空陣列**（`items.length === 0`）時有漏洞：找不到任何項目的迴圈跑完後 `i === items.length`
       （`0 === 0`）會成立，接著執行
       `` start = Math.max(0, items.length - 1) `` （空陣列時算出 `0`）、
       `` startOffset = offset - slotHeight(keyOf(items[start])) ``——但 `items[0]` 在空陣列上是
       `undefined`，`keyOf(undefined)` 也就是存取 `undefined.id`，直接拋出例外。
     - **觸發路徑**：`persona-nexus-chat/src/chat.js:632`（`initChat` 函式尾端「初始化渲染」那行）
       在 `await initializeChat(characterId)` 執行完後，**不論成功或失敗都無條件呼叫一次
       `renderMessages()`**。`initializeChat()` 逾時失敗時只會顯示錯誤覆蓋層文字然後 `return`，
       `messages` 變數仍是初始值 `[]`，於是這次無條件呼叫的 `renderMessages()` 就以空陣列觸發
       `virtualMessageList` 的這個漏洞，例外蓋過了原本要顯示的錯誤訊息（實際畫面行為待確認：
       是整頁卡死、還是错误覆蓋層文字曾短暫顯示又被打斷，需要再觀察一次畫面而非只看 Console）。
     - **確認方式**：讀 `virtualMessageList.js` 原始碼定位到 `computeRange()` 對空陣列的處理漏洞；
       讀 `chat.js:625-634` 確認 `renderMessages()` 在 `initializeChat` 後是無條件呼叫，沒有檢查
       `messages.length` 或 initializeChat 是否成功。
     - **待辦**：`computeRange()` 應在函式開頭對 `items.length === 0` 直接提前返回一個安全的空區間
       （不執行任何 `keyOf(items[...])` 存取）；或 `chat.js:632` 那行無條件呼叫的 `renderMessages()`
       應該检查 `messages.length > 0` 才呼叫，兩者修一個就能避免這個崩潰，但前者是更根本的修法
       （`virtualMessageList` 作為通用模組，不該假設呼叫端一定給非空陣列）。
     - **狀態**：先記錄，暫不修復；影響範圍是「聊天室初次建立就失敗/逾時」這個原本就少見的邊界
       情境，不影響已建立成功的正常聊天流程（本次前面 5.1-5.5 的正常/AI失敗情境測試都沒有觸發
       這個問題，訊息陣列當時都非空）。
