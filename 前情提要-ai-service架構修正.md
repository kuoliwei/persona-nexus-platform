# 前情提要：ai-service 兩項架構修正（代辦 D／E）

> **給接手的新聊天室**：這份文件是你需要知道的全部背景。
> 規格已寫好且驗證通過，**你的工作是照 tasks 執行，不是重新設計**。
> 讀完本文件後，直接開 `ai-service/openspec/changes/<change-id>/tasks.md` 開始做。

---

## 一句話任務

在 `ai-service`（Python／FastAPI）執行兩個已寫好規格的 openspec change：

| change id | 代辦 | 一句話 |
|---|---|---|
| `encapsulate-vector-store` | E | `rag_repository` 8 處繞過封裝直接操作 Qdrant，收斂回 `vector_store` 介面 |
| `typed-qdrant-errors` | D | 503／500 的判斷依據由「錯誤訊息字串比對」改為「例外型別」 |

**建議先做 E 再做 D**（理由見下方〈執行順序〉）。

---

## 這兩件事怎麼來的

平台先前完成一輪前端 debug（8 個 bug），之後依四份設計文件做稽核，
產出代辦 A～G 七項。稽核結果與完整證據記錄在平台根目錄
`前端網頁debug_task_checklist.md` 的「## ✅ 稽核結果（2026-07-28）」章節。

七項的處置：

| 代辦 | 內容 | 狀態 |
|---|---|---|
| A、B | 前端 lobby 訊息框架構問題 | ⏳ 未定案（不在你的範圍） |
| C | Bug 7 的鍵盤事件實作取捨 | ✅ 已完成（寫入 lobby spec） |
| **D** | **ai-service 錯誤碼字串判斷** | **📋 規格已寫好，待執行 ← 你的任務** |
| **E** | **ai-service 繞過封裝** | **📋 規格已寫好，待執行 ← 你的任務** |
| F、G | 微服務 spec 文件補充 | ✅ 已完成 |

**共同成因（使用者自述）**：「當初也是想到什麼功能就叫 AI 做什麼功能，
沒有想到統一架構的問題」——這兩項都不是單一疏漏，是按功能逐項開發、
未回頭收斂架構的累積結果。理解這點有助於判斷「該修到哪裡為止」。

---

## 代辦 E：`encapsulate-vector-store`

### 問題

`ai-service` 的分層設計是：

```
rag_repository（資料層）
      ↓ 應該只透過 vector_store 的公開方法
vector_store（Qdrant 封裝層）
      ↓ 內部持有 client
qdrant_client（第三方套件）
```

但 `rag_repository` 有 **8 處直接取用 `vector_store.client`**，繞過封裝直接操作 Qdrant。

**根因不是「有介面卻不走」，而是「介面上沒有這兩個方法」**：

- `delete_points()` 只能依 point id 刪除 → 無法「依條件刪除」
- `search()` 是相似度檢索 → 無法「依條件列舉全部」

### 實際範圍（比稽核記載更大）

稽核寫「三個方法」，實地清點為 **4 個方法、8 個呼叫點**
（多出 `get_conversation_data`）：

| 方法 | 行號 | `.client` 用法 |
|---|---|---|
| `replace_protagonist_background` | 154 | `delete`（**兩個條件**，最易出錯） |
| `get_latest_summary` | 433 | `scroll` |
| `get_conversation_data` | 486、494 | `scroll` ×2 |
| `delete_conversation_data` | 540、546、552 | `delete` ×3 |

### 三項後果

1. **`ensure_collection()` 被迫散落各處**：Bug 4 修復的「存取前自動補建 collection」
   只作用於 `vector_store` 自有方法，這 4 個繞過的方法罩不到，
   只好各自補一次 ensure ——是補丁不是設計。
2. **Qdrant 型別外洩**：`rag_repository` 必須 import
   `Filter`／`FieldCondition`／`MatchValue`。
3. **未來的橫切保護會漏掉這 8 處**（例如代辦 D 要加的例外包裝）。

### 修法

在 `vector_store` 補兩個方法，參數用**純字典**（關鍵——若仍傳 `Filter` 物件只是搬家）：

- `delete_by_filter(collection_name, conditions)`
- `scroll_points(collection_name, conditions, limit)`

然後 8 個呼叫點改走新介面、移除 qdrant_client 匯入、移除 4 處補丁式 ensure。

---

## 代辦 D：`typed-qdrant-errors`

### 問題

`rag_controller.py:12-20` 用**錯誤訊息的字串內容**決定回 503 還是 500：

```python
_CONNECTION_ERROR_KEYWORDS = ("qdrant", "connect", "refused")

def _raise_for_error(error_msg: str) -> None:
    if any(kw in error_msg.lower() for kw in _CONNECTION_ERROR_KEYWORDS):
        raise HTTPException(status_code=503, detail=error_msg)
    raise HTTPException(status_code=500, detail=error_msg)
```

三個風險：改文案就改了 API 契約、訊息湊巧含 `connect` 會誤判、
以及**反向依賴已經形成**——`vector_store.py:88-95` 的 docstring 自承
「訊息刻意含 'Qdrant' 字樣，讓 `_raise_for_error()` 的關鍵字查表判為連線類錯誤回 503」。

### 修法

新增 `src/exceptions.py` 定義 `QdrantUnavailableError`，
`vector_store` 改拋此型別，controller 改用 `isinstance` 判斷。

### ⚠️ 最容易出錯的地方

`qdrant_client` 的連線例外由**套件內部拋出**，不會自動變成我們的型別。
`upsert_documents()`／`search()`／`delete_points()` 必須**包裝**：

```python
except <qdrant 連線類例外> as exc:
    raise QdrantUnavailableError(str(exc)) from exc
```

**漏做會讓原本回 503 的情境退化成 500。**
且 tasks 3.4 明訂：`qdrant_client` 的實際例外型別**必須查證，不可憑猜測**。

---

## 執行順序：先 E 後 D

E 把 8 個直接呼叫點收回 `vector_store` 之後，D 只需在 `vector_store` 一處包裝例外
即可涵蓋全部路徑。若先做 D，那 8 個點得另外處理一次。

---

## 已寫好的文件在哪

```
ai-service/openspec/changes/
├── encapsulate-vector-store/     ← 先做這個
│   ├── proposal.md               為什麼做、改什麼、影響範圍
│   ├── specs/ai-generation/spec.md   ADDED / MODIFIED delta
│   └── tasks.md                  7 節、30 項可勾選
└── typed-qdrant-errors/          ← 後做這個
    ├── proposal.md
    ├── design.md                 三個方案比較、為何不推翻前一輪
    ├── specs/ai-generation/spec.md   ADDED / MODIFIED / REMOVED delta
    └── tasks.md                  8 節、35 項可勾選
```

`openspec validate --all` 目前 **5/5 通過**。改動 spec 後務必重跑。

---

## ⚠️ 必讀：這個服務的三個陷阱

### 1. 完全沒有測試框架

`ai-service` **沒有任何 `test_*.py`**，沒有 pytest／unittest。
驗證只能靠 `test.http`（手動 REST Client）與實際啟動服務打 API。

**兩個 change 的 tasks 都把「改動前先寫對照表」列為第 1 節且要求使用者確認**——
這是唯一能在改程式碼之前發現行為退化的手段。**不要跳過這一節直接改碼。**

### 2. E 涉及刪除路徑，錯了會誤刪資料

`replace_protagonist_background` 是唯一帶**兩個條件**的刪除
（`conversation_id` + `type="protagonist_background"`）。
若組 filter 時漏掉 `type`，會把該對話的**角色背景**一起刪掉。

tasks 5.1 專門驗證這點：更新主角背景後，**確認角色背景切片仍在**。
驗證重點是「其他資料未受影響」，不是只確認目標已刪除。

### 3. 不要破壞 Bug 4 的修復成果

Bug 4（2026-07-26 修復）解決的是「Qdrant 中斷後 ai-service 必須整套重啟才恢復」。
核心是「collection 於執行期冪等補建」。兩個 change 都動到相關程式碼：

- E 把 ensure 責任收進 `vector_store` 方法內部
- D 改變 ensure 失敗時拋的例外型別

**兩者的 tasks 都有專門的迴歸驗證項**（E 的 5.5、D 的 6.3）：
停掉 Qdrant 再換上空的，**不重啟 ai-service**，確認仍能自動補建並恢復。

---

## 環境與啟動

- **Qdrant 與 Ollama 需先啟動**。平台根目錄有 `start-all-services.bat`
  （**須先開 Docker Desktop**）。只做 ai-service 的話，
  最少需要 Qdrant（6333）與 Ollama（11434）。
- **`scripts/init_rag.py`** 是診斷腳本，可先跑一次確認 Qdrant 連線與現有 collections。
- **ai-service 是獨立 git repo**（非 monorepo 的一部分）。
  在平台根目錄 `git diff` **看不到** ai-service 的改動，
  要用 `git -C ai-service diff`。這點在先前的除錯中造成過誤判。
- **`src/config/config.json` 不進版控**，首次設置需從 `config.example.json` 複製。
  所有欄位（除 `qdrant.apiKey`）缺一不可，缺鍵會在啟動時直接拋 `ValueError`。

---

## 工作約定（沿用先前建立的，請延續）

1. **不可以靠推測與猜測，一定要找到證據才能寫**。查不到證據的標記「未證實」
   並寫明還缺什麼，不要升格成結論。
   （D 的 tasks 3.4「查證 qdrant_client 實際例外型別」就是這條的直接應用。）
2. **修 bug 不可以違背設計原則與規格**。四份設計文件在平台根目錄：
   `後端系統設計原則.md`、`微服務架構準則.md`、`微服務架構實作spec.md`、
   `前端系統設計原則.md`（另有新增的 `網頁架構設計原則.md`，前端專用）。
3. **可觀察的行為改動要先反映在 spec 再改碼**。這兩個 change 的 spec 都已寫好，
   若執行中發現需要偏離規格，**先改 spec 並告知使用者**，不要直接改碼。
4. **驗證要用「跑起來」而不是「讀過了」**。
5. **關鍵節點停下來跟使用者核對**，不擅自啟動服務、不擅自擴大範圍。
6. **不要順便夾帶其他重構或優化**，只做 tasks 列出的項目。
   兩個 proposal 都明列了「不在本輪範圍」的項目，請尊重那個邊界。

---

## 兩個 change 刻意**不做**的事（不要順手做掉）

- **D**：`get_rag_context`／`get_status`／`get_initialization_status`
  三個端點目前一律回 500、未接入 503 判斷。**維持原狀**，
  主 spec 已載明「刻意維持原行為」。
- **E**：`get_conversation_data` 的 `except Exception` 回傳空 dict 行為
  與其餘方法（被動報錯）不一致。**維持不變**——
  其呼叫端 `rag_service.py:149` 依賴此行為，改動屬可觀察行為變更，需獨立提案。
- **E**：`rag_repository` 對 `vector_store` 仍是具體依賴而非抽象介面（SOLID-DIP）。
  `simplify-ai-service` 已於 service 層處理，repository 層本輪維持現狀。

---

## 完成後

1. 各 change 的 tasks 第 6／7 節有文件同步與收尾項目（含更新 `CLAUDE.md`、
   `openspec/config.yaml` 中已過時的描述）。
2. 平台根目錄 `前端網頁debug_task_checklist.md` 的「待勾選清單」中，
   代辦 D／E 勾選並註記完成情形。
3. **尚未 commit**：ai-service 這輪只新增了 openspec 文件，程式碼未動。
   注意這個 repo 可能還有先前未 commit 的改動，commit 時只挑本輪檔案，
   不要整包 `git add .`。
