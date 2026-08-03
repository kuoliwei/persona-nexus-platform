## ADDED Requirements

### Requirement: authService register 方法的完整 JSDoc
authService.register() 方法 SHALL 包含完整的 JSDoc 文件，包括參數說明、回傳值類型、可能拋出的錯誤列表。

#### Scenario: JSDoc 包含所有必要標籤
- **WHEN** 開發者查看 authService.register() 的 JSDoc
- **THEN** JSDoc 包含 @param email、@param password、@returns、@throws EMAIL_ALREADY_EXISTS、@throws UNKNOWN_SERVER_ERROR

### Requirement: authService login 方法的完整 JSDoc
authService.login() 方法 SHALL 包含完整的 JSDoc 文件，包括參數說明、回傳值類型、可能拋出的錯誤列表。

#### Scenario: JSDoc 包含所有必要標籤
- **WHEN** 開發者查看 authService.login() 的 JSDoc
- **THEN** JSDoc 包含 @param email、@param password、@returns（包含 token 欄位）、@throws UNKNOWN_USER、@throws EMAIL_OR_PASSWORD_NOTMATCH、@throws UNKNOWN_SERVER_ERROR

### Requirement: userRepository findByEmail 方法的完整 JSDoc
userRepository.findByEmail() 方法 SHALL 包含完整的 JSDoc 文件，明確說明回傳值類型（用戶物件或 null）。

#### Scenario: JSDoc 說明回傳值可能性
- **WHEN** 開發者查看 userRepository.findByEmail() 的 JSDoc
- **THEN** JSDoc 明確指出回傳值為 Promise<{id, email, password} | null>

### Requirement: userRepository save 方法的完整 JSDoc
userRepository.save() 方法 SHALL 包含完整的 JSDoc 文件，明確說明參數結構和回傳值類型。

#### Scenario: JSDoc 說明參數和回傳值
- **WHEN** 開發者查看 userRepository.save() 的 JSDoc
- **THEN** JSDoc 明確指出參數為 newUser 物件（包含 id、email、password），回傳值為 Promise<{id, email}>（不含密碼）
