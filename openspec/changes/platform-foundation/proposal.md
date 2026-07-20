## Why

Persona Nexus 是一個學習性質的 AI 角色扮演/戀愛模擬平台，目標是展示如何用微服務架構構建具有「連續對話記憶」的 AI 系統。該平台已完成 80% 的核心功能，現在需要建立完整的規格文檔來保證後續 20% 的開發能維持一致的架構與 API 契約。

## What Changes

平台由 6 個獨立後端微服務 + 4 個前端應用組成，已實現的核心功能包括：
- 使用者認證與授權（JWT 簽發、密碼雜湊、gateway 驗證）
- 使用者帳號管理（CRUD）
- AI 角色創建與管理（CRUD）
- 對話訊息存儲與檢索
- LLM 推論 + RAG 記憶整合（部分）

## Capabilities

### New Capabilities

- `user-authentication`: 使用者登入/登出、JWT 簽發與驗證、密碼雜湊
- `user-account-management`: 使用者帳號 CRUD、個人資料管理
- `character-management`: AI 角色創建/編輯/刪除、角色屬性（背景、few-shots、可見性）
- `conversation-management`: 對話建立、訊息發送/接收、對話歷史查詢
- `memory-and-rag`: 短期訊息窗口、對話摘要、向量檢索（Qdrant）
- `api-gateway`: 統一 API 入口、JWT 驗證、路由轉發、CORS 管理
- `data-persistence`: SQLite 資料庫、Prisma ORM、migration 管理

### Modified Capabilities

（無 — 這是平台基礎層，尚未涉及修改既有功能）

## Impact

**涉及的服務：**
- auth-service (3000) — 認證微服務
- user-service (4000) — 使用者服務
- character-service (5000) — 角色服務
- chat-service (6000) — 對話服務
- ai-service (6001) — AI 推論服務
- api-gateway (8000) — API 網關

**涉及的前端：**
- persona-nexus-auth (5173) — 登入/註冊
- persona-nexus-character (5174) — 角色創建/編輯
- persona-nexus-lobby (5175) — 首頁與角色大廳
- persona-nexus-chat (5176) — 聊天室

**技術棧變化：**
- Node.js 20.19.0+，ESM modules
- Express 5，Prisma 7，SQLite（libSQL adapter）
- JWT，bcrypt，Zod 驗證
- Python FastAPI + LangChain + Qdrant（ai-service 部分）

**API 契約與資料模型已定，涉及：**
- `/api/v1/auth/*` — 認證路由
- `/api/v1/users/*` — 使用者路由
- `/api/v1/characters/*` — 角色路由
- `/api/v1/conversations/*` — 對話路由
- User、Character、Conversation、Message 資料模型

**已知缺口（待補）：**
- persona-nexus-auth 登入成功後未存 localStorage token
- persona-nexus-character 直打 character-service 而不經 gateway
- chat-service ↔ ai-service 實時連接未完成
