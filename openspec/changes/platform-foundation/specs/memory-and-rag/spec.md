## 新增需求

### 需求：短期記憶窗口
系統應維護「短期記憶」，包含所有未摘要的對話訊息。當 ai-service 生成角色回覆時，它接收完整的短期訊息歷史（不截斷）。

#### 情境：短期窗口檢索
- **當** ai-service 查詢 chat-service 以取得對話內容
- **則** 系統回傳對話中尚未摘要的所有訊息

#### 情境：無邊界的對話
- **當** 對話有少於摘要閾值（例如 50）的未摘要訊息
- **則** 所有訊息被視為「短期」，包含在 LLM 提示中

### 需求：摘要觸發
系統應在未摘要訊息數量超過設定的閾值時自動觸發摘要。摘要將較舊的訊息壓縮成摘要文本以供 RAG 儲存。

#### 情境：根據訊息計數觸發摘要
- **當** 未摘要訊息計數達到閾值（預設：50 條訊息）
- **則** 系統呼叫 ai-service 以摘要超過閾值的訊息
- **並且** 將摘要儲存在 Qdrant 向量資料庫
- **並且** 標記原始訊息為「已摘要」

#### 情境：可設定的閾值
- **當** chat-service 啟動
- **則** 它從設定檔讀取摘要閾值（預設：50 條訊息）

### 需求：透過 RAG 的長期記憶
系統應在向量資料庫（Qdrant）中儲存對話摘要，用於檢索增強生成（RAG）。生成回覆時，ai-service 檢索相關的歷史摘要以提供上下文。

#### 情境：在 Qdrant 中儲存摘要
- **當** 訊息被摘要
- **則** 摘要文本被嵌入為向量並儲存在 Qdrant 中，包含後設資料（conversationId、characterId、時間戳）

#### 情境：生成時的語義檢索
- **當** ai-service 生成角色回覆
- **則** 它查詢 Qdrant 以尋找最相似的歷史摘要（預設：3 條最相關）
- **並且** 將語義匹配和最新摘要包含在 LLM 提示中

#### 情境：包含最新摘要
- **當** ai-service 生成回覆
- **則** 它總是包含最新的摘要（按時間戳），即使不語義相似
- **並且** 這確保角色行為在對話情節間保持連續

### 需求：摘要格式
摘要應是敘述性文本，描述摘要訊息批次中的關鍵事件、決策和角色發展。

#### 情境：摘要生成
- **當** ai-service 摘要訊息（例如訊息 1-50）
- **則** 它生成敘述段落，例如：
  - 「使用者第一次遇見角色 Luna。角色揭露了搜尋失落星星的背景故事。使用者表示對天文學感興趣。角色承諾教使用者有關星座的知識。」

### 需求：訊息後設資料
Chat-service 中的訊息應跟蹤它們是否已被摘要。這決定了哪些訊息仍是短期記憶的一部分。

#### 情境：摘要化標誌
- **當** 訊息包含在摘要中
- **則** 這些訊息被標記為 `summarized: true` 或 `summarizedAt: <timestamp>`
- **並且** 未來的短期查詢排除這些訊息

## 資料模型擴展

### Conversation 表（擴展）
- `lastSummaryAt` (DateTime, nullable)：上次摘要生成的時間戳
- `unsummarizedMessageCount` (Integer, default: 0)：未摘要的訊息計數

### Message 表（擴展）
- `summarized` (Boolean, default: false)：此訊息是否已包含在摘要中
- `summarizedAt` (DateTime, nullable)：訊息被摘要時的時間戳
- `summaryBatch` (String, nullable)：此訊息所屬的摘要 ID 或參考

### Summary 表（在 Qdrant 向量資料庫中）
- `id` (String)：唯一摘要 ID
- `conversationId` (String)：父對話
- `characterId` (String)：對話中的角色
- `summaryText` (String)：訊息的敘述摘要
- `messageRange` (Object)：`{ fromId, toId }` — 此摘要中第一條和最後一條訊息的 ID
- `vector` (Float[])：嵌入向量（由嵌入模型生成）
- `timestamp` (DateTime)：摘要建立時間
- `metadata` (Object)：檢索的額外上下文

**Qdrant 集合結構描述：**
- 集合名稱：`conversation-summaries`
- 向量大小：384（用於 `nomic-embed-text` 模型）
- 距離度量：餘弦相似度

## 組態

### chat-service config
**檔案：** `src/config/config.json`

```json
{
  "summaryThreshold": 50,
  "summaryTimeout": 30000,
  "qdrantURL": "http://localhost:6333",
  "embeddingModel": "nomic-embed-text",
  "topKRetrieval": 3
}
```

### ai-service config
**檔案：** `src/config/config.json`

```json
{
  "qdrantURL": "http://localhost:6333",
  "topKRetrieval": 3,
  "llmModel": "gemma-26b:latest",
  "embeddingModel": "nomic-embed-text"
}
```

## API / 整合點

### chat-service → ai-service（摘要生成）
**POST /summarize**（來自 chat-service 到 ai-service 的內部呼叫）

**請求：**
```json
{
  "conversationId": "conv_abc123xyz",
  "characterId": "char_1720000000000",
  "messages": [
    { "id": "msg_1", "role": "user", "text": "..." },
    { "id": "msg_2", "role": "assistant", "text": "..." },
    ...
  ]
}
```

**回應：**
```json
{
  "summaryText": "使用者和角色討論了...",
  "messageIds": ["msg_1", "msg_2", ...]
}
```

### ai-service → Qdrant（向量儲存）
Ai-service 使用 Qdrant Python 客戶端來：
1. 使用嵌入模型嵌入摘要文本
2. 在 Qdrant 中儲存向量和後設資料
3. 在回覆生成期間查詢相似的摘要

### ai-service LLM 提示構造
生成角色回覆時，ai-service：
1. 從 chat-service 檢索短期訊息
2. 查詢 Qdrant 以尋找前 K 個相關摘要
3. 包含最新摘要（按時間戳）
4. 構造提示：`system_prompt + character_context + few_shots + relevant_summaries + latest_summary + short_term_messages`

## 錯誤場景

### 情境：Qdrant 不可用
- **當** Qdrant 服務已關閉
- **則** ai-service 繼續不使用 RAG（僅使用短期記憶和角色內容）
- **並且** 記錄警告以進行人工干預

### 情境：摘要生成逾時
- **當** 摘要生成耗時超過 `summaryTimeout`（預設：30 秒）
- **則** chat-service 重試或記錄錯誤，不阻塞對話

### 情境：格式不正確的摘要
- **當** ai-service 生成無效摘要（例如空文本）
- **則** 系統跳過儲存該摘要，訊息保持未摘要標記

## 效能考量

- **短期記憶大小**：上限約 50 條訊息才進行摘要（可設定）
- **向量檢索**：前 K=3 摘要每次查詢（可設定）
- **嵌入延遲**：每個摘要約 100-500 毫秒（取決於 Ollama 效能）
- **Qdrant 查詢延遲**：語義搜尋約 10-50 毫秒
- **每個回覆的總開銷**：由於 RAG 增加約 200-1000 毫秒的延遲

## 已知限制

- 沒有手動摘要編輯或更正
- 沒有對話「分支」或替代時間線
- 摘要是無損的（細節被丟棄）
- 沒有角色記憶更新的支援（例如「角色現在知道 X」）
- Qdrant 儲存是記憶體中的（如果服務重啟則不持久化）
- 沒有非常舊摘要的清理策略
