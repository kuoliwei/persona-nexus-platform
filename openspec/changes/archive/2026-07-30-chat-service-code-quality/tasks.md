## 1. JSDoc 補完 - conversationService 方法

- [x] 1.1 補完 `getOrCreateConversation()` 的 JSDoc（@param、@returns、@throws）
- [x] 1.2 補完 `getAllConversations()` 的 JSDoc
- [x] 1.3 補完 `getConversationsSummary()` 的 JSDoc
- [x] 1.4 補完 `sendMessage()` 的 JSDoc
- [x] 1.5 補完 `sendMessageToConversation()` 的 JSDoc
- [x] 1.6 補完 `_generateAIResponseAsync()` 的 JSDoc（私有異步方法，簡短版）
- [x] 1.7 補完 `getMessages()` 的 JSDoc
- [x] 1.8 補完 `getMessagesByConversationId()` 的 JSDoc
- [x] 1.9 補完 `deleteConversation()` 的 JSDoc
- [x] 1.10 補完 `deleteConversationsByCharacter()` 的 JSDoc
- [x] 1.11 補完 `getProtagonist()` 的 JSDoc
- [x] 1.12 補完 `updateProtagonist()` 的 JSDoc
- [x] 1.13 補完 `deleteMessageAndSubsequent()` 的 JSDoc
- [x] 1.14 補完 `getMessageById()` 的 JSDoc
- [x] 1.15 補完 `retryConversationCreation()` 的 JSDoc
- [x] 1.16 補完 `getAIGenerationStatus()` 的 JSDoc
- [x] 1.17 補完 `clearAIGenerationStatus()` 的 JSDoc

**預估時間**：35 分鐘
**驗收標準**：
- ✅ JSDoc 包含所有 @param、@returns、@throws 標籤
- ✅ 明確列舉會拋的所有錯誤碼（對照 conversationController.js 的 ERROR_MAP 交叉核對）
- ✅ 描述清楚且符合平台慣例（參考 auth/user/character-service 的 JSDoc 格式）

**範例參考**：見 character-service/src/services/characterService.js 的方法 JSDoc

---

## 2. 加區段註解 - conversationService.js

- [x] 2.1 在私有 helper 群組上方新增 `// ========== 私有 Helpers（摘要機制／RAG／擁有權檢查） ==========`
- [x] 2.2 在 `getOrCreateConversation` 上方新增 `// ========== 對話建立 ==========`
- [x] 2.3 在 `getAllConversations` 上方新增 `// ========== 對話查詢 ==========`
- [x] 2.4 在 `sendMessage` 上方新增 `// ========== 訊息 CRUD ==========`
- [x] 2.5 在 `deleteConversation` 上方新增 `// ========== 對話刪除 ==========`
- [x] 2.6 在 `getProtagonist` 上方新增 `// ========== 主角人設 ==========`
- [x] 2.7 在 `retryConversationCreation` 上方新增 `// ========== 建立重試 ==========`
- [x] 2.8 在 `getAIGenerationStatus` 上方新增 `// ========== AI 生成狀態 ==========`
- [x] 2.9 驗證區段順序與現有方法排列順序一致，不搬動任何程式碼

**預估時間**：8 分鐘
**驗收標準**：
- ✅ 8 個區段註解已加入，位置與 design.md 的規劃一致
- ✅ 格式與 auth/user/character-service 一致（`// ========== 職責名稱 ==========`）
- ✅ 未搬動任何既有方法或程式碼順序

---

## 3. JSDoc 補完 - conversationRepository.js

- [x] 3.1 補完 `conversationRepository.findFirst()` 的 JSDoc（明確說明：不存在時回 null）
- [x] 3.2 補完 `conversationRepository.findMany()` 的 JSDoc
- [x] 3.3 補完 `conversationRepository.create()` 的 JSDoc
- [x] 3.4 補完 `conversationRepository.update()` 的 JSDoc
- [x] 3.5 補完 `conversationRepository.delete()` 的 JSDoc
- [x] 3.6 補完 `conversationRepository.deleteByCharacterId()` 的 JSDoc
- [x] 3.7 補完 `messageRepository.findMany()` 的 JSDoc
- [x] 3.8 補完 `messageRepository.findFirst()` 的 JSDoc
- [x] 3.9 補完 `messageRepository.findUnsummarized()` 的 JSDoc
- [x] 3.10 補完 `messageRepository.create()` 的 JSDoc
- [x] 3.11 補完 `messageRepository.update()` 的 JSDoc
- [x] 3.12 補完 `messageRepository.delete()` 的 JSDoc
- [x] 3.13 補完 `messageRepository.deleteManyByIds()` 的 JSDoc

**預估時間**：15 分鐘
**驗收標準**：
- ✅ JSDoc 明確說明參數類型、回傳值類型
- ✅ 對邊界情況有說明（例如 findFirst 回傳 null 而非 exception）
- ✅ `conversationCreationJobRepository`／`generationStatusRepository` 既有的行內註解維持不動（品質已高，本輪不重複處理）

**範例參考**：見 character-service/src/repositories/characterRepository.js 的 JSDoc

---

## 4. 驗證與提交

- [x] 4.1 在 chat-service 目錄執行語法檢查（無測試配置，所以只檢查導入）
  ```bash
  cd chat-service
  node -e "import('./src/controllers/conversationController.js').then(() => console.log('✅ conversationController OK')).catch(e => { console.error('❌', e); process.exit(1) })"
  ```
- [x] 4.2 檢查 conversationService.js 和 conversationRepository.js 無語法錯誤
- [x] 4.3 啟動服務並確認 `/health` 端點正常回應
- [x] 4.4 git add 改動的檔案（conversationService.js、conversationRepository.js）
- [x] 4.5 git commit，使用建議的 commit message（見下方）
- [x] 4.6 驗證 git status 為 clean（所有改動已 commit）

**預估時間**：10 分鐘
**驗收標準**：
- ✅ 語法檢查通過，檔案導入成功
- ✅ `/health` 端點回應正常
- ✅ git commit 成功
- ✅ working tree 為 clean（無未追蹤的改動）

---

## Commit Message 建議

```
refactor: chat-service 程式碼品質增強（JSDoc 補完、區段註解）

- 補完 conversationService 17 個 public 方法的 JSDoc (@param、@returns、@throws)
- 補完 conversationRepository.js 13 個 CRUD 方法的 JSDoc
- 加 8 個區段註解到 conversationService.js（對話建立/查詢/訊息CRUD/刪除/主角人設/建立重試/AI生成狀態/私有Helpers）
- 不拆檔（1069 行維持單一檔案，理由見 design.md 決策 3）
- 保留既有的「為什麼」型長註解（assertConversationOwnership 等），不簡化

無功能改動，純文件補完。
```

---

## 總預估工時

**35 + 8 + 15 + 10 = 68 分鐘**

---

## 檢查清單（完成後用於存檔）

- [x] 所有 JSDoc 補完（17 + 13 = 30 個方法）
- [x] 8 個區段註解已加
- [x] 語法檢查通過
- [x] `/health` 端點驗證通過
- [x] git commit 成功
- [x] 準備歸檔本 change
