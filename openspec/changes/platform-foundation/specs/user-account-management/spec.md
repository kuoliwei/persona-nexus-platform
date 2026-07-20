## 新增需求

### 需求：透過電子郵件檢索使用者
系統應透過電子郵件地址檢索使用者記錄。這用於 auth-service 在登入和註冊期間檢查電子郵件是否已存在。

#### 情境：找到使用者
- **當** user-service 收到 `GET /users?email=user@example.com`
- **則** 系統回傳使用者記錄 `{ id, email }`，HTTP 200

#### 情境：找不到使用者
- **當** user-service 收到 `GET /users?email=nonexistent@example.com`
- **則** 系統回傳 HTTP 404（未找到）

### 需求：透過 ID 檢索使用者
系統應透過 ID 檢索完整使用者記錄。這用於前端在認證後取得使用者個人資料。

#### 情境：透過 ID 找到使用者
- **當** 前端發送 `GET /users/:id`，包含有效的 `x-user-id` header
- **則** 系統回傳使用者記錄 `{ id, email }`，HTTP 200

#### 情境：找不到使用者
- **當** 前端發送 `GET /users/:id`，ID 不存在
- **則** 系統回傳錯誤碼 `USER_NOT_FOUND`，HTTP 404

### 需求：建立使用者
系統應接受來自 auth-service 的使用者建立請求。Auth-service 提供已預先雜湊的密碼。

#### 情境：成功建立使用者
- **當** auth-service 呼叫 `POST /users`，包含 `{ id, email, password }`
- **則** 系統儲存使用者記錄，回傳 `{ id, email }`，HTTP 201

#### 情境：重複電子郵件
- **當** auth-service 呼叫 `POST /users`，電子郵件已存在
- **則** 系統回傳錯誤碼 `EMAIL_ALREADY_EXISTS`，HTTP 409

#### 情境：缺少必填欄位
- **當** 請求主體缺少 `id`、`email` 或 `password`
- **則** 系統回傳錯誤碼 `MISSING_REQUIRED_FIELDS`，HTTP 400

### 需求：刪除使用者
系統應允許透過 ID 刪除使用者帳號。刪除通常由使用者請求或管理員操作觸發。

#### 情境：成功刪除
- **當** 認證使用者發送 `DELETE /users/:id`，且 `x-user-id` 與之相符
- **則** 系統刪除使用者記錄，回傳 HTTP 204（無內容）

#### 情境：找不到使用者
- **當** 請求指向不存在的使用者 ID
- **則** 系統回傳錯誤碼 `USER_NOT_FOUND`，HTTP 404

#### 情境：未授權的刪除嘗試
- **當** 認證使用者嘗試刪除其他使用者的帳號
- **則** 系統回傳錯誤碼 `FORBIDDEN`，HTTP 403

### 需求：密碼儲存規約
系統不應執行密碼雜湊。Auth-service 負責在呼叫 user-service 之前對密碼進行雜湊。User-service 儲存接收到的任何密碼（已由 auth-service 雜湊）。

#### 情境：收到預先雜湊的密碼
- **當** auth-service 透過 `POST /users` 發送雜湊密碼
- **則** user-service 按原樣儲存，不重新雜湊
- **並且** 儲存的密碼為 bcrypt 格式（例如 `$2b$10$...`）

### 需求：錯誤碼標準化
錯誤回應必須遵循一致的格式，並包含適當的 HTTP 狀態碼。

#### 情境：重複電子郵件時的錯誤回應
- **當** 建立失敗，原因為重複電子郵件
- **則** 系統回傳 `{ status: "error", message: "..." }`，HTTP 409

| 錯誤碼 | HTTP 狀態碼 | 含義 |
|---|---|---|
| USER_NOT_FOUND | 404 | 使用者 ID 不存在 |
| EMAIL_ALREADY_EXISTS | 409 | 電子郵件已被使用 |
| MISSING_REQUIRED_FIELDS | 400 | 缺少必填欄位（id、email 或 password） |
| FORBIDDEN | 403 | 使用者沒有權限執行操作 |
| UNKNOWN_SERVER_ERROR | 500 | 非預期的伺服器錯誤 |

## 資料模型

### User 表
- `id` (String, PK)：唯一使用者識別碼（例如 `usr_1720000000000`）
- `email` (String, unique)：使用者的電子郵件地址
- `password` (String)：Bcrypt 雜湊密碼（儲存為明文字串在 DB 中，但內容為雜湊值）
- `createdAt` (DateTime)：帳號建立時間戳
- `updatedAt` (DateTime)：最後更新時間戳

**索引：**
- `email`（唯一約束，用於快速電子郵件查詢）

**遷移：**
- `init` — 初始結構描述建立，包含 User 表

## API 端點

### GET /users?email=:email
**查詢參數：**
- `email` (string, required)：要搜尋的電子郵件地址

**回應 200（找到使用者）：**
```json
{
  "id": "usr_1720000000000",
  "email": "user@example.com"
}
```

**回應 404（找不到使用者）：**
```json
{
  "status": "error",
  "message": "找不到使用者"
}
```

### GET /users/:id
**路徑參數：**
- `id` (string, required)：使用者 ID

**Header：**
- `x-user-id` (string)：由 gateway 注入，識別認證使用者

**回應 200：**
```json
{
  "id": "usr_1720000000000",
  "email": "user@example.com"
}
```

**回應 404：**
```json
{
  "status": "error",
  "message": "找不到使用者"
}
```

### POST /users
**請求主體：**
```json
{
  "id": "usr_1720000000000",
  "email": "user@example.com",
  "password": "$2b$10$bcrypthashhere..."
}
```

**回應 201：**
```json
{
  "id": "usr_1720000000000",
  "email": "user@example.com"
}
```

**回應 409（重複電子郵件）：**
```json
{
  "status": "error",
  "message": "該電子郵件已被註冊"
}
```

### DELETE /users/:id
**路徑參數：**
- `id` (string, required)：要刪除的使用者 ID

**Header：**
- `x-user-id` (string)：由 gateway 注入；如果不等於 `:id`，請求被拒絕

**回應 204：**
（無內容）

**回應 403（未授權）：**
```json
{
  "status": "error",
  "message": "你沒有權限刪除此使用者"
}
```

**回應 404（找不到使用者）：**
```json
{
  "status": "error",
  "message": "找不到使用者"
}
```

## 架構說明

**三層設計：**
- **Controller** (`userController.js`)：HTTP 請求/回應處理，錯誤碼 → HTTP 狀態碼對應
- **Service** (`userService.js`)：業務邏輯，驗證，語意錯誤拋出
- **Repository** (`userRepository.js`)：純 DB 操作，透過 Prisma

**密碼處理職責分工：**
- Auth-service：使用 bcrypt 進行雜湊，發送雜湊值
- User-service：按原樣儲存，永不雜湊或驗證（無狀態設計）

## 環境變數

- `DATABASE_URL` — SQLite 資料庫檔案路徑（例如 `file:./prisma/dev.db`）
- `PORT` — User-service 監聽的連接埠（預設：4000）

## 依賴

- **express** ^5 — Web 框架
- **@prisma/client** ^7 — ORM
- **@prisma/adapter-libsql** — SQLite 適配器
- **@libsql/client** — SQLite 驅動程式

## 已知限制

- 沒有使用者個人資料更新端點（僅建立、讀取、刪除）
- 沒有批量操作（例如批量刪除）
- 沒有軟刪除（刪除是永久的）
- 沒有使用者刪除的稽核日誌
