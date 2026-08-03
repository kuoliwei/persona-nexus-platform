## 1. 拆分 generationStatusRepository.js

- [x] 1.1 建立 `dbGenerationStatusRepository`：把 `get`/`tryAcquireLock`/`releaseLock`/`setCompleted`/`setFailed`/`reset` 的 DB 分支各自搬成完整方法，移除 `if (!config.persistence?.enableGenerationStatus)` 判斷
- [x] 1.2 建立 `memoryGenerationStatusRepository`：比照搬移記憶體分支，`memoryGenerationStatus` Map 維持模組級狀態
- [x] 1.3 保留 `tryAcquireLock`／`setFailed` 上方解釋回合身分／殭屍鎖的長註解，DB 版與記憶體版各自留一份
- [x] 1.4 檔案底部用 `config.persistence?.enableGenerationStatus ? dbGenerationStatusRepository : memoryGenerationStatusRepository` 綁定 `generationStatusRepository` 匯出
- [x] 1.5 具名匯出 `dbGenerationStatusRepository`／`memoryGenerationStatusRepository` 供測試直接使用

## 2. 拆分 conversationCreationJobRepository（conversationRepository.js）

- [x] 2.1 建立 `dbCreationJobRepository`：`findByKey`/`upsert`/`delete` 的 DB 分支搬成完整方法
- [x] 2.2 建立 `memoryCreationJobRepository`：比照搬移記憶體分支，`memoryJobs` Map 維持模組級狀態
- [x] 2.3 檔案底部用三元選擇綁定 `conversationCreationJobRepository` 匯出
- [x] 2.4 具名匯出 `dbCreationJobRepository`／`memoryCreationJobRepository` 供測試直接使用

## 3. 改寫單元測試

- [x] 3.1 `conversationRepository.test.js`：`conversationCreationJobRepository` 相關的兩個 describe 區塊改為直接匯入 `dbCreationJobRepository`／`memoryCreationJobRepository`
- [x] 3.2 `conversationRepository.test.js`：`generationStatusRepository` 相關的所有測試改為直接匯入 `dbGenerationStatusRepository`／`memoryGenerationStatusRepository`
- [x] 3.3 移除測試檔裡不再需要的 `beforeEach` config 旗標重置邏輯
- [x] 3.4 `npm test` 確認 152 則測試全數通過（zero diff：測試數量、斷言內容與重構前完全一致，只改「打誰」）

**驗收標準：**
- ✅ `dbGenerationStatusRepository`／`memoryGenerationStatusRepository`／`dbCreationJobRepository`／`memoryCreationJobRepository` 四個物件的方法內部不含 `config.persistence` 判斷
- ✅ `aiGenerationService.js`／`conversationCreationService.js`／`messageService.js` 三個呼叫方檔案零修改
- ✅ 152 則單元測試全數通過

---

## 4. 補寫 OpenSpec 文件（本次為補做，先實作後補文件）

- [x] 4.1 撰寫 `proposal.md`（Why / What Changes / Capabilities / Impact）
- [x] 4.2 撰寫 `design.md`（Context / Goals-NonGoals / Decisions / Risks / Migration Plan）
- [x] 4.3 撰寫 `specs/chat-persistence-mode-boundary/spec.md`（4 個 Requirement、6 個 Scenario）
- [x] 4.4 撰寫本檔 `tasks.md`

**備註：** 本次流程違反專案慣例——依既有先例（`2026-07-30-chat-service-code-quality` 等已歸檔 change），OpenSpec 文件應在動手改程式碼前先寫、經使用者確認後再實作，而非事後補寫。此為本次流程缺失，已與使用者確認並記錄，後續同類變更需改回「先文件後實作」。

---

## 5. Playwright 端到端驗證（真實後端，回歸測試）

- [x] 5.1 啟動六個後端服務（auth/user/character/chat/ai-service/api-gateway，含 Docker 的 Qdrant/Caddy、Ollama）與 4 個前端，發現 `config.json` 當下已是 `enableCreationJobs`／`enableGenerationStatus` 皆 `false`（記憶體模式，非正式設定，推測為先前手動測試遺留）
- [x] 5.2 Playwright 走查（記憶體模式）：建立全新角色聊天室（走 `memoryCreationJobRepository`）→ 連續發送 2 則訊息（走 `memoryGenerationStatusRepository`）→ 兩則皆在 ~18 秒內正常收到 AI 回覆、`isThisTurn` 配對正確、重新整理後訊息仍在 DB 中——**通過**
- [x] 5.3 將 `config.persistence.enableCreationJobs`／`enableGenerationStatus` 改為 `true`（正式設定）並重啟 chat-service
- [x] 5.4 Playwright 走查（DB 持久化模式）：對同一聊天室發送訊息，24 秒內正常收到 AI 回覆、重新整理後訊息仍在——**通過**
- [x] 5.5 對照 `specs/chat-persistence-mode-boundary/spec.md` 逐條確認：四個 Requirement 的 Scenario 皆通過（含「上鎖失敗不污染欄位」「setFailed 保留 tempUserId」兩條，由重構前既有的 152 則單元測試持續守住，本輪未重新單獨驗證這兩條的端到端版本）
- [x] 5.6 測試完成後旗標已設回 `true`（正式環境設定）；`config.json` 未進版控（`.gitignore` 排除），本機測試過程中的旗標切換不會被 commit
- [x] 5.7 更新 `chat-service/CLAUDE.md`／長期記憶，記錄驗證結果與第 6 節的 bug 發現

---

## 6. 調查記錄：「AI 生成成功但前端顯示失敗」的 bug——根因尚未確認

使用者回報「連續三次」發生「ai-service 已生成成功、chat-service 也已存入 DB，但前端輪詢直到 timeout 才顯示『回應失敗』，重新整理頁面才看到正確回覆」，且明確表示**服務全程穩定運行、沒有重啟任何東西、也沒有短時間內連續發送大量訊息**。這與本次重構的程式碼**無關**（重構只是把既有的兩種模式拆乾淨，未改變任一種模式本身的行為）。

⚠️ **下面 6.1～6.3 驗證的是研究者自行設計的假設情境，不是使用者實際遇到的觸發條件**——寫下這個提醒是因為第一版曾在此處寫「根因確認」，被使用者指出「這是你自己想出來的測試情境，我沒說我是這樣發生的」而修正。這兩個機制證明了「同一種前端症狀可能有多種完全不同的後端觸發原因」，本身仍是有價值的排查記錄，但**不能當作使用者那次事件的定論**。

- [x] 6.1 假設情境 A（重啟時序）：用直接呼叫 API 的方式精準控制時序，送出訊息後監看 chat-service log 抓到「AI 生成狀態已更新為 'completed'」那一行的瞬間，立刻 `taskkill` 並重啟 chat-service 行程。記憶體模式（`enableGenerationStatus: false`）下 100% 重現：重啟後所有後續輪詢皆回 `{"status":"unknown"}`，訊息確實已存入 DB；`aiResponsePoller.js` 對 `unknown` 不會判定失敗也不會停止輪詢，靜靜等到 120 秒上限才 fallback 顯示失敗。DB 模式（`enableGenerationStatus: true`）下用完全相同時序對照測試不受影響——**已被使用者排除**，因為使用者確認未重啟過任何服務。
- [x] 6.2 假設情境 B（同聊天室兩輪生成搶鎖覆寫）：`tryAcquireLock` 判斷可搶鎖的條件是「目前不是 generating」，`completed` 也符合，因此監看到第一輪 `completed` 的瞬間立刻送出第二輪訊息，100% 重現第一輪的完成通知被覆寫、其專屬輪詢迴圈永遠對不上而顯示失敗——**同樣被使用者排除**，因為這是研究者自行設計的連續發送情境，使用者從未描述過這樣操作。
- [x] 6.3 依使用者要求改為「完全正常使用」重測：記憶體模式下，單則發送、每則等完整跑完再送下一則、不重啟、不製造任何時間差，連續跑 6 輪（回覆時間 17~48 秒），**全部成功，未能重現**。
- [ ] 6.4 待使用者提供更多當時環境線索（系統效能負擔、瀏覽器分頁背景化、網路/系統卡頓等）後，針對實際條件重新設計驗證方式——**尚未完成，根因待續**
- [x] 6.5 已將 `config.json` 改回正式設定（`enableCreationJobs`／`enableGenerationStatus` 皆 `true`）
- [x] 6.6 已更新 `chat-service/CLAUDE.md` 的持久化開關段落與長期記憶，如實記錄「兩個已驗證但非確認根因的機制」+「根因調查中」的狀態
