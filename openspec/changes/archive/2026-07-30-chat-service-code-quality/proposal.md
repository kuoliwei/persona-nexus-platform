## Why

chat-service 已於 2026-07-25 完成架構層稽核（`simplify-chat-service` 及後續平台級稽核），消除了結構性缺陷（死代碼、錯誤映射分散、跨帳號授權漏洞、記憶體狀態改持久化等）。與 auth-service / user-service / character-service 的程式碼層優化一致，本輪補完 JSDoc、加區段註解，確保：
1. Service 層的 public 方法有明確的簽名文件（controller 呼叫方能快速了解會拋什麼錯誤）
2. Repository 層回傳值邊界清晰（避免誤用）
3. 1069 行的 conversationService.js 內部結構可快速導航（新維護者上手快）

## What Changes

- ✅ **補完 conversationService 的 17 個 public 方法 JSDoc**（getOrCreateConversation / getAllConversations / getConversationsSummary / sendMessage / sendMessageToConversation / _generateAIResponseAsync / getMessages / getMessagesByConversationId / deleteConversation / deleteConversationsByCharacter / getProtagonist / updateProtagonist / deleteMessageAndSubsequent / getMessageById / retryConversationCreation / getAIGenerationStatus / clearAIGenerationStatus）
  - 補充 @param、@returns、@throws 標籤
  - 明確說明會拋的所有錯誤碼

- ✅ **加區段註解到 conversationService.js**（緩解 1069 行的導航成本，本輪不拆檔）
  - `// ========== 對話建立 ==========`
  - `// ========== 對話查詢 ==========`
  - `// ========== 訊息 CRUD ==========`
  - `// ========== 對話刪除 ==========`
  - `// ========== 主角人設 ==========`
  - `// ========== 建立重試 ==========`
  - `// ========== AI 生成狀態 ==========`
  - `// ========== 私有 Helpers（摘要機制／RAG／擁有權檢查） ==========`（既有 helper 群組上方）

- ✅ **補完 conversationRepository.js 的 13 個 CRUD 方法 JSDoc**（conversationRepository 6 個 + messageRepository 7 個）
  - 明確說明回傳值邊界（例如 findFirst 不存在時回 null）

## Capabilities

### New Capabilities
<!-- No new capabilities; this is pure code quality enhancement -->

### Modified Capabilities
<!-- 無需求變更；純代碼層改進，無行為改動 -->

## Impact

**程式碼檔案：**
- conversationService.js（新增 17 個方法的 JSDoc + 8 個區段註解）
- conversationRepository.js（新增 13 個方法的 JSDoc）

**不變更：**
- conversationController.js（ERROR_MAP 已集中化，品質良好，免修改）
- serviceClient.js（JSDoc 已完整，免修改）
- 既有的「為什麼」型長註解（assertConversationOwnership、tryAcquireLock 等）——予以保留，不簡化
- **不拆檔**：本輪僅緩解導航成本，拆檔需先補測試框架，列為未來獨立工作項（見 mistake.md「拆檔決策」）

**影響範圍：**
- 無 breaking changes，無業務邏輯改動
- 純文件補完與可讀性增強
- 與 auth-service / user-service / character-service 風格對齊

**預期工時：** 60-80 分鐘（JSDoc 補完為主，方法數量約為 character-service 的 2.7 倍）

**測試驗收：**
- 語法檢查通過（無錯誤）
- 無單元測試配置（預期），確認代碼導入成功
- 手動驗證關鍵端點（health check + 現有 test.http）
