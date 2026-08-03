## 1. userService.js — JSDoc 與區段註解

- [x] 1.1 在 createUser 方法前新增 JSDoc（@param userData, @param options, @returns User, @throws FORBIDDEN/EMAIL_ALREADY_EXISTS）
- [x] 1.2 在 getUserByEmail 方法前新增 JSDoc（@param email, @param options, @returns User|null, @throws FORBIDDEN/USER_NOT_FOUND）
- [x] 1.3 在 getUserById 方法前新增 JSDoc（@param id, @param options, @returns User|null, @throws UNAUTHORIZED/FORBIDDEN/USER_NOT_FOUND）
- [x] 1.4 在 deleteUser 方法前新增 JSDoc（@param id, @param options, @returns void, @throws UNAUTHORIZED/FORBIDDEN/USER_NOT_FOUND）
- [x] 1.5 在 createUser 前加區段註解 `// ========== 建立使用者 ==========`
- [x] 1.6 在 getUserByEmail 前加區段註解 `// ========== 查詢使用者 ==========`
- [x] 1.7 在 deleteUser 前加區段註解 `// ========== 刪除使用者 ==========`

## 2. userRepository.js — JSDoc

- [x] 2.1 在 findByEmail 方法前新增 JSDoc（@param email, @returns Promise<User|null>）
- [x] 2.2 在 findById 方法前新增 JSDoc（@param id, @returns Promise<User|null>）
- [x] 2.3 在 create 方法前新增 JSDoc（@param user, @returns Promise<User>）
- [x] 2.4 在 deleteById 方法前新增 JSDoc（@param id, @returns Promise<User>）

## 3. userController.js — 日誌最佳化（可選）

- [x] 3.1 改 createUser 的日誌為條件式（if (process.env.NODE_ENV === 'development')）
- [x] 3.2 改 getUserByEmail 的日誌為條件式
- [x] 3.3 改 getUserById 的日誌為條件式
- [x] 3.4 改 deleteUser 的日誌為條件式

## 4. 驗證與提交

- [x] 4.1 執行 npm test，確認所有測試通過
- [x] 4.2 手動驗證各端點行為（npm start user-service，測試 CRUD）
- [x] 4.3 確認代碼無語法錯誤（無 linter 但可視覺檢查）
- [x] 4.4 git add . && git commit -m "docs: enhance user-service JSDoc and code organization"
- [x] 4.5 驗證 git log 顯示 commit 成功

## 5. 收尾

- [x] 5.1 更新 user-service/mistake.md，記錄本 change 完成
- [x] 5.2 更新 MEMORY.md，記錄 user-service 優化完成（如需要）
