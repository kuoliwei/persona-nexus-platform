# Microservices & Frontend Repositories

本平台採用微服務架構，各服務維護獨立的 git 倉庫。本檔案列出所有服務的倉庫位置。

## Backend Services

| 服務 | 倉庫 | Port | 技術棧 | 職責 |
|------|------|------|--------|------|
| **auth-service** | https://github.com/kuoliwei/auth-service.git | 3000 | Node.js + Express | 註冊/登入，簽發 JWT |
| **user-service** | https://github.com/kuoliwei/user-service.git | 4000 | Express + Prisma + SQLite | 使用者帳號 CRUD |
| **character-service** | https://github.com/kuoliwei/character-service.git | 5000 | Express + Prisma + SQLite | AI 角色 CRUD |
| **chat-service** | https://github.com/kuoliwei/chat-service.git | 6000 | Express + Prisma + SQLite | 對話訊息存儲、摘要管理 |
| **ai-service** | https://github.com/kuoliwei/ai-service.git | 6001 | Python + FastAPI + LangChain | AI 生成、RAG 記憶 |
| **api-gateway** | https://github.com/kuoliwei/api-gateway.git | 8000 | Express | 唯一對外入口，JWT 驗證、轉發 |

## Frontend Projects

| 前端 | 倉庫 | Port | 職責 |
|------|------|------|------|
| **persona-nexus-auth** | https://github.com/kuoliwei/persona-nexus-auth.git | 5173 | 登入/註冊頁面 |
| **persona-nexus-character** | https://github.com/kuoliwei/persona-nexus-character.git | 5174 | 角色創建/編輯頁面 |
| **persona-nexus-lobby** | https://github.com/kuoliwei/persona-nexus-lobby.git | 5175 | 平台首頁、角色大廳 |
| **persona-nexus-chat** | https://github.com/kuoliwei/persona-nexus-chat.git | 5176 | 聊天室 |

## Root Repository

| 項目 | 倉庫 | 職責 |
|------|------|------|
| **persona-nexus-platform** | https://github.com/kuoliwei/persona-nexus-platform.git | 部署配置、啟動腳本、文檔 |

---

## 開發與部署

### 本地開發

```bash
# 1. Clone 根倉庫
git clone https://github.com/kuoliwei/persona-nexus-platform.git
cd persona-nexus-platform

# 2. 各微服務已複製到子資料夾（各自有 .git）
# 3. 進入各服務開發
cd auth-service
git status
```

### 提交與推送

**重要**：各微服務獨立維護，需分別 push 到各自的遠端倉庫：

```bash
# 修改 auth-service
cd auth-service
git add .
git commit -m "..."
git push origin main

# 修改 character-service
cd ../character-service
git add .
git commit -m "..."
git push origin main

# 修改根目錄部署配置
cd ..
git add deploy/ openspec/ ARCHITECTURE.md ...
git commit -m "..."
git push origin master
```

### 一鍵啟動

根目錄提供啟動腳本，自動起動所有服務：

```bash
# Windows
start-all-services.bat

# Linux/Mac
bash start-all-services.sh  # (需自行建立)
```

---

## 倉庫狀態

| 倉庫 | 分支 | 狀態 |
|------|------|------|
| persona-nexus-platform | `master` | ✓ 已初始化 |
| auth-service | `main` | ✓ 已同步 |
| user-service | `main` | ✓ 已同步 |
| character-service | `main` | ✓ 已同步 |
| chat-service | `main` | ✓ 已同步 |
| ai-service | `main` | ✓ 已同步 |
| api-gateway | `main` | ✓ 已同步 |
| persona-nexus-auth | `main` | ✓ 已同步 |
| persona-nexus-character | `main` | ✓ 已同步 |
| persona-nexus-lobby | `main` | ✓ 已同步 |
| persona-nexus-chat | `main` | ✓ 已同步 |

---

## 注意事項

⚠️ **不要在根目錄 push 微服務的修改**
- 根目錄 git 只管根目錄的文件（`deploy/`、文檔等）
- 各微服務修改必須進入各自資料夾後提交和推送

⚠️ **同源部署依賴**
- Caddy（反向代理）
- Ollama（LLM）
- Qdrant（向量資料庫）

參見 [ARCHITECTURE.md](ARCHITECTURE.md) 與 [deploy/README.md](deploy/README.md)。
