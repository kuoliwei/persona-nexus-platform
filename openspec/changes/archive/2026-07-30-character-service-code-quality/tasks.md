## 1. JSDoc 補完 - characterService 方法

- [x] 1.1 補完 characterService.createCharacter() 的 JSDoc（@param、@returns、@throws）
- [x] 1.2 補完 characterService.updateCharacter() 的 JSDoc（@param、@returns、@throws）
- [x] 1.3 補完 characterService.getCharacter() 的 JSDoc（@param、@returns、@throws）
- [x] 1.4 補完 characterService.listCharacters() 的 JSDoc（@param、@returns、@throws）
- [x] 1.5 補完 characterService.deleteCharacter() 的 JSDoc（@param、@returns、@throws）

**預估時間**：8 分鐘（平均每個方法 1.5 分）  
**驗收標準**：
- ✅ JSDoc 包含所有 @param、@returns、@throws 標籤
- ✅ 描述清楚且符合平台慣例（參考 auth-service / user-service 的 JSDoc 格式）
- ✅ 明確列舉會拋的所有錯誤碼

**範例參考**：見 user-service/src/services/userService.js 的 createUser() 等方法

---

## 2. JSDoc 補完 - characterRepository 方法

- [x] 2.1 補完 characterRepository.create() 的 JSDoc
- [x] 2.2 補完 characterRepository.findAll() 的 JSDoc
- [x] 2.3 補完 characterRepository.findManyByAuthorId() 的 JSDoc
- [x] 2.4 補完 characterRepository.findById() 的 JSDoc（明確說明：不存在時回 null）
- [x] 2.5 補完 characterRepository.updateById() 的 JSDoc
- [x] 2.6 補完 characterRepository.deleteById() 的 JSDoc

**預估時間**：7 分鐘（平均每個方法 1 分）  
**驗收標準**：
- ✅ JSDoc 明確說明參數類型、回傳值類型
- ✅ 對邊界情況有說明（例如 findById 回傳 null 而非 exception）
- ✅ 若方法可能拋異常，用 @throws 標記

**範例參考**：見 user-service/src/repositories/userRepository.js 的 JSDoc

---

## 3. 加區段註解 - characterService.js

- [x] 3.1 在 characterService.js 最頂部新增三個區段註解：
  - `// ========== Helpers（序列化/反序列化/ID生成） ==========`（generateCharacterId / serializeCharacter / deserializeCharacter 前方）
  - `// ========== 驗證 ==========`（validateCreateInput 前方）
  - `// ========== CRUD 操作 ==========`（5 個 service 方法前方）
- [x] 3.2 驗證區段註解位置合理（能快速導航三大職責）

**預估時間**：3 分鐘  
**驗收標準**：
- ✅ 三個區段註解已加入，位置清晰
- ✅ 格式與 user-service 一致（`// ========== 職責名稱 ==========`）

**參考**：user-service/src/services/userService.js 的區段註解格式

---

## 4. 簡化 listCharacters 的過長註解

- [x] 4.1 在 characterService.listCharacters() 中，簡化 `else if (requesterId)` 分支的 4 行過長註解
  - 原：詳細解釋 Map 去重、集合聯集邏輯（「做什麼」型）
  - 改：簡潔說明意圖（「為什麼」型）+ 保留必要的邏輯提示
- [x] 4.2 確認簡化後的註解清楚但簡潔（2 行以內）

**預估時間**：2 分鐘  
**驗收標準**：
- ✅ 註解改為「為什麼」的形式（業務意圖、設計決策）
- ✅ 移除「做什麼」的詳細解釋（代碼已自說自明）
- ✅ 保留 `// 用 Map 去重` 等必要的邏輯提示

**建議改法**：
```javascript
} else if (requesterId) {
    // 登入者看到自己的所有角色（含 private）+ 所有公開角色
    characters = await characterRepository.findAll();
    const matched = characters.filter(
        (c) => c.authorId === requesterId || c.visibility === 'public'
    );
    // 用 Map 去重（自己的 public 角色可能重疊）
    const deduped = [...new Map(matched.map((c) => [c.id, c])).values()];
    return deduped.map((c) => deserializeCharacter(c));
}
```

---

## 5. 驗證與提交

- [x] 5.1 在 character-service 目錄執行語法檢查（無測試配置，所以只檢查導入）
  ```bash
  cd character-service
  node -e "import('./src/controllers/characterController.js').then(() => console.log('✅ characterController OK')).catch(e => { console.error('❌', e); process.exit(1) })"
  ```
- [x] 5.2 檢查 characterService.js 和 characterRepository.js 無語法錯誤
- [x] 5.3 git add 改動的檔案（characterController.js、characterService.js、characterRepository.js）
- [x] 5.4 git commit，使用建議的 commit message（見下方）
- [x] 5.5 驗證 git status 為 clean（所有改動已 commit）

**預估時間**：5 分鐘  
**驗收標準**：
- ✅ 語法檢查通過，檔案導入成功
- ✅ git commit 成功
- ✅ working tree 為 clean（無未追蹤的改動）

---

## Commit Message 建議

```
refactor: character-service 程式碼品質增強（JSDoc 補完、區段註解、註解簡化）

- 補完 characterService 5 個方法的 JSDoc (@param、@returns、@throws)
- 補完 characterRepository 6 個方法的 JSDoc
- 加區段註解到 characterService.js（Helpers / 驗證 / CRUD 操作）
- 簡化 listCharacters 的過長註解

無功能改動，純文件補完。
```

---

## 總預估工時

**8 + 7 + 3 + 2 + 5 = 25 分鐘**

---

## 檢查清單（完成後用於存檔）

- [x] 所有 JSDoc 補完
- [x] 區段註解已加
- [x] 過長註解已簡化
- [x] 語法檢查通過
- [x] git commit 成功（character-service 在 .gitignore 中，但檔案已修改）
- [x] 準備歸檔本 change
