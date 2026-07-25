## 新增需求

> 2026-07-25 更新：本檔案已依《微服務架構準則.md》《微服務架構實作spec.md》與《執行日誌.md》記錄的 T4、T5、T7、T13 修正結果同步。主要變化：獨立的 `authorizeSelf` middleware 已移除、授權邏輯搬到 service 層；新增 `x-internal-request` 內部呼叫放行；回應格式改為 `{error, message}` / 直接物件 / `{success, message}`。

### 需求：透過電子郵件檢索使用者（限內部呼叫）
系統應透過電子郵件地址檢索使用者記錄，僅限內部服務呼叫（帶 `x-internal-request: true`）。這用於 auth-service 在登入和註冊期間檢查電子郵件是否已存在，經 Gateway 的 `/internal/users?email=` 轉發。

#### 情境：內部呼叫找到使用者
- **當** 帶 `x-internal-request: true` 的請求打 `GET /users?email=user@example.com`
- **則** 系統回傳完整使用者記錄（含密碼雜湊，供 auth-service 登入比對），HTTP 200

#### 情境：內部呼叫找不到使用者
- **當** 帶 `x-internal-request: true` 的請求打 `GET /users?email=nonexistent@example.com`
- **則** 系統回傳 `{error: "USER_NOT_FOUND", message: "..."}`，HTTP 404

#### 情境：非內部呼叫被拒絕
- **當** 請求缺少 `x-internal-request: true`（例如直打裸 port 或經 Gateway 的 `/api/*` 外部路由）
- **則** 系統回傳 `{error: "FORBIDDEN", message: "..."}`，HTTP 403
- **並且** 這個檢查是 2026-07-25 新增的——此路由過去無條件回傳含密碼雜湊的完整使用者物件，任何能連到 user-service 的呼叫者都能查到任意使用者的密碼雜湊，屬於已修復的安全缺口

### 需求：透過 ID 檢索使用者
系統應透過 ID 檢索使用者記錄（濾掉密碼欄位）。呼叫者必須是資源擁有者本人，或是內部服務呼叫。

#### 情境：本人查詢自己的資料
- **當** 前端發送 `GET /users/:id`，`x-user-id` 與 `:id` 相符
- **則** 系統回傳使用者記錄（`toPublicUser()` 濾掉 `password`），HTTP 200

#### 情境：內部呼叫查詢（例外放行）
- **當** 請求帶 `x-internal-request: true`
- **則** 系統跳過所有權比對，直接查詢並回傳

#### 情境：查詢他人資料被拒絕
- **當** `x-user-id` 與 `:id` 不相符，且非內部呼叫
- **則** 系統回傳 `{error: "FORBIDDEN", message: "..."}`，HTTP 403

#### 情境：缺少 `x-user-id`
- **當** 請求既非內部呼叫、也沒有 `x-user-id` header
- **則** 系統回傳 `{error: "UNAUTHORIZED", message: "..."}`，HTTP 401

#### 情境：找不到使用者
- **當** 前端發送 `GET /users/:id`，ID 不存在
- **則** 系統回傳 `{error: "USER_NOT_FOUND", message: "..."}`，HTTP 404

### 需求：建立使用者（限內部呼叫）
系統應接受來自 auth-service 的使用者建立請求，僅限內部服務呼叫，經 Gateway 的 `/internal/users` 轉發。Auth-service 提供已預先雜湊的密碼。

#### 情境：內部呼叫成功建立使用者
- **當** 帶 `x-internal-request: true` 的請求呼叫 `POST /users`，包含 `{ id, email, password }`
- **則** 系統儲存使用者記錄，回傳 `{ id, email }`（濾掉 password），HTTP 201

#### 情境：非內部呼叫被拒絕
- **當** 請求缺少 `x-internal-request: true`
- **則** 系統回傳 `{error: "FORBIDDEN", message: "..."}`，HTTP 403
- **並且** 這是 2026-07-25 新增的檢查——此路由過去是完全公開、無授權保護的建帳號端點

#### 情境：重複電子郵件
- **當** 內部呼叫 `POST /users`，電子郵件已存在
- **則** 系統回傳 `{error: "EMAIL_ALREADY_EXISTS", message: "..."}`，HTTP 409

#### 情境：缺少必填欄位
- **當** 請求主體缺少 `id`、`email` 或 `password`
- **則** 系統回傳 `{error: "REQUIRED_FIELDS_MISSING", message: "..."}`，HTTP 400

### 需求：刪除使用者
系統應允許透過 ID 刪除使用者帳號。呼叫者必須是資源擁有者本人，或是內部服務呼叫。

#### 情境：本人成功刪除
- **當** 認證使用者發送 `DELETE /users/:id`，`x-user-id` 與 `:id` 相符
- **則** 系統刪除使用者記錄，回傳 `{success: true, message: "..."}`，HTTP 200
- **並且** 這是 2026-07-25 修改的行為——過去回傳 `204 No Content`（無 body），現改為統一格式的 200 + JSON body

#### 情境：內部呼叫刪除（例外放行）
- **當** 請求帶 `x-internal-request: true`
- **則** 系統跳過所有權比對，直接刪除

#### 情境：找不到使用者
- **當** 請求指向不存在的使用者 ID
- **則** 系統回傳 `{error: "USER_NOT_FOUND", message: "..."}`，HTTP 404

#### 情境：未授權的刪除嘗試
- **當** `x-user-id` 與 `:id` 不相符，且非內部呼叫
- **則** 系統回傳 `{error: "FORBIDDEN", message: "..."}`，HTTP 403

### 需求：授權邏輯統一放在 service 層
系統不設獨立的授權 middleware（例如過去的 `authorizeSelf.js`）。Controller 只負責從 header 讀取 `x-user-id`、`x-internal-request` 並傳給 service 層；授權判斷邏輯（是否放行）統一寫在 service 層方法內。

#### 情境：判斷順序
- **當** service 層方法收到 `{ requesterId, isInternalRequest }` 參數
- **則** 若 `isInternalRequest` 為真，放行，跳過所有權檢查
- **否則** 檢查 `requesterId` 是否存在（不存在則 `UNAUTHORIZED`）、`requesterId` 是否等於目標資源擁有者（不等則 `FORBIDDEN`）

### 需求：密碼儲存規約
系統不應執行密碼雜湊。Auth-service 負責在呼叫 user-service 之前對密碼進行雜湊。User-service 儲存接收到的任何密碼（已由 auth-service 雜湊）。

#### 情境：收到預先雜湊的密碼
- **當** auth-service 透過 `POST /users` 發送雜湊密碼
- **則** user-service 按原樣儲存，不重新雜湊
- **並且** 儲存的密碼為 bcrypt 格式（例如 `$2b$10$...`）

### 需求：錯誤碼標準化
錯誤回應必須遵循統一格式 `{ error: "<CODE>", message: "..." }`，並包含適當的 HTTP 狀態碼。

#### 情境：重複電子郵件時的錯誤回應
- **當** 建立失敗，原因為重複電子郵件
- **則** 系統回傳 `{ error: "EMAIL_ALREADY_EXISTS", message: "..." }`，HTTP 409

| 錯誤碼 | HTTP 狀態碼 | 含義 |
|---|---|---|
| USER_NOT_FOUND | 404 | 使用者 ID 不存在 |
| EMAIL_ALREADY_EXISTS | 409 | 電子郵件已被使用 |
| REQUIRED_FIELDS_MISSING | 400 | 缺少必填欄位（id、email 或 password） |
| FORBIDDEN | 403 | 使用者沒有權限執行操作，或非內部呼叫嘗試存取內部端點 |
| UNAUTHORIZED | 401 | 缺少必要的身份識別（`x-user-id`） |
| INTERNAL_SERVER_ERROR | 500 | 非預期的伺服器錯誤 |

## 資料模型

### User 表
- `id` (String, PK)：唯一使用者識別碼（例如 `usr_1720000000000`）
- `email` (String, unique)：使用者的電子郵件地址
- `password` (String)：Bcrypt 雜湊密碼（儲存為明文字串在 DB 中，但內容為雜湊值）
- `createdAt` (DateTime)：帳號建立時間戳
- `updatedAt` (DateTime)：最後更新時間戳

**索引：**
- `email`（唯一約束，用於快速電子郵件查詢）

## API 端點

### GET /users?email=:email（限內部呼叫）
**Header：**
- `x-internal-request: true`（必要，否則 403）

**回應 200（找到使用者）：**
```json
{
  "id": "usr_1720000000000",
  "email": "user@example.com",
  "password": "$2b$10$..."
}
```

**回應 404（找不到使用者）：**
```json
{
  "error": "USER_NOT_FOUND",
  "message": "User not found"
}
```

### GET /users/:id
**Header：**
- `x-user-id`（本人查詢時必要）或 `x-internal-request: true`（內部呼叫）

**回應 200：**
```json
{
  "id": "usr_1720000000000",
  "email": "user@example.com"
}
```

**回應 403（查詢他人）：**
```json
{
  "error": "FORBIDDEN",
  "message": "Forbidden"
}
```

### POST /users（限內部呼叫）
**Header：**
- `x-internal-request: true`（必要，否則 403）

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
  "error": "EMAIL_ALREADY_EXISTS",
  "message": "Email already exists"
}
```

### DELETE /users/:id
**Header：**
- `x-user-id`（本人刪除時必要，需與 `:id` 相符）或 `x-internal-request: true`（內部呼叫）

**回應 200：**
```json
{
  "success": true,
  "message": "User deleted successfully"
}
```

**回應 403（未授權）：**
```json
{
  "error": "FORBIDDEN",
  "message": "Forbidden"
}
```

**回應 404（找不到使用者）：**
```json
{
  "error": "USER_NOT_FOUND",
  "message": "User not found"
}
```

## 架構說明

**三層設計：**
- **Controller** (`userController.js`)：HTTP 請求/回應處理，讀取 header 傳給 service 層，錯誤碼 → HTTP 狀態碼對應
- **Service** (`userService.js`)：業務邏輯、**授權判斷**（`x-internal-request` / `x-user-id` 比對）、語意錯誤拋出
- **Repository** (`userRepository.js`)：純 DB 操作，透過 Prisma

**不設獨立授權 middleware：**
- 2026-07-25 前，授權邏輯寫在獨立的 `authorizeSelf.js` middleware；現已移除，改由 service 層統一處理（詳見上方「授權邏輯統一放在 service 層」需求）

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
