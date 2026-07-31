## 1. 抽取 assertOk 輔助函式

- [x] 1.1 `src/api.js` 新增內部函式 `async function assertOk(response) { ... }`，邏輯照搬四個函式共有的 `if (!response.ok) {...}` 區塊
- [x] 1.2 `getCharacter` 改為呼叫 `await assertOk(response)` 取代原本的判斷區塊
- [x] 1.3 `updateCharacter` 改為呼叫 `await assertOk(response)`
- [x] 1.4 `createCharacter` 改為呼叫 `await assertOk(response)`
- [x] 1.5 `deleteCharacter` 改為呼叫 `await assertOk(response)`
- [x] 1.6 `npm run build` 確認打包成功

## 2. 修正 CLAUDE.md 過時文檔

- [x] 2.1 修正「已知設計落差」段落，移除「直打 character-service 沒經過 gateway」的過時敘述，改為記錄已於 2026-07-31 查證此落差已不存在

## 3. 回歸驗證

- [x] 3.1 瀏覽器走查：創建角色成功情境（含表單清空、1.5 秒後導向「我的角色」）
- [x] 3.2 瀏覽器走查：創建角色失敗情境（改用編輯不存在角色的 404 情境驗證 assertOk 錯誤路徑：後端「角色不存在」訊息被正確攔截，UI 顯示「❌ 載入失敗，請稍後重試。」）
- [x] 3.3 瀏覽器走查：編輯角色成功情境（載入既有資料、更新成功訊息）
- [x] 3.4 瀏覽器走查：刪除角色成功情境（顯示「角色已刪除！」）
- [x] 3.5 對照 `openspec/changes/character-api-error-handling-dedup/specs/character-frontend-api-error-handling/spec.md` 逐條確認每個 Scenario 皆通過
- [x] 3.6 `git diff` 檢查 `create.js`／`edit.js`／`form.js`／`fewShots.js`／`config-loader.js`／`api.dev.js` 無非預期改動（確認為空 diff）
