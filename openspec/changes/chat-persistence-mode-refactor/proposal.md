## Why

chat-service 有兩個「任務持久化」開關：`config.persistence.enableCreationJobs`（建立聊天室的 job 追蹤）與 `config.persistence.enableGenerationStatus`（AI 生成狀態／並行鎖）。兩者的用途是讓服務重啟後仍記得「這個聊天室還在生成中／還在建立中」，繼續讓前端輪詢得到正確結果；關閉時退回進程內記憶體 Map，僅供本機測試（重啟即遺失）。

這兩個開關最初加入持久化功能時沒有預先設計「開關」這件事，導致實作方式是在 `generationStatusRepository.js` 與 `conversationRepository.js` 的 `conversationCreationJobRepository` 裡，**每一個方法內部各自寫一份 `if (!config.persistence?.enableXXX) { ...記憶體版... } ...DB版...` 分支**。DB 邏輯與記憶體邏輯交纏在同一段函式裡，形成「兩套邏輯要靠人工同步維護一致」的隱性負擔——[[turn-identity-race-condition-fix]] 那次「聊天氣泡一閃消失」的 bug，根因之一就是 `tryAcquireLock` 的兩個分支各自漏寫了同一個欄位清空邏輯，事後才補齊。這類問題在往後任何一次要修改鎖協定或 job 追蹤邏輯時都可能重演。

本次重構把兩種模式拆成完全獨立的實作，讓「DB 版」和「記憶體版」各自是一份完整、不需要在腦中同時追蹤兩條分支的程式碼。

## What Changes

- `generationStatusRepository.js`：拆成 `dbGenerationStatusRepository`／`memoryGenerationStatusRepository` 兩個完整獨立的物件，`get`/`tryAcquireLock`/`releaseLock`/`setCompleted`/`setFailed`/`reset` 六個方法各自不再包含模式判斷分支
- `conversationRepository.js` 的 `conversationCreationJobRepository`：比照同樣手法拆成 `dbCreationJobRepository`／`memoryCreationJobRepository`，`findByKey`/`upsert`/`delete` 三個方法各自不再包含模式判斷分支
- 兩處都在檔案底部用同一個三元選擇 `config.persistence.enableXXX ? db... : memory...` 決定要匯出哪一個當作外部看到的 `generationStatusRepository`／`conversationCreationJobRepository`——**呼叫方 import 的名稱與行為完全不變**，選擇時機仍是模組載入時（與「改 config.json 需要重啟服務才生效」的既有語意一致，不引入動態切換）
- `conversationRepository.test.js` 裡涉及這兩個 repository 的 27 則測試，改為直接匯入 `db*`／`memory*` 具名實作分別測試，取代原本「在同一個測試檔裡動態改寫 `config.persistence.enableXXX` 來回切換模式」的做法

## Capabilities

### New Capabilities
- `chat-persistence-mode-boundary`：定義 chat-service 這兩組「持久化／記憶體」雙模式 repository 的模組邊界契約——DB 版與記憶體版必須是各自完整、不共用條件分支的獨立實作，模式選擇只能發生一次（模組載入時），且兩種模式在相同輸入下必須產生語意相同的輸出

### Modified Capabilities
（無 API／DB schema 變更，純內部實作重組，對外行為不變）

## Impact

- **受影響檔案**：`chat-service/src/repositories/generationStatusRepository.js`、`chat-service/src/repositories/conversationRepository.js`、`chat-service/src/repositories/conversationRepository.test.js`
- **不受影響**：`aiGenerationService.js`、`conversationCreationService.js`、`messageService.js` 等呼叫方——import 的名稱（`generationStatusRepository`、`conversationCreationJobRepository`）與方法簽名完全不變，不需要修改
- **無 API 變更**、**無 DB schema 變更**、**無新環境變數**
- **相容性**：`config.json` 的 `persistence.enableCreationJobs`／`enableGenerationStatus` 兩個旗標語意不變，仍是「改了要重啟服務」；預設值（`true`）與正式環境行為完全一致
- **驗證方式**：`npm test`（152 則單元測試，重構前後 zero diff）+ Playwright 對真實後端自動化走查（建立聊天室、發送訊息、關閉兩個持久化旗標後重複走查）
