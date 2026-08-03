## Why

`chat-service-code-quality`（同日稍早）的稽核把 `conversationService.js`（1263 行、7 種職責
混在一起）標為 🔴 高嚴重度，但**只用區段註解緩解導航成本，沒有真的拆開**，理由是「無測試框架
保護，拆檔沒有回歸安全網」。

使用者檢視成果後指出：補文件不等於實質優化——那一輪唯一被點名的真結構問題原封不動地留著。
因此本輪直接處理擋在前面的前提條件：**先補測試框架，再拆檔**。

## What Changes

### 步驟 1：導入測試框架

- ✅ 引入 Vitest ^4.1.8（對齊 character-service 既有設定，不需額外 config 檔）
- ✅ 新增 `"test": "vitest run"` script
- ✅ 新增 `conversationService.test.js`：**82 則**單元測試，覆蓋全部 17 個 public 方法的
  happy path 與 JSDoc 所列的每一個錯誤碼
- ✅ 順帶修正測試核對出的 5 處 JSDoc 缺漏（漏列 `MISSING_CONVERSATION_ID`）

### 步驟 2：依職責拆檔

依《程式撰寫設計原則.md》第 50-57 行針對本檔列出的職責清單，拆成 7 個模組 + 1 個 barrel：

| 職責 | 檔案 | 行數 |
|------|------|------|
| 1. 對話 CRUD | `conversationCrudService.js` | 148 |
| 2. 訊息 CRUD | `messageService.js` | 308 |
| 3. 摘要機制 | `summaryService.js` | 143 |
| 4. 對話建立狀態機 | `conversationCreationService.js` | 311 |
| 5. AI 生成狀態機 | `aiGenerationService.js` | 300 |
| 6. 擁有權檢查 | `conversationOwnership.js` | 61 |
| 7. 主角人設 | `protagonistService.js` | 67 |
| — 組裝層 | `conversationService.js`（barrel） | 67 |

**1263 行 → 最大檔 311 行。**

## Capabilities

### New Capabilities
<!-- 無新增 capability：測試框架屬工程基礎設施，拆檔為純結構重整 -->

### Modified Capabilities
<!-- 無需求變更；service 對外介面（17 個方法）完全不變，controller 零修改 -->

## Impact

**新增檔案：**
- `src/services/conversationService.test.js`（82 則測試）
- `src/services/` 下 7 個職責模組

**修改檔案：**
- `package.json`（devDependencies + test script）
- `src/services/conversationService.js`（1263 行 → 67 行 barrel）

**不變更：**
- `conversationController.js`、`serviceClient.js`、`conversationRepository.js` 零修改
- service 對外的 17 個方法名稱、簽名、行為完全不變

**風險控制：**
- 測試打 barrel 這層介面（controller 用的同一個進入點），因此拆檔前後可用
  **完全相同、一字未改的斷言**驗證行為不變
- 唯一的邏輯調整：移除 `calculateHistoryLength` 已確認的死參數 `excludeLatestCount`

**實際工時：** 約 2.5 小時（測試 1.5h + 拆檔 0.5h + 驗證與文件 0.5h）

**測試驗收：**
- ✅ 82 則測試全綠，測試檔 **zero diff**
- ✅ barrel 匯出 17 個方法且全部解析為 function（無循環依賴）
- ✅ controller 零改動、`/health` 正常
