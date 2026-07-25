## 新增需求

> 2026-07-25 更新：本檔案已依《微服務架構準則.md》《微服務架構實作spec.md》與《執行日誌.md》記錄的 T12、T22 修正結果同步。主要變化：成功／錯誤回應格式改為 `{error, message}` / 直接物件（不再是 `{status, message, data}` 包裹）；`EMAIL_ALREADY_EXISTS` 的 HTTP 狀態碼從 400 修正為 409（對齊 spec 第三部分「HTTP Status Code 統一定義」與 user-service 同名錯誤碼）。2026-07-26 進階整合測試案例 1、G3、J1 已對格式與狀態碼做過正式驗證。

### 需求：使用者註冊
系統應允許新使用者使用電子郵件和密碼進行註冊。密碼必須使用 bcrypt（saltRounds=10）進行雜湊後再儲存。系統不應儲存明文密碼。

#### 情境：成功註冊
- **當** 使用者提交 `POST /auth/register`，包含有效電子郵件和密碼
- **則** 系統建立使用者記錄，回傳 `{ id, email }`，HTTP 201

#### 情境：重複電子郵件被拒絕
- **當** 使用者提交註冊請求，使用已存在的電子郵件
- **則** 系統回傳錯誤碼 `EMAIL_ALREADY_EXISTS`，HTTP 409（2026-07-25 由 T22 修正，此前誤回 400，已於 2026-07-26 案例 J1 實測驗證為 409）

#### 情境：無效的電子郵件格式
- **當** 使用者提交註冊請求，格式不正確的電子郵件
- **則** 系統回傳錯誤碼 `INVALID_EMAIL`，HTTP 400

#### 情境：缺少必填欄位
- **當** 使用者提交註冊請求，缺少電子郵件或密碼
- **則** 系統回傳錯誤碼 `MISSING_REQUIRED_FIELDS`，HTTP 400

### 需求：使用者登入
系統應透過電子郵件和密碼驗證使用者，登入成功時回傳 JWT 令牌。

#### 情境：成功登入
- **當** 使用者提交 `POST /auth/login`，包含有效電子郵件和正確密碼
- **則** 系統回傳 `{ id, email, token }`，HTTP 200，其中令牌有效期為 7 天

#### 情境：未知使用者
- **當** 使用者提交登入請求，電子郵件不存在
- **則** 系統回傳錯誤碼 `UNKNOWN_USER`，HTTP 400（訊息：「電子郵件或密碼錯誤」）

#### 情境：密碼不正確
- **當** 使用者提交登入請求，電子郵件正確但密碼錯誤
- **則** 系統回傳錯誤碼 `EMAIL_OR_PASSWORD_NOTMATCH`，HTTP 400（訊息：「電子郵件或密碼錯誤」）

### 需求：JWT 令牌管理
系統應使用 `JWT_SECRET` 環境變數簽署 JWT 令牌，payload 僅包含 `{ id: userId }`，過期時間設為 7 天。

#### 情境：令牌生成
- **當** 使用者成功登入
- **則** 系統透過 `generateToken(userId)` 生成令牌，有效期 7 天

#### 情境：令牌過期
- **當** 令牌已過期（建立時間 + 7 天 < 現在）
- **則** gateway 的 JWT 驗證拒絕令牌，回傳 HTTP 401

### 需求：密碼安全性
密碼應使用 bcrypt 進行雜湊，saltRounds=10。系統應在登入時使用 `bcrypt.compare()` 驗證密碼。

#### 情境：密碼雜湊於註冊時
- **當** 使用者以密碼「mypassword123」進行註冊
- **則** 系統儲存雜湊後的版本（例如 `$2b$10$...`），絕不儲存明文

#### 情境：密碼比對於登入時
- **當** 使用者以密碼「mypassword123」登入，針對現有的雜湊密碼
- **則** `bcrypt.compare()` 回傳 true，登入成功

### 需求：錯誤碼標準化
系統應回傳標準化錯誤碼，作為 HTTP 回應主體的一部分。每個錯誤碼必須對應特定的 HTTP 狀態碼。

#### 情境：錯誤回應格式
- **當** 發生錯誤（例如 `EMAIL_ALREADY_EXISTS`）
- **則** 系統回傳 `{ error: "<CODE>", message: "..." }`，包含適當的 HTTP 狀態碼（2026-07-25 由 T12 從舊格式 `{status:"error", message}` 修正）

| 錯誤碼 | HTTP 狀態碼 | 含義 |
|---|---|---|
| EMAIL_ALREADY_EXISTS | 409 | 電子郵件已被註冊 |
| INVALID_EMAIL | 400 | 電子郵件格式無效 |
| MISSING_REQUIRED_FIELDS | 400 | 缺少必填欄位（電子郵件或密碼） |
| UNKNOWN_USER | 400 | 系統中找不到電子郵件 |
| EMAIL_OR_PASSWORD_NOTMATCH | 400 | 密碼不正確 |
| UNKNOWN_SERVER_ERROR | 500 | 非預期的伺服器錯誤 |

## 資料模型變更

### 新增表：User（透過 user-service）
- `id` (String, PK)：`usr_<timestamp>`
- `email` (String, unique)：使用者的電子郵件地址
- `password` (String)：雜湊後的密碼（bcrypt 輸出）
- `createdAt` (DateTime)：帳號建立時間戳
- `updatedAt` (DateTime)：最後更新時間戳

**索引：**
- `email`（唯一約束）

**注意：** Auth-service 本身無資料庫。它透過 HTTP 呼叫將使用者儲存委派給 user-service。

## API 端點

### POST /auth/register
**請求：**
```json
{
  "email": "user@example.com",
  "password": "securePassword123"
}
```

**回應 201：** 直接回傳物件本身（無外層包裹，2026-07-25 由 T12 修正，此前是 `{status,message,data}` 包裹）
```json
{
  "id": "usr_1720000000000",
  "email": "user@example.com"
}
```

**回應 409 (EMAIL_ALREADY_EXISTS)：**
```json
{
  "error": "EMAIL_ALREADY_EXISTS",
  "message": "該電子郵件已被註冊，請更換帳號。"
}
```

### POST /auth/login
**請求：**
```json
{
  "email": "user@example.com",
  "password": "securePassword123"
}
```

**回應 200：** 直接回傳物件本身（無外層包裹，2026-07-25 由 T12 修正）
```json
{
  "id": "usr_1720000000000",
  "email": "user@example.com",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**回應 400 (UNKNOWN_USER 或 EMAIL_OR_PASSWORD_NOTMATCH)：**
```json
{
  "error": "UNKNOWN_USER",
  "message": "電子郵件或密碼錯誤。請再試一次。"
}
```

## 環境變數

- `JWT_SECRET` — JWT 簽署的祕密鑰匙（必須與 api-gateway 的 `JWT_SECRET` 相同）
- `GATEWAY_URL` — api-gateway 的 URL，用於透過 `/internal/users` 進行使用者儲存（預設：`http://localhost:8000`；2026-07-25 由 T6 取代舊的 `USER_SERVICE_URL` 直連設定，不再直連 user-service:4000）
- `PORT` — Auth-service 監聽的連接埠（預設：3000）

## 依賴

- **bcrypt** ^6.0.0 — 密碼雜湊
- **jsonwebtoken** ^9.0.3 — JWT 簽署和驗證
- **user-service** — 外部 HTTP 依賴，用於使用者持久化

## 已知限制

- Auth-service 沒有自己的資料庫；它依賴 user-service 進行持久化
- 登入/註冊端點上沒有速率限制（存在暴力破解風險）
- 沒有電子郵件驗證（電子郵件不經確認即被接受）
- 沒有密碼重設功能
