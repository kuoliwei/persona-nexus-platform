## Context

chat-service 的 AI 生成狀態（`generationStatusRepository.js`）與建立聊天室 job 追蹤（`conversationRepository.js` 的 `conversationCreationJobRepository`）在 2026-07-25～26 的平台級稽核中，已從進程內記憶體 Map 全面改為 Prisma 持久化（commit `b509562`）。2026-07-27 為了方便本機手動測試（常需要中途重啟 chat-service，驗證其他服務的斷線恢復），補上 `config.persistence.enableCreationJobs`／`enableGenerationStatus` 兩個開關，設為 `false` 時退回記憶體 Map。

**當前狀況（重構前）：**
- `generationStatusRepository` 的 6 個方法（`get`/`tryAcquireLock`/`releaseLock`/`setCompleted`/`setFailed`/`reset`）與 `conversationCreationJobRepository` 的 3 個方法（`findByKey`/`upsert`/`delete`），每個方法內部都各自寫一份 `if (!config.persistence?.enableXXX) { ...記憶體版... } ...DB版...`
- DB 邏輯與記憶體邏輯交纏在同一段函式裡：要修改任一種模式的行為，眼睛得同時追蹤兩條分支；要新增一個欄位或調整語意，得記得在兩個分支都改
- 已知代價：`tryAcquireLock` 的「上鎖時標記回合身分」修正（[[turn-identity-race-condition-fix]]）originally 只改了其中一個分支，另一分支漏改，事後才由測試補齊一致性驗證

**約束：**
- 呼叫方（`aiGenerationService.js`、`conversationCreationService.js`）import 的名稱與方法簽名不能變
- `config.json` 本身「改了要重啟服務才生效」的既有語意不能變（不是要做成執行期動態切換）
- 152 則既有單元測試的斷言內容不能變（只能改「打誰」，不能改「期待什麼」）——這是本次重構「零行為改動」的證據

## Goals / Non-Goals

**Goals:**
1. ✅ DB 版與記憶體版各自成為完整、獨立、不含模式判斷分支的實作
2. ✅ 外部可見的 import 名稱、方法簽名、行為完全不變
3. ✅ 測試改為直接指定實作驗證，不再依賴「動態改寫 config 旗標」這種只在同一模組實例存活期間才有意義的技巧

**Non-Goals:**
- 不做成執行期動態切換（例如熱重載 config、API 觸發切換模式）——config.json 本來就要重啟才生效，這次不改變這個時機
- 不新增第三種模式，也不改變兩個旗標各自的預設值（仍是 `true`）
- 不處理 RAG／摘要機制那組完全不同的「持久化記憶」概念（角色背景／few-shot／歷史摘要）——使用者已確認本次重構範圍僅限「任務狀態持久化」（建立 job + 生成鎖），與 RAG 記憶無關
- 不引入per-使用者或per-聊天室層級的持久化開關（維持全域 config 旗標，範圍已與使用者確認）

## Decisions

### 1. 選擇時機：模組載入時，一次性三元選擇

**決策：** 兩個檔案底部各自用 `config.persistence.enableXXX ? dbXxx : memoryXxx` 決定要匯出哪一個當作外部看到的物件。

**為什麼：** `config.json` 是啟動時讀一次的靜態檔案（`config/index.js` 用 `fs.readFileSync` 同步讀取，無 watch/reload），改變設定本來就需要重啟服務才生效。讓程式碼的選擇時機對齊這個既有事實，而不是每次呼叫都重新判斷一次——後者才是「把兩套邏輯交纏在一起」的根源。

### 2. 保留原本的匯出名稱（`generationStatusRepository`／`conversationCreationJobRepository`）

**決策：** 選擇後的結果仍用原本的名稱匯出，呼叫方完全不需要修改。

**為什麼：** 這是純內部重構，不是介面變更。`aiGenerationService.js`、`conversationCreationService.js` 等呼叫方不應該因為這次重構而被牽動。

### 3. 兩份實作各自完整匯出（`db*`／`memory*`），供測試直接指定

**決策：** 除了選擇後的預設匯出，也把 `dbGenerationStatusRepository`／`memoryGenerationStatusRepository`／`dbCreationJobRepository`／`memoryCreationJobRepository` 個別具名匯出。

**為什麼：** 原本的測試靠「在同一個測試檔案裡把 `config.persistence.enableXXX` 改成 `true`/`false`，再呼叫同一個 `generationStatusRepository` 物件」來覆蓋兩種模式——這個技巧之所以成立，是因為舊實作的每個方法都在呼叫當下重新讀一次 config。拆成獨立物件後，選擇只發生一次，這個技巧會失效（測試裡改 config 不會讓已經匯出的物件變成另一個）。改為兩個模式各自具名匯出後，測試直接匯入要驗證的那個物件，語意更直接：「這個測試在驗證 DB 版」而不是「這個測試在某個 config 狀態下驗證共用物件」。

### 4. 保留既有的「為什麼」型長註解，複製到各自對應的分支

**決策：** `tryAcquireLock`／`setFailed` 上方解釋「回合身分」「不得清 tempUserId」的長段落註解，在 DB 版與記憶體版各自保留一份（不是只留一份、互相參照）。

**為什麼：** 這兩份實作現在是完全獨立的程式碼，各自需要能被單獨讀懂——不該要求讀者為了理解記憶體版的行為，還得跳去看 DB 版上方的註解。這些註解記錄了真實發生過的歷史 bug（[[turn-identity-race-condition-fix]]），是 F2 原則的必要註解，不能省略。

## Risks / Trade-offs

| 風險 | 概率 | 影響 | 緩解 |
|------|------|------|------|
| 重構過程中不慎讓 DB 版與記憶體版的行為產生差異 | 低 | 兩種模式語意不一致，正式/本機環境行為不同調 | 152 則既有測試的斷言內容完全不動，只改「打誰」；重構前後測試結果 zero diff（152/152 通過） |
| 拆檔後兩份實作的「為什麼」註解各留一份，未來只改其中一份導致註解與另一份行為不同步 | 低 | 註解誤導 | 兩份註解在本次重構是同一時間點複製產生，內容一致；後續維護需注意（已記錄於此 design.md 供未來參照） |
| 選擇邏輯本身（`config.persistence.enableXXX ? db : memory` 這一行）沒有專屬測試覆蓋 | 低 | 若三元運算式寫反，正式環境會意外用到記憶體版 | 屬單行、直觀的三元判斷，與既有服務啟動時讀 config 的其他慣例（例如 `config.ai.timeouts` 的預設值寫法）風險等級相同，未針對此類單行邏輯個別寫測試是本專案既有慣例；Playwright 端到端走查會間接驗證（關閉旗標後應退化為記憶體行為） |

## Migration Plan

不需要資料遷移——這是純程式碼內部重組，`config.json` 的欄位名稱、預設值、語意完全不變，現有部署不需要任何額外步驟即可套用本次變更。

## Open Questions

無——重構範圍已與使用者確認僅限「任務狀態持久化」（建立 job + 生成鎖），不涉及 RAG 記憶；實作前的誤解（一度以為使用者指的是 RAG 記憶開關）已在對話中澄清並記錄於 proposal.md 的 Why 段落。
