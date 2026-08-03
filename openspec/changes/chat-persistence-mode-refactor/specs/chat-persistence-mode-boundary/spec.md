## ADDED Requirements

### Requirement: DB 版與記憶體版必須是互不依賴的獨立實作
`generationStatusRepository.js` 的 `dbGenerationStatusRepository`／`memoryGenerationStatusRepository`，以及 `conversationRepository.js` 的 `dbCreationJobRepository`／`memoryCreationJobRepository`，SHALL 各自完整實作全部方法，方法內部 MUST NOT 包含判斷 `config.persistence.enableXXX` 的條件分支。

#### Scenario: 修改其中一種模式不需要碰另一種模式的程式碼
- **WHEN** 開發者需要調整 DB 版 `tryAcquireLock` 的鎖協定（例如殭屍鎖時限計算方式）
- **THEN** 只需修改 `dbGenerationStatusRepository.tryAcquireLock`，不需要閱讀或修改 `memoryGenerationStatusRepository.tryAcquireLock` 的程式碼

### Requirement: 模式選擇只在模組載入時發生一次
`generationStatusRepository`／`conversationCreationJobRepository` 這兩個對外匯出的名稱 SHALL 在模組載入時，依 `config.persistence.enableGenerationStatus`／`enableCreationJobs` 的值各自綁定為對應的 `db*` 或 `memory*` 實作，且此後不再重新判斷。

#### Scenario: 執行期改變 config 物件不影響已匯出的對外名稱
- **WHEN** 服務執行期間，其他程式碼修改了記憶體中 `config.persistence.enableGenerationStatus` 的值
- **THEN** 已匯出的 `generationStatusRepository` 仍然是模組載入當下綁定的那一個實作，不會因此切換——與 `config.json` 本來就要重啟服務才能改變設定的既有語意一致

### Requirement: 呼叫方介面在重構前後保持不變
`aiGenerationService.js`、`conversationCreationService.js` 等呼叫方 import `generationStatusRepository`／`conversationCreationJobRepository` 的方式與呼叫的方法簽名 SHALL 與重構前完全一致。

#### Scenario: 呼叫方程式碼不需要任何修改
- **WHEN** 對 `generationStatusRepository.js`／`conversationRepository.js` 完成本次重構
- **THEN** `aiGenerationService.js`、`conversationCreationService.js`、`messageService.js` 三個呼叫方檔案的程式碼不需要任何修改即可正常運作

### Requirement: 兩種模式在相同輸入下必須產生語意相同的輸出
對於 `get`/`tryAcquireLock`/`releaseLock`/`setCompleted`/`setFailed`/`reset`（`generationStatusRepository`）與 `findByKey`/`upsert`/`delete`（`conversationCreationJobRepository`），DB 版與記憶體版在相同的呼叫序列下 SHALL 產生語意相同的回傳值與狀態轉換（差異僅限於「服務重啟後是否遺失狀態」）。

#### Scenario: 關閉持久化旗標後，聊天室建立與訊息發送的可觀察行為不變
- **WHEN** 將 `config.persistence.enableCreationJobs`／`enableGenerationStatus` 皆設為 `false` 並重啟 chat-service
- **THEN** 使用者仍可正常建立新聊天室、發送訊息並收到 AI 回覆，前端輪詢行為與旗標為 `true` 時一致，唯一差異是服務重啟後進行中的任務會遺失（記憶體版的預期行為）

#### Scenario: 上鎖失敗時兩種模式都不得污染既有回合的欄位
- **WHEN** 同一聊天室已有一個生成任務持有有效鎖（`generating` 且未超過殭屍鎖時限），此時另一個請求呼叫 `tryAcquireLock`
- **THEN** 不論 DB 版或記憶體版，搶鎖都回傳 `false`，且既有回合的 `tempUserId`／`userMessageId`／`assistantMessageId` 欄位不被修改

#### Scenario: setFailed 在兩種模式下都保留本回合的 tempUserId
- **WHEN** AI 生成失敗，呼叫 `setFailed(conversationId, errorMessage)`
- **THEN** 不論 DB 版或記憶體版，該回合的 `tempUserId` 都保持不變（不得被清成 null），確保前端能透過 `tempUserId` 判斷這個失敗屬於哪一回合
