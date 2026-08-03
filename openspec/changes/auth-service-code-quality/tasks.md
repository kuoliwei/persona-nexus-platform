## 1. JSDoc 補完 - authService 方法

- [x] 1.1 補完 authService.register() 的 JSDoc（@param、@returns、@throws）
- [x] 1.2 補完 authService.login() 的 JSDoc（@param、@returns、@throws）

**預估時間**：5 分鐘  
**驗收標準**：JSDoc 包含所有 @param、@returns、@throws 標籤，描述清楚

---

## 2. JSDoc 補完 - userRepository 方法

- [x] 2.1 補完 userRepository.findByEmail() 的 JSDoc
- [x] 2.2 補完 userRepository.save() 的 JSDoc

**預估時間**：5 分鐘  
**驗收標準**：JSDoc 明確說明參數類型、回傳值類型、何時拋異常

---

## 3. 簡化 authService 內部註解

- [x] 3.1 簡化 authService.register() catch 區塊的過度詳細註解
- [x] 3.2 簡化 authService.login() catch 區塊的過度詳細註解

**預估時間**：5 分鐘  
**驗收標準**：移除「做什麼」型註解和比喻，保留「為什麼」的邏輯說明

---

## 4. 統一 validateMiddleware 錯誤回應格式

- [x] 4.1 改 validateMiddleware 的錯誤回應格式為 `{error: 'INVALID_INPUT', message: '...'}`
- [x] 4.2 手動測試 register 端點的驗證失敗場景（檢查前端能否正確處理新格式）

**預估時間**：8 分鐘（4.1: 5 分鐘，4.2: 3 分鐘）  
**驗收標準**：✅ validateMiddleware 的錯誤回應與 authController 格式一致；回應格式為 `{error: 'INVALID_INPUT', message}`

---

## 5. 驗證與提交

- [x] 5.1 運行 `npm test` 確保所有 14 個單元測試通過
- [x] 5.2 手動驗證 register / login 端點（透過 test.http 或 curl）
- [x] 5.3 git add 改動的檔案
- [x] 5.4 git commit（commit message 見下方）
- [x] 5.5 驗證 git status 為 clean

**預估時間**：5 分鐘  
**驗收標準**：✅ 單元測試全通過（14/14），git 提交成功，working tree clean

---

## Commit Message 建議

```
refactor: auth-service 程式碼品質增強（JSDoc、註解、錯誤格式）

- 補完 authService.register/login 的 JSDoc (@param、@returns、@throws)
- 補完 userRepository.findByEmail/save 的 JSDoc
- 簡化 authService catch 區塊過度詳細的內部註解
- 統一 validateMiddleware 錯誤回應格式為 {error, message}

無功能改動，14/14 單元測試通過。
```

---

## 總預估工時

**5 + 5 + 5 + 8 + 5 = 28 分鐘**

（前一版本估計為 25 分鐘，因新增 4.2 驗證項而調整為 28 分鐘）
