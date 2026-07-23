# Persona Nexus 平台架構總覽

> 本文件位於工作資料夾根目錄，供**新接手的對話 / 開發者**快速了解整個平台的用途與各微服務的職責。
> 詳細的單一服務說明，請看各專案子資料夾內的 `CLAUDE.md`。

---

## 這是什麼專案

**Persona Nexus** 是一個**類 Character.ai 的 AI 角色扮演／模擬對話平台**。使用者可以註冊登入、建立自己的 AI 角色，並與角色進行具「記憶連續性」的即時對話。

專案性質為**學習用途**，採**微服務架構**，由多個獨立的前端與後端小專案組成，各自是**獨立的 git 倉庫**（非 monorepo），只是整合複製到同一個工作資料夾 `C:\Users\MSI3090\persona-nexus-platform` 下方便一起開發。

### 協作偏好

使用者**沒有建構此類系統的經驗，偏好「教學引導、讓他自己動手」**的協作方式——解釋概念、引導思考、給方向與範例片段，但**不要直接貼完整程式碼讓他複製貼上**。

---

## 核心架構原則

```
                          瀏覽器（各前端 Vite dev server）
                                     │
          靜態頁面各自提供            │   所有 API 請求一律經過 Gateway
                                     ▼
                          ┌────────────────────┐
                          │   api-gateway :8000 │  ← 唯一對外入口
                          │  驗證 JWT，注入      │
                          │  x-user-id header    │
                          └─────────┬──────────┘
                                    │ proxy（各後端不對外暴露）
        ┌───────────────┬──────────┼───────────┬──────────────┐
        ▼               ▼          ▼            ▼              ▼
   auth-service   user-service  character-  chat-service   ai-service
     :3000          :4000       service      :6000          :6001
   (註冊/登入        (使用者資料   :5000       (對話訊息      (LLM 生成 +
    發 JWT)          CRUD)      (角色 CRUD)   儲存)          RAG 記憶)
                                                              │
                                                    ┌─────────┴─────────┐
                                                    ▼                   ▼
                                              Ollama :11434       Qdrant :6333
                                              (本地 LLM)          (向量資料庫)
```

**兩條關鍵鐵則：**

1. **前端從不直接呼叫後端服務，一律打 api-gateway。**
2. **JWT 驗證只在 gateway 做一次**：gateway 驗證 `Authorization: Bearer <JWT>` 成功後，把使用者 ID 放進 `x-user-id` header 再轉發。後端服務直接信任這個 header，本身不驗 JWT（`auth-service` 除外，它負責簽發）。這是**刻意的架構分工**，前提是後端服務不會被外部直接打到。

> ⚠️ 唯一例外：`auth-service` 的 `/auth/*` 路由不需要 JWT（本來就是要發 JWT 的），其餘皆需。

---

## 服務清單

### 後端服務

| 服務 | Port | 技術棧 | 職責 |
|------|------|--------|------|
| **api-gateway** | 8000 | Express | 平台唯一對外入口。CORS、JWT 驗證、注入 `x-user-id`、`pathRewrite` 後 proxy 到各服務。**不含業務邏輯**。 |
| **auth-service** | 3000 | Node.js + Express | 只負責註冊 / 登入，簽發 JWT。`/auth/*` 不經過 gateway 的 JWT 驗證。 |
| **user-service** | 4000 | Express 5 + Prisma 7 (libSQL) + SQLite | 使用者帳號 CRUD（建立/查詢/刪除）。典型三層架構（controller / service / repository）。 |
| **character-service** | 5000 | Express + Prisma + SQLite | AI 角色的 CRUD。只認 gateway 注入的 `x-user-id`，不含 `jsonwebtoken` 依賴。 |
| **chat-service** | 6000 | Express 5 + Prisma + SQLite | 儲存與管理使用者和角色的對話記錄（Conversation + Message 兩層）。負責短期記憶窗口管理與**摘要觸發**，並轉呼叫 ai-service 生成回覆。 |
| **ai-service** | 6001 | Python + FastAPI + LangChain | **AI 大腦**。呼叫本地 LLM（Ollama）生成角色回覆，並用 RAG（Qdrant 向量庫）檢索角色背景、few-shot 範例、歷史摘要，組裝 system prompt。 |

**ai-service 的外部依賴：**
- **Ollama**（`:11434`）— 本地 LLM 推論（目前模型 `gemma-26b:latest`）與 embedding（`nomic-embed-text`）。
- **Qdrant**（`:6333`）— 向量資料庫，儲存角色背景 / few-shot / 對話摘要的向量。

**模型預載（app.py 的 startup hook）：**
ai-service 啟動時會在**背景執行緒**預載 Ollama 模型（不阻塞啟動，載入期間其他端點照常可用），
避免使用者第一次聊天要苦等模型載入。預載用「空 prompt 的 generate」——這是 Ollama 官方的純載入慣例，
不會實際生成內容。同時帶入 config 的 `ollama.keepAlive`（目前 `30m`）延長模型在記憶體的常駐時間，
避免閒置 5 分鐘（Ollama 預設）就被卸載。`chat_service` 每次對話也會帶同一個 `keepAlive`，持續續期。

### 前端（皆為 Vite + Vanilla JS，無框架，port 已用 `strictPort` 固定）

| 前端 | Port | 職責 |
|------|------|------|
| **persona-nexus-auth** | 5173 | 登入 / 註冊頁。未登入的使用者會被導向這裡。 |
| **persona-nexus-character** | 5174 | 角色創建 / 編輯頁（`creator-create.html` / `creator-edit.html`）。 |
| **persona-nexus-lobby** | 5175 | **平台首頁**。側邊欄（Logo、創建角色）+ 主內容區（角色大廳）。登入守門。 |
| **persona-nexus-chat** | 5176 | 聊天室。使用者在此與 AI 角色對話，輪詢 ai-service 的回覆。 |

---

## 典型使用者流程

```
1. 登入        persona-nexus-auth (5173)  → auth-service 發 JWT
                     ↓
2. 進入首頁    persona-nexus-lobby (5175) → 角色大廳
                     ↓
3. 建立角色    persona-nexus-character (5174) → character-service 存角色
                     ↓
4. 開始對話    persona-nexus-chat (5176)
                     ↓
               chat-service (6000) 存訊息、管理短期記憶、必要時觸發摘要
                     ↓
               ai-service (6001) 用 RAG 檢索記憶 + Ollama 生成角色回覆
                     ↓
               回覆存回 chat-service，前端輪詢取得並顯示
```

---

## 記憶與摘要機制（平台的核心特色）

為了讓 AI 角色維持**劇情連續性**，記憶分為兩層：

1. **短期記憶**：全部「未摘要」的對話訊息，完整送給模型（不截斷）。
2. **長期記憶（RAG）**：當未摘要訊息累積到門檻，`chat-service` 觸發摘要，把較舊的訊息壓縮成摘要存入 Qdrant，短期只保留最新數條原文。

ai-service 組 prompt 時會同時提供：
- **與當前對話最相關的歷史摘要**（語義檢索）— 相關往事參考。
- **最近一次歷史摘要**（時間最新的單筆，非語義檢索）— 確保 AI 永遠記得「上一段劇情剛發生什麼」。

> 相關設定分散在兩處：`chat-service/src/config/config.json`（摘要門檻、timeout）與 `ai-service/src/config/config.json`（LLM 模型、RAG 檢索數量）。

---

## 啟動方式

根目錄提供批次啟動腳本：

| 腳本 | 用途 |
|------|------|
| `start-backend-services.bat` | 啟動 Ollama + Qdrant + auth / user / character / chat / ai 五個後端 |
| `start-frontend-services.bat` | 啟動四個前端 Vite server |
| `start-all-services.bat` | 一次全部啟動 |

`ai-service` 是 Python，需要 conda 環境（環境名 `ai-service`）。由於 conda 不在 PATH 上，腳本以完整路徑呼叫
`C:\Users\MSI3090\miniconda3\Scripts\activate.bat` 來啟用；另設 `PYTHONIOENCODING=utf-8`，
避免 log 中的 emoji 在 Windows cp950 環境下觸發 `UnicodeEncodeError` 導致服務啟動失敗。

Ollama 與 Qdrant 會先偵測再啟動（已在跑就跳過），因此重複執行腳本是安全的。
Qdrant 以 Docker 啟動並掛載既有的 `qdrant_storage` volume，RAG 資料得以保留。

> 手動啟動 ai-service：`conda activate ai-service && cd ai-service && python main.py`

---

## Git 說明

各子資料夾是**獨立 git 倉庫**（remote 皆為 `github.com/kuoliwei/<服務名>`），**不是** monorepo。
推送時需分別進入各子資料夾操作。本根目錄下的腳本與本文件本身**不在任何倉庫追蹤範圍內**（除非另行初始化）。
