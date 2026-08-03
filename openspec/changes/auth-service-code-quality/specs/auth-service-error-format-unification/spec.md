## ADDED Requirements

### Requirement: validateMiddleware 的錯誤回應格式 SHALL 與 authController 一致
validateMiddleware 的錯誤回應 SHALL 使用 `{error, message}` 格式，與 authController 的錯誤回應格式一致。錯誤回應 SHALL 包含 error 欄位（為業務錯誤碼如 'INVALID_INPUT'）和 message 欄位（為人類可讀的訊息）。

#### Scenario: validateMiddleware 回應格式與 authController 一致
- **WHEN** validateMiddleware 檢驗失敗（例如 email 格式不正確）
- **THEN** HTTP 回應體為 `{error: 'INVALID_INPUT', message: 'EMAIL或密碼格式不正確'}`，與 authController 的格式一致

#### Scenario: 前端統一處理錯誤格式
- **WHEN** 前端接收 validateMiddleware 或 authController 的錯誤回應
- **THEN** 前端可以用統一的 error 欄位邏輯判斷錯誤類型（不需要檢查 status 欄位是否存在）
