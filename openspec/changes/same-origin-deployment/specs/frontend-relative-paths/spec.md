# Frontend Relative Paths

## ADDED Requirements

### Requirement: 所有 API 呼叫改用相對路徑
前端 JavaScript 中的所有 `fetch()` 呼叫 MUST 使用相對路徑（以 `/` 開頭），不寫主機名。

#### Scenario: 登入 API 呼叫
- **WHEN** auth 前端執行 `const res = await fetch('/api/auth/login', { method: 'POST', body: JSON.stringify({...}) })`
- **THEN** 瀏覽器自動補上當前網域，實際連線到 `http://localhost:8080/api/auth/login`

#### Scenario: 跨前端 fetch（消除 bootstrap 問題）
- **WHEN** lobby 前端啟動時調用 `fetch('/api/config')`
- **THEN** 無需事先知道 gateway 位址，相對路徑自動使用當前網域

### Requirement: 前端間跳轉改用相對路徑
前端使用 `window.location.href` 或 `<a>` 標籤跳轉到其他前端時，MUST 用相對路徑或相對網址，不寫 `http://localhost:port`。

#### Scenario: 從 lobby 跳轉到登入
- **WHEN** lobby 的登出按鈕執行 `window.location.href = '/login'`
- **THEN** 跳轉到 `http://localhost:8080/login`（而非硬寫 `http://localhost:5173`）

#### Scenario: 從聊天室返回大廳
- **WHEN** chat 前端的返回按鈕執行 `window.location.href = '/'`
- **THEN** 跳轉到 `http://localhost:8080/`（大廳根目錄）

### Requirement: 環境變數不再需要前端網址清單
config-loader 中關於「各前端的 URL」的環境變數和邏輯可大幅簡化或移除，因為前端已改用相對路徑跳轉。

#### Scenario: config.json 簡化
- **WHEN** 前端載入 `/api/config` 
- **THEN** 回傳的 `frontends` 物件可為空或移除（前端不再需要）

