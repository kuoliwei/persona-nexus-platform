## ADDED Requirements

### Requirement: assertOk 是非 2xx 回應處理的唯一權威來源
`persona-nexus-character` 的 `src/api.js` SHALL 提供內部輔助函式 `assertOk(response)`，封裝「非 2xx 回應時解析錯誤訊息並拋出 `Error`」的邏輯。`getCharacter`／`updateCharacter`／`createCharacter`／`deleteCharacter` 四個函式 MUST 呼叫 `assertOk(response)`，不得各自重複實作相同的判斷邏輯。

#### Scenario: 非 2xx 回應優先使用後端訊息
- **WHEN** API 請求回傳非 2xx 狀態碼，且回應 body 可解析為 JSON 且含 `message` 欄位
- **THEN** `assertOk` 拋出 `Error`，訊息內容為該 `message`

#### Scenario: 無法解析回應內容時退回 HTTP 狀態碼
- **WHEN** API 請求回傳非 2xx 狀態碼，且回應 body 無法解析為 JSON
- **THEN** `assertOk` 拋出 `Error`，訊息內容為 `HTTP <狀態碼>`

#### Scenario: 2xx 回應不拋出例外
- **WHEN** API 請求回傳 2xx 狀態碼
- **THEN** `assertOk` 不拋出例外，呼叫端繼續解析回應內容

### Requirement: 抽取後不改變對外可觀察行為
`persona-nexus-character` 的角色創建、編輯、刪除三個流程，其成功與失敗情境下的錯誤訊息呈現、UI 狀態變化 SHALL 與抽取前完全一致。

#### Scenario: 三個流程的錯誤情境回歸驗證
- **WHEN** 對創建/編輯/刪除三個流程分別觸發成功與失敗情境（如網路異常、後端回傳 4xx/5xx）
- **THEN** 畫面顯示的錯誤訊息與抽取前一致，`npm run build` 成功產出無錯誤
