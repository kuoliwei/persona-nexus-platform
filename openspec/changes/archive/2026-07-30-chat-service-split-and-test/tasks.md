## 1. 建立測試框架

- [x] 1.1 `package.json` 加入 `vitest ^4.1.8` devDependency 與 `"test": "vitest run"` script
- [x] 1.2 `npm install`
- [x] 1.3 冒煙測試：確認 `vi.mock` 管線接通（barrel 匯出 17 方法、repository/serviceClient 已被替換）

**驗收**：✅ 冒煙測試 2 則通過

---

## 2. 撰寫單元測試（82 則）

- [x] 2.1 Mock 設定：`conversationRepository.js`（4 個匯出物件全部方法列齊）、`serviceClient.js`（11 方法）、`config/index.js`
- [x] 2.2 壓掉 console 噪音（`vi.spyOn(console, 'log'/'error'/'warn')`）
- [x] 2.3 職責 6：擁有權檢查（UNAUTHORIZED / MISSING_CONVERSATION_ID / CONVERSATION_NOT_FOUND / FORBIDDEN / isInternalRequest 跳過）
- [x] 2.4 職責 4：對話建立狀態機（getOrCreateConversation 的 ready/preparing/failed 三分支、retryConversationCreation）
- [x] 2.5 職責 1：對話 CRUD（列表、輕量摘要、刪除的 RAG-先於-DB 順序、RAG 失敗即中斷）
- [x] 2.6 職責 2：訊息 CRUD（sendMessage、分頁、getMessageById、回溯刪除 + 摘要連動）
- [x] 2.7 職責 7：主角人設（RAG-先於-DB 順序、空值正規化）
- [x] 2.8 職責 5：AI 生成狀態機（授權早於驗輸入、搶鎖、失敗解鎖、背景生成的原子性保存與失敗不落地）
- [x] 2.9 職責 3：摘要機制（未達訊息數不觸發／未達字數不觸發／達閾值完整流程／摘要失敗解鎖）

**驗收**：✅ 82 則全綠

---

## 3. 修正測試核對出的既有缺陷

- [x] 3.1 補上 5 個方法 JSDoc 漏列的 `MISSING_CONVERSATION_ID`
  （`deleteConversation` / `getProtagonist` / `updateProtagonist` /
  `getAIGenerationStatus` / `clearAIGenerationStatus`）
- [x] 3.2 確認 `deleteMessageAndSubsequent` / `getMessageById` 因先檢查 `MISSING_PARAMS`
  而不會拋 `MISSING_CONVERSATION_ID`，省略是正確的
- [x] 3.3 commit 步驟 1-3（commit `c829512`）

**驗收**：✅ JSDoc 記載處 1 個 throw 點 + 7 個方法

---

## 4. 依職責拆檔

- [x] 4.1 `conversationOwnership.js`（職責 6，葉節點）
- [x] 4.2 `summaryService.js`（職責 3，葉節點；移除死參數 `excludeLatestCount`）
- [x] 4.3 `conversationCreationService.js`（職責 4，封裝 `conversationCreationJobRepository`）
- [x] 4.4 `conversationCrudService.js`（職責 1）
- [x] 4.5 `protagonistService.js`（職責 7）
- [x] 4.6 `messageService.js`（職責 2）
- [x] 4.7 `aiGenerationService.js`（職責 5；`this._generateAIResponseAsync` 改直接呼叫）
- [x] 4.8 `conversationService.js` 降為 barrel，重組 17 方法物件

**驗收**：✅ 1263 行 → 最大檔 311 行

---

## 5. 驗證與提交

- [x] 5.1 跑同一份測試，確認 **測試檔 zero diff 且 82 則全綠**
- [x] 5.2 導入鏈檢查（controller → barrel → 7 模組）
- [x] 5.3 循環依賴檢查（barrel 匯出 17 個方法且全部解析為 function）
- [x] 5.4 確認 controller 零改動
- [x] 5.5 啟動服務打 `/health`
- [x] 5.6 commit 拆檔（commit `e85fce8`）

**驗收**：✅ 全數通過

---

## 6. 文件更新

- [x] 6.1 `CLAUDE.md`：技術棧加入 Vitest、新增「分層結構」段落與依賴規則、更新「已知限制」與「現況補充」、演進歷史補上三個 commit
- [x] 6.2 `mistake.md`：把「本輪不拆檔」標記為已推翻，新增「第三輪」完整記錄
- [x] 6.3 建立本 OpenSpec change
- [x] 6.4 commit 文件更新

---

## 總結

| 項目 | 結果 |
|------|------|
| 測試則數 | 82（原本 0） |
| 最大檔案行數 | 1263 → 311 |
| service 層檔案數 | 1 → 8（7 職責模組 + barrel） |
| controller 修改量 | 0 |
| 測試檔 diff（拆檔前後） | 0 |
| 順帶修正的 JSDoc 缺漏 | 5 處 |
