## Why

基於《程式撰寫設計原則.md》對 auth-service 的稽核，發現 5 項低嚴重度的違反項，主要涉及函數簽名不完整、註解品質、錯誤格式不一致。這些問題不影響當前功能（14/14 單元測試通過），但降低了代碼可讀性和下游呼叫方的理解成本。此次改進是「代碼品質增強」，為後續維護和新功能開發打好基礎。

## What Changes

- **補完 JSDoc**：`authService.register()` 和 `authService.login()` 方法補齊 `@throws` 和 `@returns` 標籤，明確說明回傳值結構和會拋什麼錯誤。
- **補完 userRepository JSDoc**：`findByEmail()` 和 `save()` 方法補齊完整的 JSDoc，說明參數、回傳值類型、何時拋異常。
- **簡化 authService catch 區塊註解**：移除過度詳細的「做什麼」型註解（例如「倉庫爆掉」等比喻），保留清晰的「為什麼」說明。
- **統一 validateMiddleware 錯誤格式**：將 `{status: 'error', message}` 改為 `{error: 'CODE', message}`，與 authController 的回應格式一致。

## Capabilities

### New Capabilities

- `auth-service-jsdoc-completion`: 補完 authService 和 userRepository 方法的 JSDoc 文件，提升代碼可讀性和 IDE 智能提示。
- `auth-service-comment-cleanup`: 簡化 authService catch 區塊的內部註解，移除過度解釋的「做什麼」，只保留「為什麼」。
- `auth-service-error-format-unification`: 統一 validateMiddleware 的錯誤回應格式，與 authController 保持一致。

### Modified Capabilities

<!-- 無既有功能的需求改動，純代碼品質增強 -->

## Impact

**受影響檔案**：
- `src/services/authService.js`（register, login 方法的 JSDoc）
- `src/repositories/userRepository.js`（findByEmail, save 方法的 JSDoc）
- `src/middlewares/validateMiddleware.js`（錯誤回應格式）

**無 API 端點改動、無資料庫改動、無環境變數新增。**

**向後相容**：完全相容。只改代碼註解和錯誤回應的格式（格式變化內容不變，前端依靠 HTTP 狀態碼和 error 欄位判斷），無業務邏輯改動。
