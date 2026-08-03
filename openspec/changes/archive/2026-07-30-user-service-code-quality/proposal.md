## Why

user-service 的代碼質量優異（無架構缺陷），但缺少程式碼層面的文件補完。根據新建立的《程式撰寫設計原則.md》六大維度稽核，發現 3 項低嚴重度違反（主要為 JSDoc 不完整、日誌過詳）。補完這些將提升可維護性，並為未來的 code review 建立清晰的文件標準。此為程式碼品質持續改進的一環（auth-service 已完成類似優化）。

## What Changes

- **補完 userService 方法的 JSDoc**（createUser、getUserByEmail、getUserById、deleteUser）：標註 @param、@returns、@throws，讓下游呼叫方（controller）快速理解簽名和邊界情況
- **補完 userRepository 方法的 JSDoc**（findByEmail、findById、create、deleteById）：明確指出回傳值是否可能為 null、何時拋異常
- **加入區段註解**（// ========== 職責名 ==========）：為將來的 userService 擴展建立清晰的內部結構
- **改進 controller 日誌**（可選）：改為條件式日誌（NODE_ENV='development' 才輸出），減少生產環境噪音

## Capabilities

### New Capabilities
<!-- None - this is documentation/quality improvement, not a new capability -->

### Modified Capabilities
<!-- None - no requirement changes, only code quality improvements -->

## Impact

- **userService.js**：新增 4 個方法的 JSDoc（約 20 行）
- **userRepository.js**：新增 4 個方法的 JSDoc（約 16 行）
- **userService.js**：新增區段註解（約 6 行）
- **userController.js**（可選）：改 4 個日誌語句為條件式（保持功能，減少噪音）
- **無 API 變更、無 DB schema 變更、無環境變數新增**
- **無破壞性改動、100% 向後相容**
- **測試無需更新**（代碼邏輯無變更）
