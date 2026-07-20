## 新增需求

### 需求：角色建立
系統應允許已認證使用者建立新 AI 角色，包含所需的後設資料。每個角色由建立者擁有。

#### 情境：成功建立角色
- **當** 使用者發送 `POST /characters`，包含 `{ name, background, opening, introduction, tags?, fewShots?, gender?, visibility? }`
- **則** 系統建立角色記錄，回傳角色資料，HTTP 201

#### 情境：缺少必填欄位
- **當** 請求缺少必填欄位（`name`、`background`、`opening` 或 `introduction`）
- **則** 系統回傳錯誤碼 `REQUIRED_FIELDS_MISSING`，HTTP 400

#### 情境：無效的欄位類型
- **當** 請求發送 `tags` 為字串而不是陣列
- **則** 系統回傳錯誤碼 `TAGS_MUST_BE_ARRAY`，HTTP 400

### 需求：角色檢索
系統應透過各種篩選器檢索角色記錄。使用者只能看到自己的私密角色；公開角色對所有人可見。

#### 情境：檢索使用者的角色
- **當** 使用者發送 `GET /characters?authorId=user123`
- **則** 系統回傳由 user123 擁有的角色陣列，HTTP 200

#### 情境：檢索單一角色
- **當** 使用者發送 `GET /characters/:id`
- **則** 系統回傳角色資料（公開或由使用者擁有），HTTP 200

#### 情境：找不到角色
- **當** 請求指向不存在的角色
- **則** 系統回傳錯誤碼 `CHARACTER_NOT_FOUND`，HTTP 404

#### 情境：未授權檢索私密角色
- **當** 使用者嘗試檢索其他使用者的私密角色
- **則** 系統回傳 HTTP 404（視為不存在，不洩露存在性）

### 需求：角色更新
系統應允許使用者更新自己的角色。更新是完全替換（PUT 語義），不是部分修補。

#### 情境：成功更新角色
- **當** 角色擁有者發送 `PUT /characters/:id`，包含更新的資料
- **則** 系統替換角色記錄，回傳更新的資料，HTTP 200

#### 情境：未授權的更新
- **當** 非擁有者嘗試更新角色
- **則** 系統回傳錯誤碼 `FORBIDDEN`，HTTP 403

#### 情境：無效的可見性值
- **當** 請求發送 `visibility`，值不是 `private` 或 `public`
- **則** 系統回傳錯誤碼 `INVALID_VISIBILITY`，HTTP 400

### 需求：角色刪除
系統應允許使用者刪除自己的角色。

#### 情境：成功刪除
- **當** 角色擁有者發送 `DELETE /characters/:id`
- **則** 系統刪除角色，回傳 HTTP 204

#### 情境：未授權的刪除
- **當** 非擁有者嘗試刪除角色
- **則** 系統回傳錯誤碼 `FORBIDDEN`，HTTP 403

#### 情境：找不到角色
- **當** 請求指向不存在的角色
- **則** 系統回傳錯誤碼 `CHARACTER_NOT_FOUND`，HTTP 404

### 需求：Few-Shots 處理
系統應支援儲存對話範例對（few-shots），格式為 `{ user, char }` 物件的陣列。Few-shots 由 ai-service 用於使用大型語言模型使用角色個性範例進行初始化。

#### 情境：Few-shots 儲存為陣列
- **當** 使用者建立角色，包含 `fewShots: [{ user: "Hello", char: "Hi there!" }, ...]`
- **則** 系統儲存 few-shots，檢索時以陣列形式回傳

#### 情境：無效的 few-shots 格式
- **當** 請求發送 `fewShots` 為字串而不是陣列
- **則** 系統回傳錯誤碼 `FEW_SHOTS_MUST_BE_ARRAY`，HTTP 400

### 需求：標籤處理
系統應支援儲存角色標籤，格式為字串陣列，用於分類和篩選。

#### 情境：標籤已儲存和檢索
- **當** 使用者建立角色，包含 `tags: ["romance", "fantasy"]`
- **則** 系統儲存並回傳標籤為陣列

#### 情境：無效的標籤格式
- **當** 請求發送 `tags` 為字串或物件
- **則** 系統回傳錯誤碼 `TAGS_MUST_BE_ARRAY`，HTTP 400

### 需求：角色可見性
角色可以標記為 `private`（僅擁有者看見）或 `public`（任何人都看得見）。預設為 `private`。

#### 情境：私密角色可見性
- **當** 角色建立時沒有明確 `visibility`，或 `visibility: "private"`
- **則** 僅擁有者可以檢索；其他人得到 HTTP 404

#### 情境：公開角色可見性
- **當** 角色有 `visibility: "public"`
- **則** 任何使用者（根據 gateway 規則，認證或未認證）都可以檢索

## 資料模型

### Character 表
- `id` (String, PK)：唯一識別碼（例如 `char_1720000000000`）
- `authorId` (String, FK → User.id)：角色建立者的使用者 ID
- `name` (String, required)：角色名稱
- `background` (String, required)：角色背景故事
- `opening` (String, required)：角色開場問候
- `introduction` (String, required)：角色自我介紹（在遷移 `make_introduction_required` 中變為必填）
- `gender` (String, nullable)：角色性別
- `tags` (JSON, stored as string)：標籤陣列，序列化為 JSON
- `fewShots` (JSON, stored as string)：`{ user, char }` 對的陣列，序列化為 JSON
- `visibility` (String, enum: `private|public`, default: `private`)：可見性範圍
- `createdAt` (DateTime)：角色建立時間戳
- `updatedAt` (DateTime)：最後更新時間戳

**索引：**
- `authorId`（快速檢索使用者的角色）
- `visibility`（發現公開角色）

**遷移：**
- `init` — 初始 Character 表建立
- `make_introduction_required` — 將 `introduction` 從可為空改為必填，回填現有行

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
    { "user": "你最喜歡的星星是什麼？", "char": "北極星引導我..." },
    { "user": "給我講個故事", "char": "從前..." }
  ],
  "visibility": "public"
}
```

**回應 201：**
```json
{
  "id": "char_1720000000000",
  "authorId": "usr_1720000000000",
  "name": "Luna Starlight",
  "background": "一個神秘的 AI 角色...",
  "opening": "你好，旅行者!...",
  "introduction": "我是 Luna，一個宇宙流浪者...",
  "gender": "Female",
  "tags": ["romance", "fantasy", "mysterious"],
  "fewShots": [
    { "user": "你最喜歡的星星是什麼？", "char": "北極星..." },
    { "user": "給我講個故事", "char": "從前..." }
  ],
  "visibility": "public",
  "createdAt": "2026-01-20T10:00:00Z",
  "updatedAt": "2026-01-20T10:00:00Z"
}
```

**回應 400 (REQUIRED_FIELDS_MISSING)：**
```json
{
  "status": "error",
  "message": "缺少必填欄位：name、background、opening、introduction"
}
```

### GET /characters?authorId=:authorId
**查詢參數：**
- `authorId` (string, required)：要篩選的使用者 ID

**回應 200：**
```json
[
  {
    "id": "char_1720000000000",
    "authorId": "usr_1720000000000",
    "name": "Luna Starlight",
    "visibility": "private",
    ...
  },
  ...
]
```

### GET /characters/:id
**回應 200：**
```json
{
  "id": "char_1720000000000",
  "authorId": "usr_1720000000000",
  "name": "Luna Starlight",
  ...
}
```

**回應 404 (CHARACTER_NOT_FOUND)：**
```json
{
  "status": "error",
  "message": "找不到角色"
}
```

### PUT /characters/:id
**Header：**
- `x-user-id`：必須與角色的 `authorId` 相符

**請求主體：** （與 POST 相同）

**回應 200：** （更新後的角色）

**回應 403 (FORBIDDEN)：**
```json
{
  "status": "error",
  "message": "你沒有權限更新此角色"
}
```

### DELETE /characters/:id
**Header：**
- `x-user-id`：必須與角色的 `authorId` 相符

**回應 204：** （無內容）

**回應 403 (FORBIDDEN)：**
```json
{
  "status": "error",
  "message": "你沒有權限刪除此角色"
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
| FORBIDDEN | 403 | 使用者沒有權限（不是作者） |
| UNKNOWN_SERVER_ERROR | 500 | 非預期的伺服器錯誤 |

## 架構說明

**三層設計：**
- **Controller**：HTTP 處理、錯誤對應、驗證中介層
- **Service**：序列化/反序列化（tags/fewShots 陣列 ↔ JSON 字串）、權限檢查
- **Repository**：Prisma CRUD 操作

**授權：**
- 角色擁有權透過 `x-user-id` header 驗證（由 gateway 注入）
- 可見性規則：私密角色需要擁有權，公開角色對所有人可訪問

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
