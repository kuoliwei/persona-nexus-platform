## Context

user-service 是使用者帳號管理微服務，已通過架構層稽核（2026-07-24），各層職責清晰。當前代碼無功能缺陷或安全漏洞，缺口主要是文件補完：

- userService 方法（4 個）缺 JSDoc
- userRepository 方法（4 個）缺 JSDoc  
- userService 無區段註解
- controller 日誌過於詳細（生產環境不適）

## Goals / Non-Goals

**Goals:**
- 補完 userService / userRepository 的 JSDoc（@param、@returns、@throws）
- 加入區段註解，為日後擴展建立清晰結構
- 改進日誌（條件式輸出），減少生產環境噪音
- 提升代碼可維護性，建立文件標準

**Non-Goals:**
- 重構代碼邏輯（代碼已清晰）
- 改變 API 簽名或行為
- 新增 validation 或驗證邏輯
- 修改錯誤碼或 HTTP 狀態碼映射

## Decisions

**決策 1：JSDoc 補完的格式**
- 選擇 JSDoc 3 標準（與 auth-service 一致）
- 每個 public method 必有 @param、@returns、@throws
- repository 層 @throws 指出拋異常的情況；query 層回傳 null 的邊界也要明確

**決策 2：區段註解的粒度**
- 按職責分級（建立、查詢、刪除）
- 方法集中在同一職責下，邏輯明確

**決策 3：日誌改進的範圍**
- userController 的 4 個方法各有詳細日誌，改為條件式（NODE_ENV='development'）
- 保留業務邏輯上的 console.error（錯誤追蹤需要）

## Risks / Trade-offs

[風險] 日誌改為條件式後，生產環境看不到請求詳情  
→ 改進：改用 `process.env.NODE_ENV === 'development'` 判斷；若生產需要詳細日誌，應走 debug level（需另行設定 logger 庫）

[權衡] JSDoc 增加代碼行數（~36 行），但換得可維護性提升  
→ 取捨：優先維護性，短期代碼略長但長期收益

## Migration Plan

1. **編輯 userService.js**：加 JSDoc + 區段註解（無行為改變）
2. **編輯 userRepository.js**：加 JSDoc（無行為改變）
3. **編輯 userController.js**：改日誌為條件式（可選）
4. **測試驗證**：npm test（應全通過）
5. **git commit**：所有改動一併提交

無需回滾策略（純文件改動，無邏輯改變）。

## Open Questions

- 是否應該為 userController 的 respondError() 方法也加 JSDoc？（目前是 private helper）  
  → 建議：不加（internal utility），但若日後提取為中央錯誤處理則再補
