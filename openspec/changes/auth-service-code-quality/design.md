## Context

auth-service 現有代碼品質良好（14/14 單元測試通過），但根據《程式撰寫設計原則.md》稽核發現 5 項低嚴重度的違反項：
- JSDoc 不完整（register、login、userRepository 方法）
- 註解過度詳細（catch 區塊）
- 錯誤格式不一致（validateMiddleware vs authController）

這些改進純粹是代碼品質增強，無功能或架構改動。

## Goals / Non-Goals

**Goals:**
- 提升代碼可讀性和下游呼叫方的理解成本
- 統一錯誤回應格式，便於前端統一處理
- 補完 JSDoc，改善 IDE 智能提示和文件完整性
- 為後續維護和新功能開發打好基礎

**Non-Goals:**
- 改動任何業務邏輯或 API 端點行為
- 新增或移除任何功能
- 修改資料庫或環境變數
- 改變現有的單元測試

## Decisions

### 決策 1：JSDoc 標籤選擇

**選擇**：使用 JSDoc 的 `@param`、`@returns`、`@throws` 標籤。

**理由**：
- `@param` 明確參數名、類型、用途
- `@returns` 明確回傳值類型和結構
- `@throws` 明確會拋什麼錯誤

**為什麼不用 TypeScript**：
- 本專案是 JavaScript ESM，不採 TypeScript
- JSDoc 在 IDE 中有同等的智能提示效果

### 決策 2：錯誤回應格式統一為 `{error, message}`

**選擇**：validateMiddleware 改為回應 `{error: 'CODE', message: '...'}`，與 authController 一致。

**理由**：
- authController 已採 `{error, message}` 格式（見 authController.js:16）
- 統一格式便於前端用單一邏輯判斷錯誤（檢查 `error` 欄位而非 `status` 欄位）
- 無需改動前端，因為前端可能本來就在檢查 error 欄位

**為什麼不改 authController**：
- authController 的格式已經是 `{error, message}`，無需改動
- validateMiddleware 改成一致的格式是最小改動

### 決策 3：註解簡化方向

**選擇**：移除「做什麼」型的過度詳細註解，保留「為什麼」的邏輯說明。

**理由**：
- 代碼本身已清楚表達「做什麼」（if 語句、throw 語句一目瞭然）
- 註解應該說明「為什麼」（例如「區分業務錯誤與系統錯誤」）
- 移除比喻和簡化（例如「倉庫爆掉」）使代碼更專業

**例子**：
```javascript
// 改前
// 核心邏輯：如果是我們自己主動丟出的「Email重複」，就放行，不攔截牠！
if (error.message === 'EMAIL_ALREADY_EXISTS') { throw error }

// 改後
// 業務錯誤（已預期的）直接拋給 controller
if (error.message === 'EMAIL_ALREADY_EXISTS') { throw error }
```

## Risks / Trade-offs

**風險 1：前端依賴 status 欄位判斷錯誤**  
→ **緩解**：validateMiddleware 現在回應格式是 `{status: 'error', message}`，前端若依賴 `status` 值會看到 'error' 而非 HTTP 狀態碼，這本來就是不對的。改為 `{error: 'CODE', message}` 實際上是修正。前端應該依賴 HTTP 狀態碼和 error 欄位，不依賴 status 欄位。

**風險 2：JSDoc 文件可能過時**  
→ **緩解**：JSDoc 與代碼同檔，改邏輯時容易一併更新。建立 code review 習慣檢查 JSDoc 是否同步更新。

**無重大風險**：該改進純粹是代碼品質增強，無功能改動，現有單元測試不需改動。

## Migration Plan

**步驟**：
1. 補完 authService.register() 和 authService.login() 的 JSDoc（5 分鐘）
2. 補完 userRepository.findByEmail() 和 userRepository.save() 的 JSDoc（5 分鐘）
3. 簡化 authService catch 區塊的過度詳細註解（5 分鐘）
4. 改 validateMiddleware 的錯誤回應格式（5 分鐘）
5. 運行單元測試確保無迴歸（2 分鐘）
6. git commit（2 分鐘）

**預計總時間**：25 分鐘

**無需版本遷移或向後相容考量**：改動純粹是代碼層級，無 API 行為改變。

## Open Questions

- 是否需要為 userRepository 補充單元測試？（目前無）→ **決策**：本次改進不涵蓋；如有測試需求可在後續 change 中處理。
