## 1. 先重現，確立根因（依賴：無）

> 先讓 bug 穩定可重現，才有辦法判斷修正是否真的有效。跳過這一步等於用「跑幾次沒看到」當驗收標準。

- [x] 1.1 ~~插入 3 秒延遲放大競態視窗~~ → **改用 repository 層驗證取代**（見 3.1）：一次性腳本在 `git stash` 掉修正後執行，回合 B 上鎖後讀到的狀態為 `{status:'generating', tempUserId:'temp_A', userMessageId:'u_A', assistantMessageId:'a_A'}`，直接證實「狀態碼是新的、訊息 ID 是舊的」混合體確實存在，9 項斷言未通過。不需改動 production 程式碼即可重現根因，比插延遲更安全
- [ ] 1.2 **（需人工瀏覽器操作）** 在既有聊天室（已有至少一回合完成的對話）送出第二則訊息，確認能**穩定重現**「兩個氣泡出現後一閃消失」；記錄 console 中 `🐛 [DEBUG] 走【ID 配對】路徑` 那行印出的 `tempUserId`，確認它不等於本回合的 `temp_*`（約 0.5 小時）
- [x] 1.3 ~~保留延遲至第 5 章~~ → 未插入延遲，無此需求

## 2. 後端：生成狀態標記回合身分（依賴：1.1）

- [x] 2.1 修改 `chat-service/src/repositories/conversationRepository.js` 的 `generationStatusRepository.tryAcquireLock(conversationId, staleLimitMs, { tempUserId })`——**持久化分支**（`updateMany` 的 `data`）新增 `generationTempUserId: tempUserId || null`、`generationUserMessageId: null`、`generationAssistantMessageId: null`（約 1 小時）
- [x] 2.2 同一函式的**記憶體分支**（`memoryGenerationStatus.set`）同步寫入 `tempUserId: tempUserId || null`、`userMessageId: null`、`assistantMessageId: null`，確保與持久化分支語意一致（約 0.5 小時）
- [x] 2.3 修改 `chat-service/src/services/conversationService.js` 的呼叫點，把 `sendMessageToConversation()` 收到的 `tempUserId` 傳進 `tryAcquireLock()`（約 0.5 小時）
- [x] 2.4 檢查 `setFailed()` 確實**沒有**碰 `generationTempUserId`（決策 2），並補上一行註解說明「此欄位由 `tryAcquireLock` 標記本回合，`setFailed` 必須保留」，避免日後被人「清乾淨」（約 0.5 小時）
- [x] 2.5 更新 `tryAcquireLock` / `setFailed` 上方的既有中文註解，說明新的欄位寫入時機與回合身分語意（約 0.5 小時）

## 3. 後端：驗證兩種持久化模式一致（依賴：2.1、2.2、2.3）

- [x] 3.1 寫一支一次性驗證腳本（沿用先前 14/14 一致性比對的手法，放 `chat-service` 暫存目錄、不進版控），對同一組操作序列「上鎖 → get → setCompleted → 上鎖 → get → setFailed → get」在 `enableGenerationStatus` 為 `true` / `false` 兩種設定下各跑一次（約 1.5 小時）
- [x] 3.2 比對兩種模式下每個步驟的 `status` / `tempUserId` / `userMessageId` / `assistantMessageId` 四個欄位完全相同；不一致就回頭修 2.1／2.2（約 0.5 小時）
- [ ] 3.3 用 `chat-service/test.http` 手動驗證：搶鎖失敗（同聊天室連送兩則）時回 409，且 `generationTempUserId` 未被第二個請求覆寫（spec 場景「搶鎖失敗不得污染他人回合的狀態」）（約 0.5 小時）
- [ ] 3.4 用 `test.http` 驗證 `generating` 期間 `GET /ai-generation-status` 的回應**不含** `userMessageId` / `assistantMessageId`（約 0.5 小時）
- [ ] 3.5 驗證後把 `config.json` 的 `persistence` 兩個旗標改回 `true`（正式設定），確認沒有把本機測試值 commit 進去（約 0.5 小時）

## 4. 前端：輪詢守門（依賴：2.3）

- [x] 4.1 修改 `persona-nexus-chat/src/chat.js` 的 `pollForAIResponse()`：解析 `generationStatus` 後計算 `const isThisTurn = generationStatus.tempUserId === tempUserId;`，把 `failed` 與 `completed` 兩個分支的判斷條件都加上 `isThisTurn &&`（約 1 小時）
- [x] 4.2 在守門不符的情況加一行 console log，印出期望的 `tempUserId` 與實際收到的值（設計文件的緩解措施：讓誤判在 console 立即可見，而非靜默跑到 120 秒超時）（約 0.5 小時）
- [x] 4.3 確認守門不符時 `attempts` 仍照常累加、`clearInterval` 不被呼叫、輸入框維持禁用，且第 118-133 行的超時分支不受影響（決策 4）（約 0.5 小時）
- [x] 4.4 在 `pollForAIResponse()` 上方補中文註解，說明為何需要守門（後端狀態欄位跨回合殘留）與為何不改成 `await POST` 後才輪詢（決策 3）（約 0.5 小時）
- [x] 4.5 執行 `npm run build` 確認前端建置通過（本專案無測試框架，建置是唯一的自動化把關）（約 0.5 小時）

## 5. 端到端驗證（依賴：3.x、4.x）

- [ ] 5.1 **放大競態視窗做端到端驗證**：在 `chat-service/src/services/conversationService.js` 的 `tryAcquireLock()` 呼叫**之前**暫時插入
      `await new Promise(r => setTimeout(r, 3000)); // TEMP: 放大競態視窗，驗證完必須移除`，
      重啟 chat-service，在既有聊天室送出第二則訊息。預期：兩個氣泡在整個延遲期間持續顯示、佔位符維持「正在思考中...」、
      console 出現 `⏭️ 狀態不屬於本回合` 三次左右、AI 回覆最終正確替換佔位符（spec 場景「後端上鎖延遲 3 秒仍不影響畫面」）（約 1 小時）
- [ ] 5.2 在瀏覽器 console 執行檢查，確認 `messages` 陣列無重複 id（可暫時在 `renderMessages()` 內加一行去重檢查 log，驗證完移除）（約 0.5 小時）
- [ ] 5.3 移除 5.1 插入的 3 秒延遲，`grep` 確認 `TEMP:` 註解與 `setTimeout(r, 3000)` 皆已清除（約 0.5 小時）
- [ ] 5.4 回歸走查：全新聊天室第 1 則訊息（`generationStatus` 為 null → `unknown` 路徑）正常（約 0.5 小時）
- [ ] 5.5 回歸走查：連續正常送 5 則訊息，每則的氣泡都不消失、AI 回覆都正確對位（約 1 小時）
- [ ] 5.6 回歸走查：AI 生成失敗（例如暫停 ai-service 或 Ollama）時，失敗氣泡**立即**出現且帶後端 error 訊息，不需等 120 秒（驗證決策 2 有效）（約 1 小時）
- [ ] 5.7 回歸走查：連續快速送兩則訊息，第二則被 409 擋下並顯示對應的失敗氣泡，第一則的輪詢不受影響（約 0.5 小時）
- [ ] 5.8 回歸走查：AI 生成失敗後，下一則訊息能立即送出（確認 `failed` 狀態不會卡住 `tryAcquireLock`，design.md Open Questions 第三項）（約 0.5 小時）
- [ ] 5.9 回歸走查：刪除訊息（回溯式）後再送新訊息，行為正常（刪除會呼叫 `reset()` 清空生成狀態，需確認與新的上鎖流程不衝突）（約 0.5 小時）
- [ ] 5.10 回歸走查：重啟聊天室後送訊息，行為正常（約 0.5 小時）

## 6. 文件與收尾（依賴：5.x）

- [ ] 6.1 更新 `chat-service/CLAUDE.md`：在生成狀態欄位的說明中補上「`generationTempUserId` 於上鎖時標記本回合、兩個訊息 ID 於上鎖時清空」（約 0.5 小時）
- [ ] 6.2 更新 `persona-nexus-chat/CLAUDE.md`：在「發送訊息採樂觀更新」段落補上「輪詢須以 `tempUserId` 驗證狀態歸屬後才採信」（約 0.5 小時）
- [ ] 6.3 把本變更的規格同步回兩個 repo 的 store：`chat-service/openspec/specs/conversations` 與 `persona-nexus-chat/openspec/specs/chat-ui`（約 1 小時）
- [ ] 6.4 兩個 repo 各自 commit（獨立 git repo，非 monorepo；`git -C chat-service` / `git -C persona-nexus-chat`），commit message 說明是競態修正並引用本變更名稱（約 0.5 小時）
- [ ] 6.5 在 `前端網頁debug_task_checklist.md` 記錄此 bug 的根因與修正結果，供後續測試回顧（約 0.5 小時）
- [ ] 6.6 決定 design.md Open Questions 的兩個待決項（`virtualMessageList` 重複 key 防護、`DELETE /ai-generation-status` 端點去留）——若決定處理，各自另立變更，不併入本輪（約 0.5 小時）
