## Why

`persona-nexus-character` 的 `src/api.js` 內四個函式（`getCharacter`／`updateCharacter`／`createCharacter`／`deleteCharacter`）各自逐字重複同一段錯誤處理邏輯（解析錯誤 JSON、取後端訊息或退回 HTTP 狀態碼、拋出 `Error`）。依《程式撰寫設計原則.md》E1「三次法則」（相同邏輯出現 3 次以上才抽成共用函式），這裡出現 4 次已超過門檻，應抽成共用的 `assertOk(response)` 輔助函式。同時 `CLAUDE.md`「已知設計落差」段落聲稱本專案「直打 character-service，沒經過 gateway」，但實際 `api.js` 的 `BASE_URL = '/api'` 早已是走 gateway 的相對路徑（程式碼註解明確寫「透過 Caddy 同源代理打 gateway」），文檔與程式碼矛盾，需要一併修正。

**附帶稽核結論**：`persona-nexus-auth` 的 `src/main.js` 也有兩組形狀相似的重複邏輯（註冊/登入 submit handler、兩個 tab 切換 handler），但都只出現 2 次，套用同一條三次法則判定「不構成違反」，本輪不處理。

## What Changes

- `src/api.js` 新增內部輔助函式 `assertOk(response)`，封裝「非 2xx 時解析錯誤訊息並拋出 `Error`」的邏輯，四個既有函式改為呼叫 `assertOk(response)` 取代各自的 `if (!response.ok) {...}` 區塊
- 修正 `CLAUDE.md` 的「已知設計落差」段落：移除或改寫「直打 character-service 沒經過 gateway」的過時敘述，使其與 `api.js` 現況（走 `/api` 相對路徑經 gateway）一致
- **不改變任何對外行為**：錯誤訊息文案、HTTP 錯誤處理邏輯、成功/失敗時的 UI 呈現皆維持不變，純內部重構 + 文檔修正

## Capabilities

### New Capabilities
- `character-frontend-api-error-handling`：定義 `persona-nexus-character` 前端 API 層錯誤處理的單一權威來源契約——非 2xx 回應的解析與拋出邏輯只能存在於一處，且拆分後行為必須與拆分前完全一致

### Modified Capabilities
（無 spec 層級行為變更——錯誤處理的可觀察行為維持不變，僅內部實作與文檔調整）

## Impact

- **受影響檔案**：`persona-nexus-character/src/api.js`（新增 `assertOk` 輔助函式，四個函式改用它）、`persona-nexus-character/CLAUDE.md`（修正過時的「已知設計落差」段落）
- **不受影響**：`create.js`、`edit.js`、`form.js`、`fewShots.js`、`config-loader.js`、`api.dev.js`（意圖保留的開發期切換工具，非死代碼，不動）、`index.html`、`creator-create.html`、`creator-edit.html`、`style.css`
- **無 API 變更**：不涉及後端契約
- **無依賴變更**：不新增套件
- **驗證方式**：`npm run build` 確認打包成功 + 瀏覽器走查角色創建/編輯/刪除三個流程（含成功與失敗情境的錯誤訊息顯示）
