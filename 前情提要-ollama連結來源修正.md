# 前情提要：ai-service 的 Ollama 連結來源修正（代辦 H）

> **給接手的新聊天室**：這份文件是你需要知道的全部背景。
> 規格已寫好且驗證通過（`openspec validate --all` 6/6），**你的工作是照 tasks 執行，
> 不是重新設計**。讀完本文件後，直接開
> `ai-service/openspec/changes/config-driven-ollama-host/tasks.md` 開始做。

---

## 一句話任務

在 `ai-service`（Python／FastAPI）執行一個已寫好規格的 openspec change：

| change id | 代辦 | 一句話 |
|---|---|---|
| `config-driven-ollama-host` | H | 三個 Ollama 呼叫點繞過 `config.ollama.url`，改用共用 client 收斂回來 |

**範圍很小**：1 個新檔 + 3 個呼叫點。但屬可觀察行為變更，仍須照流程走。

---

## 這件事怎麼來的

不是稽核發現的，是**執行代辦 D（`typed-qdrant-errors`）的手動測試時撞到的**。

當時要驗證「Ollama 不可用時該回 503」，於是把 `config.json` 的 `ollama.url` 指向
不存在的埠（19999）後重啟服務——結果 `POST /api/v1/chat/summary` **照樣回 200**。

原因：`chat_service` 用的是 `ollama` 套件的**模組層級預設 client**
（`ollama.chat(...)`），該 client 的位址來自 `OLLAMA_HOST` 環境變數
（預設 `http://localhost:11434`），**跟 config.json 無關**。
後來改設 `OLLAMA_HOST` 環境變數才測到真正的連線失敗路徑。

---

## 問題本體

### 使用者已明示的原則

> **`config.json` 的 `ollama.url` 是請求 Ollama 推論的唯一合法來源。**

`config.py:19` 用 `_require("ollama.url")` **強制**此鍵存在（缺鍵服務直接拋 `ValueError`
起不來），即為此原則的既有表達。**所以這是實作缺陷，不是設定機制的分歧**——
不要把它當成「要選 config 還是選環境變數」的開放問題來重新討論。

### 四個呼叫點，只有一個守規矩

| 呼叫點 | 客戶端 | 位址來源 |
|---|---|---|
| `src/rag/embedder.py:16` embedding | `requests` | ✅ `config.OLLAMA_URL` |
| `app.py:69` 啟動時模型預載 | `ollama.generate()` 預設 client | ❌ `OLLAMA_HOST` |
| `src/services/chat_service.py:164` 生成回應 | `ollama.chat()` 預設 client | ❌ 同上 |
| `src/services/chat_service.py:223` 生成摘要 | `ollama.chat()` 預設 client | ❌ 同上 |

### 為什麼這會傷到人：監控會說謊

`config.OLLAMA_URL` 有**四處被當成權威值對外顯示**，其中兩處是 API 回應：

- `app.py:111` → `GET /health` 的 `ollama_url` 欄位
- `src/services/rag_service.py:410` → `GET /api/v1/rag/status` 的 `config.ollama_url`
- `main.py:15`、`scripts/init_rag.py:31` → 啟動與診斷輸出

把 `ollama.url` 改指向另一台機器後，`/health` 會回報**新位址**、實際生成卻仍連 localhost。
排查「為什麼換了 Ollama 主機沒生效」時，這兩個端點會把人**引導到錯誤的方向**。

---

## 修法（已定稿，tasks 2.A 有完整程式碼）

新增 `src/llm_client.py`，比照 `src/rag/embedder.py` 的單例慣例：

```python
import ollama
from config import config

ollama_client = ollama.Client(host=config.OLLAMA_URL)
```

三個呼叫點改用 `ollama_client.chat(...)` / `.generate(...)`。

### 已查證的事實（實測 `ollama` 0.6.2，不是推論）

| 項目 | 結果 |
|---|---|
| `ollama.Client` 簽章 | `(self, host: Optional[str] = None, **kwargs)` |
| `Client(host='http://localhost:19999')` | 確實連往該位址（非套件預設） |
| 連線失敗的例外型別 | **Python 內建 `ConnectionError`**——與 `ollama.chat()` 相同 |
| 預設 timeout | `Timeout(timeout=None)`（**永不逾時**） |

**最重要的一條**：因為 `Client` 連線失敗拋的例外型別與原本完全相同，
代辦 D 在 `chat_service` 加的
`except ConnectionError → OllamaUnavailableError` 包裝**一行都不用改**，
503 行為自動延續。

---

## ⚠️ 最容易做錯的兩件事

### 1. 不要順手接 `config.OLLAMA_TIMEOUT`

看起來 `OLLAMA_TIMEOUT`（300 秒）也該一起接上，**但本輪明確不做**：

- `ollama` 預設是**永不逾時**（已實測）
- 改成 `timeout=300` 會讓**超過 5 分鐘的生成被中斷**
- 本機跑的是 `gemma-26b`，長回應超過 5 分鐘並非不可能
- `OLLAMA_TIMEOUT` 目前只有 embedding 在用，那條路很快，沒有這個風險

在同一輪偷渡這個，等於在修設定問題的同時引入一個可能中斷生成的變更，
故障歸因會變得困難。要不要為生成設逾時、設多少，**另案評估**。

### 2. 不要理會 Docker

`deploy/` 底下有 docker-compose 等容器化內容，其中
`docker-compose.yml:125-129` 還為 ai-service 預留了 `PORT`／`OLLAMA_HOST`／`QDRANT_URL`
環境變數（大多是註解，且對 ai-service 一律不生效）。

**這些不是本平台要求的工作項目。** 使用者僅提過「未來可能部署 Docker」，
**從未要求實作**——那是某一次 AI 未經報備自行做的。

因此：**不要把 docker-compose 的內容當成設計依據**，不要為了「配合容器化」
去改設定機制，也不要順手補 Dockerfile。本輪只處理本機執行時的設定來源一致性。

---

## 已寫好的文件在哪

```
ai-service/openspec/changes/config-driven-ollama-host/
├── proposal.md                    為什麼做、改什麼、影響範圍、刻意不做的事
├── specs/ai-generation/spec.md    ADDED（Ollama 位址單一來源）/ MODIFIED（健康檢查、狀態查詢）
└── tasks.md                       6 節；第 1 節前置查證已完成並記錄結果
```

`openspec validate --all` 目前 **6/6 通過**。改動 spec 後務必重跑。

**tasks 1.1 已完成**：全平台查證無任何生效中的設定依賴 `OLLAMA_HOST`，前提成立，
結果記在 tasks 1.A。你不必重跑，但可以複查。

---

## ⚠️ 必讀：這個服務的三個陷阱

### 1. 用對 Python

- **用**：`C:\Users\MSI3090\miniconda3\envs\ai-service\python.exe`
  （conda env `ai-service`，Python 3.11.15）
- **不要用** `C:\Python314\python.exe`（`python` 預設指向它）——那個環境**只有 pip**，
  無 `qdrant_client`／`fastapi`／`ollama`，任何 import 都會 `ModuleNotFoundError`。
  **那是環境問題不是程式問題**，先前的除錯曾因此誤判過。
- `conda` 不在 PATH 上，直接用完整路徑呼叫即可，不需要 activate。

### 2. 完全沒有測試框架

`ai-service` **沒有任何 `test_*.py`**，沒有 pytest／unittest。
驗證只能靠 `test.http`（手動 REST Client）與實際啟動服務打 API。
**不要以「語法通過」代替「行為正確」。**

本輪的核心驗證（tasks 4.2）是：把 `ollama.url` 改成不存在的埠後，
聊天端點**應該回 503**——**變更前這個測試會回 200**，那正是要修的行為。

### 3. 改 config.json 測試後務必還原

`src/config/config.json` **不進版控**（`.gitignore` 排除），且它是你本機唯一那份。
測試需要反覆改 `ollama.url`，**改之前先備份、測完用 SHA256 比對確認還原**。

另外：用 PowerShell 的 `Set-Content -Encoding UTF8` 寫這個檔會**帶 BOM**，
`config_loader` 的 `json.load` 會直接拋
`Unexpected UTF-8 BOM`，服務起不來。改用 Python 寫檔（`io.open(..., encoding='utf-8')`）
或 `-Encoding utf8NoBOM`。這在上一輪實際踩過。

---

## 環境與啟動

- **Qdrant 與 Ollama 需先啟動**。平台根目錄有 `start-all-services.bat`
  （**須先開 Docker Desktop**，Qdrant 跑在容器裡）。
  只做 ai-service 的話，最少需要 Qdrant（6333）與 Ollama（11434）。
- ai-service 埠為 `config.json` 的 `server.port`（目前 **6001**）。
- **`scripts/init_rag.py`** 是診斷腳本，可先跑一次確認 Qdrant 連線與現有 collections。
- **ai-service 是獨立 git repo**（非 monorepo 的一部分）。
  在平台根目錄 `git diff` **看不到** ai-service 的改動，要用 `git -C ai-service diff`。
  這點在先前的除錯中造成過誤判。
- ⚠️ **Qdrant 裡有使用者的真實資料**（characters 114／fewshots 46／summaries 12 筆），
  掛在具名 volume `qdrant_storage`。**不要 `docker rm qdrant`、不要刪 collection。**
  需要「空 Qdrant」情境時，另起一個容器（例如 `-p 6399:6333` 不掛 volume）測，
  上一輪就是這樣做的。

---

## 工作約定（沿用先前建立的，請延續）

1. **不可以靠推測與猜測，一定要找到證據才能寫**。查不到證據的標記「未證實」並寫明還缺什麼，
   不要升格成結論。（本輪的 `ollama.Client` 行為已全部實測，記在 tasks 0.A。）
2. **修 bug 不可以違背設計原則與規格**。四份設計文件在平台根目錄：
   `後端系統設計原則.md`、`微服務架構準則.md`、`微服務架構實作spec.md`、
   `前端系統設計原則.md`（另有 `網頁架構設計原則.md`，前端專用）。
3. **可觀察的行為改動要先反映在 spec 再改碼**。本 change 的 spec 已寫好；
   若執行中發現需要偏離規格，**先改 spec 並告知使用者**，不要直接改碼。
4. **驗證要用「跑起來」而不是「讀過了」**。
5. **關鍵節點停下來跟使用者核對**，不擅自擴大範圍。
6. **不要順便夾帶其他重構或優化**，只做 tasks 列出的項目。
   proposal 明列了「不在本輪範圍」的項目（尤其是 timeout），請尊重那個邊界。

---

## 完成後

1. tasks 第 5 節有文件同步項目（`CLAUDE.md`、`openspec/config.yaml`、`test.http`）。
   ⚠️ `test.http` 現有的 **D-2 情境註解會過時**——它目前寫著
   「chat_service 不讀 config.json 的 ollama.url」，本輪之後不再成立，記得改掉。
2. 第 6 節：依專案慣例**同步 delta 回主 spec**。
   本專案**不使用 `openspec archive`**（無 `changes/archive/` 目錄，
   已完成的 `simplify-ai-service`／`encapsulate-vector-store`／`typed-qdrant-errors`
   都保留在 `changes/`）。
3. 平台根目錄 `前端網頁debug_task_checklist.md` 的**代辦 H** 勾選並註記完成情形。
4. **commit 注意**：ai-service 這個 repo 目前有**上一輪（代辦 E／D）尚未 commit 的改動**
   （`src/exceptions.py`、`src/http_errors.py` 等新檔與多個修改檔）。
   commit 時只挑本輪檔案，**不要整包 `git add .`**。

---

## 前一輪的成果（背景知識，不必重做）

2026-07-28 已完成兩個 change，程式碼都已改好並實測通過，但**尚未 commit**：

- **`encapsulate-vector-store`（代辦 E）**：`rag_repository` 7 處直接用
  `vector_store.client` 的地方全部收斂，`vector_store` 新增 `delete_by_filter()`／
  `scroll_points()`（參數為純字典），`rag_repository` 不再 import `qdrant_client`。
- **`typed-qdrant-errors`（代辦 D）**：503／500 的判斷依據由「錯誤訊息關鍵字比對」
  改為「例外型別」。新增 `src/exceptions.py`（`QdrantUnavailableError`／
  `OllamaUnavailableError`）與 `src/http_errors.py`（共用 `raise_for_error()`）。
  聊天端點也接上了（原本一律 500）。

**與本輪最相關的一點**：`chat_service.py` 的兩處 `ollama.chat()` 外面已經包了
`try/except ConnectionError → OllamaUnavailableError`。你改成 `ollama_client.chat()`
時，**那層包裝要原封不動保留**（已查證型別相同）。
