## 新增需求

> 2026-07-25 更新：本檔案已依《微服務架構準則.md》《微服務架構實作spec.md》與《執行日誌.md》記錄的 T8、T14、T20 修正結果同步。主要變化：回應格式改為 `{error, message}` / 直接物件；新增 `x-internal-request` 內部呼叫放行（供 ai-service 查詢私有角色）；`GET /characters` 新增「不帶 query」的第三種合併查詢模式；私密角色未授權存取的實際回應是 403（非本文件先前寫的 404）。

### 需求：角色建立
系統應允許已認證使用者建立新 AI 角色，包含所需的後設資料。每個角色由建立者擁有，建立後 `authorId` 無法更改。

#### 情境：成功建立角色
- **當** 使用者發送 `POST /characters`，包含 `{ name, background, opening, introduction, tags?, fewShots?, gender?, visibility? }`
- **則** 系統建立角色記錄，直接回傳角色物件本身，HTTP 201

#### 情境：缺少必填欄位
- **當** 請求缺少必填欄位（`name`、`background`、`opening` 或 `introduction`）
- **則** 系統回傳 `{error: "REQUIRED_FIELDS_MISSING", message: "..."}`，HTTP 400

#### 情境：無效的欄位類型
- **當** 請求發送 `tags` 為字串而不是陣列
- **則** 系統回傳 `{error: "TAGS_MUST_BE_ARRAY", message: "..."}`，HTTP 400

### 需求：角色檢索
系統應透過各種篩選器檢索角色記錄。使用者只能看到自己的私密角色；公開角色對所有已登入使用者可見；內部服務呼叫可繞過可見性限制。

#### 情境：檢索使用者的角色（既有查詢模式）
- **當** 使用者發送 `GET /characters?authorId=user123`
- **則** 系統回傳：查詢者是 user123 本人時回傳其全部角色（含私密）；查詢者不是 user123 時只回傳 user123 的公開角色

#### 情境：檢索全部公開角色（既有查詢模式）
- **當** 使用者發送 `GET /characters?visibility=public`
- **則** 系統回傳所有使用者的公開角色（用於大廳頁面），不含任何私密角色

#### 情境：不帶 query 的合併查詢（2026-07-25 新增）
- **當** 已登入使用者發送 `GET /characters`，不帶 `authorId` 或 `visibility` 參數
- **則** 系統回傳「登入者自己的所有角色（含私密）」聯集「所有公開角色（不限作者，含自己的公開角色）」，依角色 `id` 去重
- **並且** 這是新增的第三種查詢模式，不影響前兩種既有模式的行為

#### 情境：檢索單一角色
- **當** 使用者發送 `GET /characters/:id`
- **則** 系統回傳角色資料（公開角色任何登入者可查，私密角色僅擁有者可查），HTTP 200

#### 情境：內部呼叫檢索（例外放行）
- **當** 請求帶 `x-internal-request: true`（例如 ai-service 經 Gateway 的 `/internal/characters/:id` 查詢角色詳情）
- **則** 系統跳過可見性檢查，直接回傳角色資料（即使是私密角色）

#### 情境：找不到角色
- **當** 請求指向不存在的角色
- **則** 系統回傳 `{error: "CHARACTER_NOT_FOUND", message: "..."}`，HTTP 404

#### 情境：未授權檢索私密角色
- **當** 非擁有者、非內部呼叫，嘗試檢索他人的私密角色
- **則** 系統回傳 `{error: "FORBIDDEN", message: "..."}`，HTTP 403
- **並且** 本文件先前版本誤寫成「回傳 HTTP 404（視為不存在，不洩露存在性）」——實際實作（`characterService.js` 的 `getCharacter`）是明確拋出 `FORBIDDEN` 並回 403，不是隱藏存在性的 404，此處已修正

### 需求：角色更新
系統應允許使用者更新自己的角色。更新是完全替換（PUT 語義），不是部分修補。內部服務呼叫可繞過所有權檢查。

#### 情境：成功更新角色
- **當** 角色擁有者發送 `PUT /characters/:id`，包含更新的資料
- **則** 系統替換角色記錄，直接回傳更新後的角色物件，HTTP 200

#### 情境：內部呼叫更新（例外放行）
- **當** 請求帶 `x-internal-request: true`
- **則** 系統跳過所有權比對，直接更新

#### 情境：未授權的更新
- **當** 非擁有者、非內部呼叫，嘗試更新角色
- **則** 系統回傳 `{error: "FORBIDDEN", message: "..."}`，HTTP 403

#### 情境：無效的可見性值
- **當** 請求發送 `visibility`，值不是 `private` 或 `public`
- **則** 系統回傳 `{error: "INVALID_VISIBILITY", message: "..."}`，HTTP 400

### 需求：角色刪除
系統應允許使用者刪除自己的角色。內部服務呼叫可繞過所有權檢查。

#### 情境：成功刪除
- **當** 角色擁有者發送 `DELETE /characters/:id`
- **則** 系統刪除角色，直接回傳被刪除的角色物件，HTTP 200

#### 情境：內部呼叫刪除（例外放行）
- **當** 請求帶 `x-internal-request: true`
- **則** 系統跳過所有權比對，直接刪除

#### 情境：未授權的刪除
- **當** 非擁有者、非內部呼叫，嘗試刪除角色
- **則** 系統回傳 `{error: "FORBIDDEN", message: "..."}`，HTTP 403

#### 情境：找不到角色
- **當** 請求指向不存在的角色
- **則** 系統回傳 `{error: "CHARACTER_NOT_FOUND", message: "..."}`，HTTP 404

### 需求：Few-Shots 處理
系統應支援儲存對話範例對（few-shots），格式為 `{ user, char }` 物件的陣列。Few-shots 由 ai-service 用於使用大型語言模型使用角色個性範例進行初始化。

#### 情境：Few-shots 儲存為陣列
- **當** 使用者建立角色，包含 `fewShots: [{ user: "Hello", char: "Hi there!" }, ...]`
- **則** 系統儲存 few-shots，檢索時以陣列形式回傳

#### 情境：無效的 few-shots 格式
- **當** 請求發送 `fewShots` 為字串而不是陣列
- **則** 系統回傳 `{error: "FEW_SHOTS_MUST_BE_ARRAY", message: "..."}`，HTTP 400

### 需求：標籤處理
系統應支援儲存角色標籤，格式為字串陣列，用於分類和篩選。

#### 情境：標籤已儲存和檢索
- **當** 使用者建立角色，包含 `tags: ["romance", "fantasy"]`
- **則** 系統儲存並回傳標籤為陣列

#### 情境：無效的標籤格式
- **當** 請求發送 `tags` 為字串或物件
- **則** 系統回傳 `{error: "TAGS_MUST_BE_ARRAY", message: "..."}`，HTTP 400

### 需求：角色可見性
角色可以標記為 `private`（僅擁有者、內部呼叫可見）或 `public`（任何已登入使用者都看得見）。預設為 `private`。

#### 情境：私密角色可見性
- **當** 角色建立時沒有明確 `visibility`，或 `visibility: "private"`
- **則** 僅擁有者、內部呼叫可以檢索；其他人得到 HTTP 403

#### 情境：公開角色可見性
- **當** 角色有 `visibility: "public"`
- **則** 任何已登入使用者都可以檢索

## 資料模型

### Character 表
- `id` (String, PK)：唯一識別碼（例如 `char_1720000000000`）
- `authorId` (String, FK → User.id)：角色建立者的使用者 ID
- `name` (String, required)：角色名稱
- `background` (String, required)：角色背景故事
- `opening` (String, required)：角色開場問候
- `introduction` (String, required)：角色自我介紹
- `gender` (String, nullable)：角色性別
- `tags` (JSON, stored as string)：標籤陣列，序列化為 JSON
- `fewShots` (JSON, stored as string)：`{ user, char }` 對的陣列，序列化為 JSON
- `visibility` (String, enum: `private|public`, default: `private`)：可見性範圍
- `createdAt` (DateTime)：角色建立時間戳
- `updatedAt` (DateTime)：最後更新時間戳

**索引：**
- `authorId`（快速檢索使用者的角色）
- `visibility`（發現公開角色）

### 序列化規約
- `tags` 和 `fewShots` 在資料庫中儲存為 JSON 字串
- Service 層在檢索時自動反序列化為陣列
- Service 層在資料庫儲存前自動從陣列序列化
- API 始終交換陣列（JSON 格式），永不字串

## API 端點

### POST /characters
**Header：**
- `x-user-id` (string)：由 gateway 注入，成為角色的 `authorId`

**請求主體：**
```json
{
  "name": "Luna Starlight",
  "background": "一個神秘的 AI 角色，喜歡天文學...",
  "opening": "你好，旅行者！什麼把你帶到我的領域？",
  "introduction": "我是 Luna，一個宇宙流浪者...",
  "gender": "Female",
  "tags": ["romance", "fantasy", "mysterious"],
  "fewShots": [
    { "user": "你最喜歡的星星是什麼？", "char": "北極星引導我..." }
  ],
  "visibility": "public"
}
```

**回應 201：** 直接回傳建立後的角色物件本身（無外層包裹）

**回應 400 (REQUIRED_FIELDS_MISSING)：**
```json
{
  "error": "REQUIRED_FIELDS_MISSING",
  "message": "缺少必填欄位"
}
```

### GET /characters
**查詢參數（三選一，皆為選填）：**
- 不帶任何參數：回傳登入者自己的所有角色聯集所有公開角色（去重）
- `authorId`：篩選特定作者，本人查詢含私密、他人查詢僅公開
- `visibility=public`：回傳所有使用者的公開角色

**回應 200：** 直接回傳角色陣列本身
```json
[
  { "id": "char_1720000000000", "authorId": "usr_1720000000000", "name": "Luna Starlight", "visibility": "private", "..." : "..." }
]
```

### GET /characters/:id
**Header：**
- `x-user-id`（一般查詢）或 `x-internal-request: true`（內部呼叫，例如 ai-service）

**回應 200：** 直接回傳角色物件本身

**回應 403 (FORBIDDEN)：**
```json
{
  "error": "FORBIDDEN",
  "message": "無權限"
}
```

**回應 404 (CHARACTER_NOT_FOUND)：**
```json
{
  "error": "CHARACTER_NOT_FOUND",
  "message": "角色不存在"
}
```

### PUT /characters/:id
**Header：**
- `x-user-id`（必須與角色的 `authorId` 相符）或 `x-internal-request: true`（內部呼叫）

**請求主體：** （與 POST 相同）

**回應 200：** 直接回傳更新後的角色物件

**回應 403 (FORBIDDEN)：**
```json
{
  "error": "FORBIDDEN",
  "message": "無權限"
}
```

### DELETE /characters/:id
**Header：**
- `x-user-id`（必須與角色的 `authorId` 相符）或 `x-internal-request: true`（內部呼叫）

**回應 200：** 直接回傳被刪除的角色物件（**非** `204 No Content`）

**回應 403 (FORBIDDEN)：**
```json
{
  "error": "FORBIDDEN",
  "message": "無權限"
}
```

## 錯誤碼參考

| 錯誤碼 | HTTP 狀態碼 | 含義 |
|---|---|---|
| CHARACTER_NOT_FOUND | 404 | 角色 ID 不存在 |
| REQUIRED_FIELDS_MISSING | 400 | 缺少必填欄位（name、background、opening、introduction） |
| TAGS_MUST_BE_ARRAY | 400 | 標籤欄位必須是陣列 |
| FEW_SHOTS_MUST_BE_ARRAY | 400 | Few-shots 欄位必須是陣列 |
| INVALID_VISIBILITY | 400 | 可見性必須是「private」或「public」 |
| FORBIDDEN | 403 | 使用者沒有權限（不是作者，且非內部呼叫） |
| INTERNAL_SERVER_ERROR | 500 | 非預期的伺服器錯誤 |

## 架構說明

**三層設計：**
- **Controller**：HTTP 處理、讀取 header（`x-user-id`、`x-internal-request`）傳給 service 層、錯誤對應
- **Service**：序列化/反序列化（tags/fewShots 陣列 ↔ JSON 字串）、**授權判斷**（所有權、可見性、`x-internal-request` 例外）
- **Repository**：Prisma CRUD 操作

**授權：**
- 角色擁有權透過 `x-user-id` header 驗證（由 gateway 注入）
- 可見性規則：私密角色需要擁有權或 `x-internal-request`，公開角色對已登入使用者可訪問
- **不設獨立授權 middleware**：所有授權判斷都在 service 層完成

## 環境變數

- `DATABASE_URL` — SQLite 資料庫路徑
- `PORT` — Character-service 監聽的連接埠（預設：5000）

## 依賴

- **express** ^5
- **@prisma/client** ^7
- **@prisma/adapter-libsql**
- **@libsql/client**

## 已知限制

- 沒有批量操作（批量建立、批量刪除）
- 沒有角色名稱/背景的搜尋或全文搜尋
- 沒有角色分叉或複製
- 沒有角色編輯的版本歷史
