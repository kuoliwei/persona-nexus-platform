## ADDED Requirements

### Requirement: authService catch 區塊註解應說明「為什麼」而非「做什麼」
authService.register() 和 authService.login() 的 catch 區塊內的註解 SHALL 移除過度詳細的「做什麼」描述（例如比喻或簡化的解釋），只保留「為什麼」的邏輯說明（例如區分業務錯誤與系統錯誤）。

#### Scenario: register catch 區塊註解簡化
- **WHEN** 開發者讀取 authService.register() 的 catch 區塊
- **THEN** 註解簡潔地說明「業務錯誤直接拋」vs「系統錯誤統一轉為 UNKNOWN_SERVER_ERROR」，移除「倉庫爆掉」等比喻

#### Scenario: login catch 區塊註解簡化
- **WHEN** 開發者讀取 authService.login() 的 catch 區塊
- **THEN** 註解簡潔地說明「業務錯誤直接拋」vs「系統錯誤統一轉為 UNKNOWN_SERVER_ERROR」，移除冗長解釋

### Requirement: 移除冗長的內部 console.error 前的註解
authService 內 console.error() 前的註解 SHALL 簡化為清楚的說明（例如「userRepository 發生非預期錯誤」），而非「真正的錯誤」或其他模糊表述。

#### Scenario: console.error 註解清楚明確
- **WHEN** 開發者看到 console.error() 語句
- **THEN** 其前面的註解清楚說明「這是什麼類別的錯誤」（例如「userRepository 發生非預期錯誤」）
