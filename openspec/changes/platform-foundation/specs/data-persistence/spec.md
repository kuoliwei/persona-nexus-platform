## 新增需求

### 需求：SQLite 資料庫
系統應使用 SQLite 作為所有後端服務的主要資料儲存。每個服務在本地管理自己的 SQLite 資料庫檔案。

#### 情境：服務特定的資料庫
- **當** auth-service 啟動
- **則** 它讀取 `DATABASE_URL=file:./prisma/dev.db` 並連接至本地 SQLite 檔案
- **並且** user-service、character-service、chat-service 各有自己的分別 SQLite 檔案

#### 情境：資料庫檔案位置
- **當** 服務初始化
- **則** SQLite 資料庫檔案位於 `<service-root>/prisma/dev.db`

### 需求：Prisma ORM
所有後端服務應使用 Prisma 7 作為物件關聯對應（ORM）層。Prisma 抽象化資料庫操作並提供型別安全的查詢。

#### 情境：Prisma 客戶端初始化
- **當** 服務啟動
- **則** 它透過 `@prisma/client` 使用 libSQL 適配器初始化 `PrismaClient`
- **並且** 維護單例實例以進行連線池管理

#### 情境：libSQL 適配器
- **當** Prisma 客戶端連接
- **則** 它使用 `@prisma/adapter-libsql` 橋接至 SQLite，透過 `@libsql/client`

### 需求：資料庫結構描述定義
每個服務在 `prisma/schema.prisma` 中定義其資料模型。此檔案是該服務資料庫結構的單一事實來源。

#### 情境：結構描述定義
- **當** 開發者編輯 `prisma/schema.prisma`
- **則** 他們定義表、欄位、關係和約束
- **例如：**
  ```prisma
  model User {
    id        String   @id
    email     String   @unique
    password  String
    createdAt DateTime @default(now())
    updatedAt DateTime @updatedAt
  }
  ```

### 需求：遷移
資料庫結構變更必須透過 Prisma 遷移追蹤。遷移確保結構演變可重現和可審計。

#### 情境：建立遷移
- **當** 開發者改變 `schema.prisma`
- **則** 他們執行 `npx prisma migrate dev --name <migration_name>`
- **並且** Prisma 在 `prisma/migrations/<timestamp>_<name>/migration.sql` 生成遷移檔案

#### 情境：遷移應用
- **當** 服務在新環境中啟動
- **則** 它執行 `npx prisma migrate deploy` 以應用所有待處理遷移
- **並且** 資料庫結構與程式碼同步

#### 情境：遷移回滾
- **當** 遷移包含錯誤
- **則** 開發者可以透過以下方式回滾：
  1. 刪除遷移檔案
  2. 執行 `npx prisma migrate resolve --rolled-back <name>`
  3. 建立新的更正遷移

### 需求：型別生成
Prisma 自動從結構描述生成 TypeScript 型別。雖然服務使用 JavaScript，但型別資訊可用於 IDE 支援。

#### 情境：生成的型別
- **當** 結構改變
- **則** `npx prisma generate` 在 `node_modules/@prisma/client` 中建立型別定義
- **並且** IDE 可以為 Prisma 查詢提供自動完成

### 需求：外鍵關係
資料庫表可定義外鍵約束以維護參照完整性。級聯刪除規則在結構中指定。

#### 情境：Conversation → Message 級聯
- **當** Conversation 被刪除
- **則** 所有相關的 Message 記錄自動被刪除（CASCADE DELETE）

#### 情境：User → Character 關係
- **當** Character 參照 User（authorId）
- **則** 資料庫強制外鍵約束；無效的 authorId 被拒絕

### 需求：唯一約束
唯一約束防止在關鍵欄位中出現重複值。

#### 情境：電子郵件唯一性
- **當** User 表有 `email` 欄位搭配 `@unique`
- **則** 嘗試插入重複電子郵件回傳資料庫錯誤
- **並且** 服務捕捉錯誤並回傳 `EMAIL_ALREADY_EXISTS`

### 需求：索引
在頻繁查詢的欄位上建立索引以最佳化讀取效能。

#### 情境：查詢最佳化
- **當** Conversation 表在 `userId` 上有索引
- **則** 查詢 `WHERE userId = ?` 很快（O(log n) 而不是 O(n)）

**常見索引：**
- `User.email`（用於登入查詢）
- `Conversation.userId`（用於檢索使用者的對話）
- `Message.conversationId`（用於檢索對話訊息）
- `Character.authorId`（用於檢索使用者的角色）

### 需求：JSON 儲存規約
某些欄位（如 Character 中的 `tags` 和 `fewShots`）儲存為資料庫中的 JSON 字串。Service 層處理序列化/反序列化。

#### 情境：JSON 欄位儲存
- **當** Character 的 `tags` 欄位定義為結構描述中的 `String`
- **則** service 層在插入前將其儲存為 `JSON.stringify(['tag1', 'tag2'])`
- **並且** service 層在檢索後呼叫 `JSON.parse()` 轉換回陣列

#### 情境：資料庫角度
- **當** 使用 `sqlite3` CLI 直接檢查 SQLite
- **則** `tags` 欄位包含字串 `'["tag1","tag2"]'`
- **不是** 原生 JSON 類型（舊版 SQLite 限制）

### 需求：交易支援
交易確保多步驟操作的原子性。要麼所有步驟成功，要麼全部回滾。

#### 情境：原子使用者建立
- **當** auth-service 呼叫 user-service 建立使用者
- **則** user-service 應將建立包裝在交易中（雖然目前實現沒有）
- **並且** 如果密碼雜湊在使用者插入後失敗，交易回滾

### 需求：連接池管理
Prisma 維持至 SQLite 的連接池以實現高效的資源使用。

#### 情境：連接重用
- **當** 多個請求同時到達
- **則** Prisma 從池中重用連接，而不是建立新的

### 需求：開發 vs 生產資料庫
在開發中，SQLite 檔案已提交到 `.gitignore`。在生產中，使用分別的資料庫。

#### 情境：開發資料庫
- **當** 開發者在本機執行服務
- **則** `.env` 包含 `DATABASE_URL=file:./prisma/dev.db`
- **並且** SQLite 檔案在本地建立，資料在重啟間持久化

#### 情境：.gitignore 設定
- **當** `.gitignore` 包含 `prisma/dev.db`
- **則** 開發資料庫不被提交至版本控制

## 按服務的資料模型

### auth-service
**沒有資料庫** — 依賴 user-service 進行使用者儲存。

### user-service
```
User
├── id (String, PK)：usr_<timestamp>
├── email (String, unique)
├── password (String, bcrypt 雜湊)
├── createdAt (DateTime)
└── updatedAt (DateTime)
```

**索引：** email（唯一）

### character-service
```
Character
├── id (String, PK)：char_<timestamp>
├── authorId (String, FK → User.id)
├── name (String)
├── background (String)
├── opening (String)
├── introduction (String)
├── gender (String, nullable)
├── tags (String, JSON 陣列)
├── fewShots (String, JSON 陣列)
├── visibility (String, enum：private|public)
├── createdAt (DateTime)
└── updatedAt (DateTime)
```

**索引：** authorId、visibility

**遷移：**
- `init` — 初始結構描述
- `make_introduction_required` — 將 `introduction` 從可為空改為必填

### chat-service
```
Conversation
├── id (String, PK, CUID)
├── userId (String, FK → User.id)
├── characterId (String, FK → Character.id)
├── title (String, nullable)
├── createdAt (DateTime)
└── updatedAt (DateTime)

Message
├── id (String, PK, CUID)
├── conversationId (String, FK → Conversation.id, CASCADE)
├── role (String, enum：user|assistant)
├── text (String)
├── createdAt (DateTime)
└── updatedAt (DateTime)
```

**索引：**
- Conversation：userId、characterId、(userId, characterId)
- Message：conversationId、createdAt、(conversationId, createdAt)

**遷移：**
- `init` — 初始 Conversation 和 Message 表

## 環境變數

每個服務使用：
- `DATABASE_URL` — SQLite 連接字串（例如 `file:./prisma/dev.db`）
- `PORT` — 服務監聽的連接埠

## Prisma 組態

**檔案：** `prisma/schema.prisma`

```prisma
datasource db {
  provider = "sqlite"
  url      = env("DATABASE_URL")
}

generator client {
  provider = "prisma-client-js"
  // Prisma 7 不再使用 binaryTargets
}

generator adapter {
  provider = "prisma-adapter-libsql"
}
```

**檔案：** `prisma/prisma.config.ts`（用於 libSQL 適配器）

```typescript
const config = {
  driver: 'better-sqlite3',
  url: process.env.DATABASE_URL,
};
export default config;
```

## 依賴

所有資料持久化服務需要：
- `@prisma/client` ^7 — ORM 客戶端
- `@prisma/adapter-libsql` — SQLite 適配器
- `@libsql/client` — SQLite 驅動程式

## 已知限制

- SQLite 是單檔案、單進程；不適合高並發生產環境
- 沒有內建分片或分割
- 沒有自動化備份
- 外鍵約束可能有效能開銷
- JSON 欄位儲存為字串（SQLite 沒有原生 JSON 類型支援）
- 沒有全文搜尋能力
- 遷移回滾不保證（取決於遷移指令碼的正確性）

## 遷移工作流

1. **修改結構描述：**
   ```bash
   # 編輯 prisma/schema.prisma
   ```

2. **建立遷移：**
   ```bash
   npx prisma migrate dev --name <descriptive_name>
   ```

3. **提交遷移：**
   ```bash
   git add prisma/migrations/
   ```

4. **在其他環境中應用：**
   ```bash
   npx prisma migrate deploy
   ```

## 監控 & 維護

- 定期檢視 `prisma/migrations/` 以確保命名清晰
- 在推送至主分支前在本機測試遷移
- 保持 `schema.prisma` 和遷移同步
- 開發期間使用 `npx prisma studio` 進行資料庫檢查
