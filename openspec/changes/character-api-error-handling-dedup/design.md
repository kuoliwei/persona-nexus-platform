## Context

`api.js` 的四個對外函式目前各自內嵌相同的錯誤處理三行程式碼。這是本次系列稽核（[[chat-frontend-code-quality-optimization]]、[[lobby-router-consolidation]]）中規模最小的一筆——純粹的 DRY 抽取，沒有職責邊界、狀態管理或呼叫慣例上的爭議。

## Goals / Non-Goals

**Goals:**
- 把重複 4 次的錯誤處理邏輯收斂成一個函式，改一次規則（例如日後要在錯誤訊息加上 HTTP method 資訊）只需改一處
- 修正 `CLAUDE.md` 與程式碼現況矛盾的文檔

**Non-Goals:**
- 不改變錯誤訊息的文案或格式
- 不引入全域錯誤處理框架或攔截器（YAGNI，四個呼叫點不需要）
- 不處理 `persona-nexus-auth` 的兩組 2 次重複（未達三次法則門檻）

## Decisions

### assertOk(response) 用拋出例外而非回傳值
```js
async function assertOk(response) {
  if (!response.ok) {
    const error = await response.json().catch(() => ({ message: '未知錯誤' }));
    throw new Error(error.message || `HTTP ${response.status}`);
  }
}
```
維持原本「非 2xx 時拋出 `Error`，呼叫端用 `try/catch` 接」的既有慣例（`create.js`／`edit.js` 已經是這樣寫），不改變呼叫端的錯誤處理方式，只搬移重複的判斷邏輯本身。

### 不順便處理 CLAUDE.md 之外的其他過時內容
本輪只修正稽核中發現、且與本次改動直接相關的「已知設計落差」段落，不做全文件重新校對（範圍控制）。

## Risks / Trade-offs

- **[風險] 抽取時誤改錯誤訊息判斷順序** → 緩解：`assertOk` 內容逐字照搬四個函式共有的區塊，不做「順便改進」
- **[取捨] 函式名不對外 export** → 可接受：`assertOk` 只在 `api.js` 內部使用，不需要成為公開介面

## Migration Plan

1. 在 `api.js` 新增 `assertOk(response)` 函式
2. 四個函式依序改為呼叫 `assertOk(response)`，每改一個立即比對邏輯是否完全等價
3. `npm run build` 確認打包成功
4. 修正 `CLAUDE.md` 過時段落
5. 瀏覽器走查三個流程（創建/編輯/刪除，含失敗情境）

無需 rollback 策略——純前端內部重構，不涉及資料庫或已部署契約。

## Open Questions

無。
