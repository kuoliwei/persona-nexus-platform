## Why

character-service 現有代碼品質已達可用標準（無高中度缺陷），但缺乏必要文件與可讀性增強。與 auth-service / user-service 的程式碼層優化一致，本輪補完 JSDoc、簡化過長註解、加區段註解，確保：
1. Service 層方法有明確的簽名文件（呼叫方能快速了解會拋什麼錯誤）
2. Repository 層回傳值邊界清晰（避免誤用）
3. 內部代碼結構可快速導航（新維護者上手快）

## What Changes

- ✅ **補完 characterService 的 5 個方法 JSDoc**（createCharacter / updateCharacter / getCharacter / listCharacters / deleteCharacter）
  - 補充 @param、@returns、@throws 標籤
  - 明確說明會拋的所有錯誤碼（UNAUTHORIZED / FORBIDDEN / CHARACTER_NOT_FOUND / REQUIRED_FIELDS_MISSING / TAGS_MUST_BE_ARRAY / FEW_SHOTS_MUST_BE_ARRAY / INVALID_VISIBILITY）

- ✅ **補完 characterRepository 的 6 個方法 JSDoc**（create / findAll / findManyByAuthorId / findById / updateById / deleteById）
  - 明確說明回傳值邊界（例如 findById 不存在時回 null）

- ✅ **加區段註解到 characterService.js**
  - 新增 `// ========== Helpers（序列化/反序列化/ID生成） ==========`
  - 新增 `// ========== 驗證 ==========`
  - 新增 `// ========== CRUD 操作 ==========`

- ✅ **簡化 listCharacters 的過長註解**
  - 移除詳細解釋邏輯的 4 行註解
  - 保留簡潔的「為什麼」說明

## Capabilities

### New Capabilities
<!-- No new capabilities; this is pure code quality enhancement -->

### Modified Capabilities
<!-- 無需求變更；純代碼層改進，無行為改動 -->

## Impact

**程式碼檔案：**
- characterService.js（新增 JSDoc 與區段註解）
- characterRepository.js（新增 JSDoc）

**影響範圍：**
- 無 breaking changes，無業務邏輯改動
- 純文件補完與可讀性增強
- 與 auth-service / user-service 風格對齊

**預期工時：** 20 分鐘（JSDoc 補完 15 分 + 註解調整 5 分）

**測試驗收：**
- 語法檢查通過（無錯誤）
- 無單元測試配置（預期），確認代碼導入成功
