# OpenSpec 文件同步 task（2026-07-26）

## 給下一個聊天室的任務說明

根目錄 `openspec/` 底下有兩個 change（`platform-foundation`、`same-origin-deployment`），各自的 `proposal.md`／`design.md`／`tasks.md`／`specs/*/spec.md` 記錄的是**規劃當時**的狀態。但根目錄這陣子累積了大量實際執行紀錄（`執行日誌.md` 的 T1-T22、`mistakes.md` 的 M1-M17、`測試清單-*.md` 系列的正式實測結果），這些文件目前**沒有同步回 openspec**。

這次任務：**依照根目錄的 task/日誌文件，把 openspec 裡兩個 change 的文件（尤其 `tasks.md`）更新成反映目前實際狀態**——該打勾的打勾、過時的「已知缺口」該更正的更正、已經修好的 bug 不要再列成待辦。

---

## 開始前必讀（依序）

1. **`微服務架構準則.md`、`微服務架構實作spec.md`** — 這是全專案的規範源頭，`openspec/config.yaml` 的 context 區塊本身就是摘要這兩份文件寫的。如果 openspec 文件跟這兩份規範文件衝突，以規範文件為準。
2. **`執行日誌.md`**（T1-T22）— 記錄了每一次修復做了什麼、改了哪些檔案、驗收結果。這是判斷 openspec `tasks.md` 裡哪些項目「已完成」的主要依據。
3. **`mistakes.md`**（M1-M17）— 稽核發現的問題與根因，`openspec/config.yaml` context 區塊的「已知缺口」段落要對照這份文件重新檢查是否還成立。
4. **`測試清單-進階整合測試.md` 的「實測結果（2026-07-26，正式完整測試）」段落** + **`進階整合測試task0726.md`** — 今天（2026-07-26）剛完成的一輪正式測試，47 個案例＋2 項資料庫驗證＋H6 共 50 項全部經 Gateway、真實 token 實測 PASS，是目前最新鮮的「這些功能現在真的是這樣運作」的第一手證據，很多 openspec 裡寫的「待驗證」項目其實已經被這輪測試直接驗證過。
5. **`待辦task.md`** — 各 T 任務的原始程式碼與驗收標準，如果要判斷某個 openspec 任務項目的驗收標準是否已被滿足，這裡有最詳細的程式碼層級記錄。
6. **`前端API指引.md`** — 目前所有對外 API 的正確規格（路徑、request/response 格式），比對 `specs/*/spec.md` 裡的 API 範例是否過時時用這份當基準。
7. 各服務自己的 `CLAUDE.md`（`auth-service/CLAUDE.md`、`user-service/CLAUDE.md`、`character-service/CLAUDE.md`、`chat-service/CLAUDE.md`、`api-gateway/CLAUDE.md`）——每個服務目前實作狀態的第一手描述，含「已知缺口」段落，跟 openspec 的內容經常有落差，需要交叉比對。

---

## 已經發現的具體落差（不用重新找，直接處理即可）

### `openspec/changes/platform-foundation/`

- **`tasks.md` 全部 10 節、所有子項目目前都是 `- [ ]`（完全未打勾）**，但這份 tasks.md 寫的很多驗證項目實際上已經在 T1-T22 的修復過程與今天的正式測試中做過、且通過了。需要逐節對照執行日誌與今天的測試結果，該打勾的打勾，並補上驗收依據（例如「已於 2026-07-26 進階整合測試 J2/I1 案例驗證，見測試清單-進階整合測試.md」這種指向）。
- **4.1「錯誤回應格式：`{status:"error", message:"..."}`」是舊格式**，T12 已把格式改成 `{error, message}`（或部分端點是 `{success, message}`／裸物件），今天的 J1-J6 案例已經逐一驗證過現行格式。這條規則本身就寫錯了，要更正，不是打勾了事。
- **4.1「EMAIL_ALREADY_EXISTS 始終回傳 409」**——這件事本身現在是對的（T22 修復 + 今天 J1 案例驗證），但 tasks.md 寫這條的時候可能還是 400 的年代，要確認描述文字本身有沒有需要更新的地方（例如要不要註明「T22 修復前 auth-service 曾經是 400，現已統一 409」）。
- **`openspec/config.yaml` context 區塊「已知缺口」段落**：
  - 「persona-nexus-auth 登入成功後未存 localStorage token + 未導向大廳（狀態未重新查證）」——`auth-service/CLAUDE.md` 明確記載這個已經修好了（`main.js:188-193` 已確認有存 token），這條要更正或移除，不是繼續列成缺口。
  - 「persona-nexus-character 直打 character-service (5000) 而不經 gateway」——這條是否還成立需要重新查證，本輪測試沒有涵蓋前端瀏覽器行為（測試清單一律用指令模擬請求，不開瀏覽器），不能直接斷言已修好，但也不能照抄舊文字，要標註「需前端實測確認」。
  - 「ai-service 的非同步任務狀態仍在進程內記憶體」——這條目前仍然成立（`執行日誌.md` 明確記載 T19 擱置中未實作），可以保留，但可以補充參照今天測試的 K 系列結果（chat-service 這邊已經做好、ai-service 還沒做），讓對比更清楚。
- **`design.md`（392 行）尚未讀過內容**，需要另外檢查是否有跟現況不符的架構描述（例如是否還在描述 T8 之前的內部路由信任模型，沒反映 T21 修的「區分真正系統呼叫 vs 內部呼叫但代表特定使用者」這個修正）。

### `openspec/changes/same-origin-deployment/`

- 這份維護得比較好，`tasks.md` 45 項裡 40 項已打勾，且有詳細的「實作偏離與待辦」「Phase 7 整合測試結果」等第一手記錄，**不需要大改**，但有兩點要處理：
  1. **第 8 節（文件與交付）4 項還沒打勾**（`ARCHITECTURE.md` 更新、`.env.example` 補環境變數、`.gitignore`/`git status` 驗證、`CONTRIBUTING.md`）——確認現在是否已完成，完成的話補打勾。
  2. **文末「發現的安全問題」段落寫的 `GET /api/users/:id` 回傳完整使用者物件含 bcrypt 密碼雜湊**——**這個問題今天的測試（案例 G1、I1、J2）已經直接驗證是修好的**（`toPublicUser()` 有正確濾掉 password 欄位，逐一確認回應 body 不含 `"password"` 字樣）。要把這段標記為已解決，並註明是哪次修復解決的（查 `執行日誌.md` 或 `mistakes.md` 有沒有對應的 T/M 編號；如果查不到對應修復記錄，代表這是一個**沒有留下修復紀錄的落差**，要老實記下來，不要編一個不存在的 T 編號）。
  3. **「仍未完成」段落：「各後端專案尚無 Dockerfile，`docker-compose up --build` 會失敗」**——需要重新確認現況是否還成立。
  - `specs/*/spec.md`（4 個檔案）沒細看，可能也需要對照現況檢查。

---

## 注意事項

- **不要憑空猜測某個 openspec 任務項目「應該」已經完成**——每一條打勾前都要回頭對照執行日誌／測試清單裡的實際證據（狀態碼、response body、檔案行號），比照今天測試 T21/T22/G2/J1 案例「誰錯就改誰、有證據才下結論」的處理原則。
- **修改 `specs/*/spec.md` 時要遵守 `openspec/config.yaml` 的 `rules.specs` 格式規範**：Given/When/Then scenario 格式、RFC 2119 關鍵字、DB 變更要列 migration 檔名、API 變更要有完整 JSON 範例、錯誤碼要列舉所有 error code 與對應 HTTP status。修改 `tasks.md` 時比照 `rules.tasks`：每個任務 2-3 小時內、層級清楚、預估工時與依賴關係明確。
- 兩個 change 的 `proposal.md`（62/63 行，都還沒讀過內容）也要檢查是否有跟現況不符的地方，篇幅不大可以直接通讀。
- 如果發現 openspec 文件跟根目錄的 mistakes.md／執行日誌.md 的說法互相矛盾，處理方式比照今天測試遇到落差時的原則：**先查根因（哪個文件比較新、哪個有實際程式碼佐證），再決定改哪邊，不要各打五十大板**。
