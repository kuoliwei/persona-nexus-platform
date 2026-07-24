# 這份文件不屬於本專案，而是屬於LLMOPS平台，由於本專案要與LLMOPS合作，因此提供我們這份文件做參考

# LLM Gateway 接入指南 — 給 app 端團隊

給要接 Capitolium LLM Gateway 的消費端 app（**MSME、GuideTrust、NestLyzer…**）。
**如果你的 app 要呼叫 LLM，這份是你的起點。** 自足可交付：照著做就能接通並上線。

這份是**給應用端的唯一整合文件**——接通、模型、長輸出、Embedding、限流、標記用戶、查用量，全部在這裡。

---

## TL;DR

1. Gateway 講的是**與 OpenAI 完全相同**的 API。用官方 `openai` SDK，只改 `base_url` 與 `api_key` 兩個設定，其餘程式碼一行不動。
2. 跟 admin 拿一把 **Virtual Key**（`sk-...`），這把 key 綁在你 app 的名下。
3. `model` 建議填 **`smart-router`**，讓平台依任務難度自動選模型。
4. **一定要做**：收到 `429` → 指數退避重試；每次請求帶 OpenAI `user` 參數標記終端用戶。
5. **要長回應就給足 `max_tokens`**，否則會被截斷；長輸出建議用**串流**（見下）。

---

## 三步接通

只需設定三樣東西：

| 設定 | 填什麼 |
|------|--------|
| `base_url` | `http://<server-b-ip>:4000`（端點是 `/v1/chat/completions`，SDK 會自動補） |
| `api_key`  | Gateway 發的 **Virtual Key**（`sk-...`）——**不是**任何 provider（OpenAI/Anthropic/Google）的金鑰 |
| `model`    | 建議 `smart-router`；或指定具體 `model_name`（見下方模型清單） |

> `<server-b-ip>`：本機部署填 `localhost`；跨機填 Server B 的內網 IP（向 admin 索取）。無 TLS、純內網，`http://` 不是筆誤。

### Python（官方 openai 套件）

```python
# pip install openai
from openai import OpenAI

client = OpenAI(
    base_url="http://<server-b-ip>:4000",   # ← 指向 LLM Gateway，而非 OpenAI
    api_key="sk-你的VirtualKey",             # ← Gateway 的 Virtual Key
)

resp = client.chat.completions.create(
    model="smart-router",                    # 讓平台自動選模型
    messages=[{"role": "user", "content": "你好，自我介紹一句"}],
    user="guidetrust:user:u8f31",            # ← 標記終端用戶（見下）
)
print(resp.choices[0].message.content)
```

### Node.js（官方 openai 套件）

```javascript
// npm install openai
import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "http://<server-b-ip>:4000",
  apiKey: "sk-你的VirtualKey",
});

const resp = await client.chat.completions.create({
  model: "smart-router",
  messages: [{ role: "user", content: "你好，自我介紹一句" }],
  user: "nestlyzer:user:u8f31",
});
console.log(resp.choices[0].message.content);
```

### curl

```bash
curl http://<server-b-ip>:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-你的VirtualKey" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "smart-router",
    "messages": [{"role": "user", "content": "你好，自我介紹一句"}],
    "user": "guidetrust:user:u8f31"
  }'
```

> repo 附了一支最小可跑範例 `examples/hello_gateway.py`（uv 管理環境），設好 Virtual Key 即可一鍵驗證接通。

---

## 怎麼拿到 Virtual Key

Virtual Key 不是自己產生的，也**不要共用別的 app 的 key**——每個 app 是一個獨立租戶，用量、預算、限流都以「key 掛在哪個 app 名下」來歸戶。

1. 到整合控制台（Console，`http://<server-b-ip>:8080`）以你 app 的 **app-user 帳號**登入，於自助頁面**申請 key**（審核制）。
2. admin 核准後即生效；你可以擁有多把 key（例如線上流量一把、批次一把）。
3. key 的別名由 admin 依規則命名 `<app-slug>-<env>-<用途>`，例如 `guidetrust-prod-online`、`nestlyzer-prod-batch`。

沒有帳號 / 不確定你的 app-slug → 聯絡 Capitolium admin 開通。

> 你的 key 預設綁定：**只能走 `smart-router`**（無法直接指定後端模型）、RPM/TPM 斷路器、`max_budget` 成本上限。這些對正常使用完全無感，詳見下方「模型該填什麼」與「限流與 429」。

---

## 模型該填什麼

### 建議：`smart-router`（自動選模型）

填 `model: "smart-router"`，平台會依**任務難度**自動選後端：簡單 → 地端便宜模型、複雜/推理 → 雲端強模型。對你完全透明、回應格式不變。

- 你**不必**知道背後選了哪個模型，也不必隨模型汰換改程式。
- app-user 的 key 預設**只開放 `smart-router`**；直接指定 `claude-opus-4-8` 這類具體後端會被 `401` 擋（這是刻意的治理設計）。
- 要什麼模型參與自動選擇，由 admin 在 Console `/admin/routing` 掌控，不需你介入。

### 想指定具體模型

若你的 key 有開放具體模型白名單，可直接填 `model_name`。切換模型 = 只改這個字串：

```
smart-router                                                          → 依難度自動選（建議）
gemini-3.5-flash / gemini-3.1-pro-preview                            → Google Gemini（雲端）
claude-fable-5 / claude-opus-4-8 / claude-sonnet-5 / claude-haiku-4-5 → Anthropic（雲端）
gpt-5.1 / gpt-5 / gpt-4.1 / gpt-4.1-mini / gpt-4o / gpt-4o-mini       → OpenAI（雲端）
llama3.1-local / gemma4-local                                        → 地端 Ollama（免金鑰、不出網）
```

> 具體有哪些可用，以 `GET http://<server-b-ip>:4000/v1/models`（帶你的 key）為準。

---

## 長輸出：別被截斷（`max_tokens` 與串流）

> **這是實際踩過的坑：** app 端呼叫後發現回應「講到一半就斷了」，追了半天，最後發現**不是 gateway 的問題，是請求帶的 `max_tokens` 太小**——模型在到達上限時被硬切掉。要長回應，這兩件事一定要做對。

### 1. 要長回應就給足 `max_tokens`

`max_tokens` 是**這次回應**能產生的 token 上限，不是「大概值」——到了就**硬切**，不會客氣。

- **需要長輸出（報告、長文、逐步解說）就明確帶足夠的 `max_tokens`**（例如 `4096`、`8192`），別用預設或很小的值。
- 用 `smart-router` 時：它**尊重你明確帶的值**；未帶時依難度給預設（1024 / 2048 / 4096 / 8192）。**只有在你指示裡有明顯的長度線索（字數要求、報告類詞）且你帶的值又低於該難度預設時，才會幫你往上拉**（可稽核）。所以**別指望它替你猜**——要長輸出，自己帶足。
- 判斷是否被截斷：回應的 `finish_reason` 為 **`length`** 就代表撞到 `max_tokens` 上限被切斷（正常結束是 `stop`）。你的程式可以據此偵測並提示或重試。

```python
resp = client.chat.completions.create(
    model="smart-router",
    messages=[{"role": "user", "content": "寫一份 800 字的產品分析報告"}],
    max_tokens=4096,   # ← 長輸出務必給足；不帶或給太小 → 被截斷
)
if resp.choices[0].finish_reason == "length":
    ...  # 被截斷了：提高 max_tokens 或分段
```

### 2. 長輸出建議用**串流（streaming）**

長回應若一次等到好，使用者要盯著空白等很久、也容易撞連線逾時。**長文字建議改用串流**，逐字回吐、體驗好很多。用法跟 OpenAI 完全一樣，加 `stream=True`（Python）/ `stream: true`（Node）：

```python
stream = client.chat.completions.create(
    model="smart-router",
    messages=[{"role": "user", "content": "寫一份詳細的市場分析"}],
    max_tokens=8192,        # ← 串流也一樣要給足 max_tokens，否則照樣被截斷
    stream=True,
    user="guidetrust:user:u8f31",
)
for chunk in stream:
    print(chunk.choices[0].delta.content or "", end="", flush=True)
```

> **串流不等於沒有上限**：`max_tokens` 對串流一樣有效，太小照樣中途斷。串流解決的是「等待體驗」，`max_tokens` 解決的是「會不會被切斷」——兩者要一起做對。串流請求同樣受限流（在請求進入 gateway 時判斷）。

---

## App 端契約（必守）

以下是接入契約，不是建議。第 1 點攸關整個平台的穩定，務必做到。

### 1. 收到 `429` → 指數退避（**強制**）

每把 key 都有 **RPM**（每分鐘請求數）與 **TPM**（每分鐘 token 數）上限，超過回 **HTTP 429**。

- **你必須做**：收到 429 → 指數退避（exponential backoff）重試。
- **你絕對不能做**：收到 429 → 立刻重打、或無限重試。

**為什麼這麼嚴格：**

1. **預算擋不住失控。** 每把 key 有 `max_budget`，但**預算是錢已經花掉之後才擋**；一個迴圈 bug 能在幾分鐘內把整月預算燒光。**流量上限是唯一能在事前攔截的機制。**
2. **你的失控會拖垮其他 app。** Capitolium 單機、無 HA、無基礎設施層隔離——若無 per-key 流量閘門，一個 app 的迴圈 bug 會吃光整個 gateway 的處理能力，**連帶讓所有其他租戶無法服務**。限流讓失控被侷限在該租戶自己的額度內（已實測）。

**門檻怎麼設——這是斷路器，不是容量管理：** 預設 **60 RPM / 200,000 TPM**。實測全平台單分鐘尖峰僅 **~6 RPM**，而失控迴圈是**數千 RPM**（差三個數量級）。門檻遠高於任何合理使用、卻遠低於失控量級——**正常使用永遠不會碰到它；碰到了，代表你的 app 出事了。** 需要更高額度跟 admin 說即可（方向是隨成長放寬，不是壓在剛好夠用）。

> **為什麼 TPM 也要管**：單一 100k token 的請求比 100 個小請求更貴。只看 RPM 擋不住「低頻但巨量」的成本失控——每分鐘 3 個請求、每個塞 50k token，RPM 看起來很健康、錢卻在狂燒。TPM 是**成本**閘門，RPM 是**容量**閘門，攔截不同的失效模式。

**✅ 正確：指數退避 + jitter**

```python
import time, random
from openai import RateLimitError

def call_with_backoff(client, **kwargs):
    for attempt in range(5):
        try:
            return client.chat.completions.create(**kwargs)
        except RateLimitError:
            if attempt == 4:
                raise
            # 指數退避 + jitter（避免多個 client 同步重試而再次一起撞牆）
            time.sleep(min(2 ** attempt + random.uniform(0, 1), 60))
```

要點：等待時間**隨次數指數增長**（1s→2s→4s…）、**加 jitter**、**有重試上限**、**設等待上限**（如 60s）。

**❌ 錯誤：立即重打 / 無限重試**

```python
while True:
    try:
        return client.chat.completions.create(...)
    except RateLimitError:
        continue          # ← 立刻重打
```

**這比不限流更糟。** 你會把「短暫限流」變成「持續的自我 DDoS」：不斷送出注定被拒的請求、吃光 gateway，最後連自己恢復正常後的請求都打不進去。

> 429 的錯誤訊息含 `Rate limit exceeded`，OpenAI SDK 會拋 `RateLimitError`。你的 key 上限可請 admin 在 Console `/admin/keys` 查得。

### 2. 標記終端用戶：帶 OpenAI `user` 參數

你 app 內的**終端用戶不會**、也**不該**成為 Capitolium 的帳號或各自持 key。要區分「這次請求是哪個終端用戶發的」，**每次請求帶 OpenAI 標準的 `user` 參數**：

```python
user="guidetrust:consultant:u8f31:case:c442"   # 由你 app 自訂的穩定識別字串
```

- 平台會把它記進 spend log，未來可據此出 per-end-user 用量。
- **請用穩定的內部 ID，不要放真名 / email / 電話**（明文上線路、且會進 log）。
- 你 app 內更細的軟性配額（某用戶本月剩餘額度等）由**你自己管**：呼叫前查自己的 DB、超額就別呼叫。Capitolium 不做這層。

### 3.（進階）重生成升級訊號

當終端用戶對結果不滿意、按「重新生成」時，你可在請求帶 metadata 讓 `smart-router` 升級到更強的模型層：

```python
resp = client.chat.completions.create(
    model="smart-router",
    messages=messages,
    extra_body={"metadata": {"smart_router_attempt": 2}},  # 第 N 次生成：2 升一級、>=3 直上最強推理層
)
```

- 何時帶、升幾次由**你的產品邏輯**決定；第一次生成不必帶（缺席 / 值為 1 → 行為不變）。
- 升級仍受你 key 的路由候選集與 `max_budget` 約束（候選集裡沒有的模型升不上去）。
- 決策會寫進 Langfuse trace（`escalated_from` / `attempt`）可稽核。

---

## Embedding（文字向量化）

要做語意搜尋、RAG、去重、分類，你需要把文字轉成向量（embedding）。Gateway 提供 OpenAI 相容的 `/v1/embeddings`，用**同一把 Virtual Key**、同一組認證即可。

### 用法

用 `client.embeddings.create`，`model` 填**明確的 embedding 模型名**（見下）：

```python
from openai import OpenAI
client = OpenAI(base_url="http://<server-b-ip>:4000", api_key="sk-你的VirtualKey")

resp = client.embeddings.create(
    model="bge-m3-local",              # 或 text-embedding-3-small
    input="要向量化的一段文字",          # 也可傳 list[str] 一次多筆
)
vec = resp.data[0].embedding           # 浮點數陣列
```

curl（⚠️ 中文 input 要用 `--data-binary @檔案`，直接 `-d` 會因編碼壞掉、回假的 `model=None`）：

```bash
printf '%s' '{"model":"bge-m3-local","input":"要向量化的一段文字"}' > req.json
curl http://<server-b-ip>:4000/v1/embeddings \
  -H "Authorization: Bearer sk-你的VirtualKey" -H "Content-Type: application/json" \
  --data-binary @req.json
```

### 可用模型

| 模型 | 來源 | 維度 | 適用 |
|------|------|------|------|
| `bge-m3-local` | 地端 Ollama | **1024** | 中文/多語佳、**免費、不出網**（成本 0）；離線/隱私情境首選 |
| `text-embedding-3-small` | 雲端 OpenAI | **1536** | 跨語一致的雲端品質；有計費 |
| `text-embedding-3-large` | 雲端 OpenAI | **3072** | 需要更精準檢索時；維度更高、成本更高 |
| `gemini-embedding-001` | 雲端 Google | **3072** | Google 生態的雲端選項 |

> 以 `GET /v1/models`（帶你的 key）為準；要用哪個 embedding 模型，該 key 的白名單需明確含它（找 admin 開）。

### ⚠️ 維度不相容——同一索引只能用同一個模型

**不同 embedding 模型的向量維度不同、彼此不可比較**（1024 ≠ 1536）。這代表：

- **同一個向量索引/資料庫，從頭到尾只能用同一個 embedding 模型**。不能一半用地端 `bge-m3-local`、一半用雲端 `text-embedding-3-small`，再拿來算相似度——結果無意義。
- 「雲端與地端都提供」的意思是**依情境二選一**（離線/免費/隱私 → 地端；跨語一致的雲端品質 → OpenAI），**不是混用**。
- 若日後要換 embedding 模型，等於要**把整個索引重新向量化（re-embed）**，不是換個字串就好。

### 其他

- **不要送 `smart-router`**：embedding 一律用明確模型名。智慧路由只服務對話（依難度選 chat 模型），送 embedding 進去會被改寫成 chat 模型而失敗。
- embedding 呼叫一樣受 **RPM/TPM 限流**（見上）、一樣會被 Langfuse trace（地端成本 0）。
- 向量的**儲存與檢索由你 app 自管**；Capitolium 只負責把文字轉成向量。

---

## 查自己的用量（M2M usage API）

想在自己的後台顯示 LLM 用量或成本，Console 後端提供一個**唯讀、租戶隔離**的彙總端點。

```
GET http://<server-b-ip>:8080/api/platform/usage?from=2026-07-01&to=2026-07-14
Authorization: Bearer <你的 usage token>
```

- **唯讀、只回你自己名下 key 的用量**：這把 token 對應一個 **client-id（= 你在 Console 的 app-slug）**，後端據此收斂到「該 app 名下的所有 key」，**收斂界線寫死在後端，任何參數都繞不過**。看不到別的租戶，也不能拿來呼叫 LLM 或改動任何東西。
- **這是另一把 token**（不是呼叫 LLM 的 Virtual Key），向 admin 索取（存於 Capitolium 的 `.env`，不在版控）。⚠️ 機密：進你的 secret 管理、別寫死在原始碼、別明文傳遞。未設定時端點 **fail closed**（一律拒絕）。
- **Base URL**：與 Capitolium 同機填 `localhost:8080`；跨機填 `<server-b-ip>:8080`（需 admin 開放 inbound `:8080`）。

### 參數與範圍

| 參數 | 說明 |
|------|------|
| `from` | 起日 `YYYY-MM-DD`，**含當日** |
| `to`   | 迄日 `YYYY-MM-DD`，**含當日** |

- 日期以 **Asia/Taipei** 解讀（不是 UTC——做日報表時跨日邊界會差 8 小時）。
- `from`/`to` **必須成對**；只給一個回 400。**跨度上限 31 天**，超過回 400（更長區間請分段查詢再合併）。
- **兩者皆不給** → 預設回**近 7 天**（含今日）。

### 回應

```json
{
  "schema_version": 1,
  "range":  { "from": "2026-07-14", "to": "2026-07-14" },
  "totals": { "calls": 77, "prompt_tokens": 920, "completion_tokens": 303,
              "total_tokens": 1223, "cost_usd": 0 },
  "by_day": [
    { "date": "2026-07-14", "calls": 77, "prompt_tokens": 920,
      "completion_tokens": 303, "total_tokens": 1223, "cost_usd": 0 }
  ],
  "by_key": [
    { "key_alias": "guidetrust-prod-online", "username": "guidetrust",
      "console_key_id": "cmrk8q93f0005o774hxozplsr",
      "user_id": "cmrk8nlf60002o774alm4xsdu",
      "max_budget": 10, "remaining": 10,
      "calls": 77, "prompt_tokens": 920, "completion_tokens": 303,
      "total_tokens": 1223, "cost_usd": 0 }
  ]
}
```

- `schema_version` — 目前 `1`；日後破壞性變更會遞增，**解析時請檢查它**。
- `totals` 整區間合計；`by_day` 依日拆分（直接餵折線圖）；`by_key` 依 Virtual Key 拆分，含 `max_budget` 與 `remaining`（剩餘預算）。
- 金額/token/呼叫數皆來自 LLM Gateway 逐次 spend 紀錄（canonical，與計費同源）；**回應不含任何 raw 金鑰**。

> **⚠️ `cost_usd` 是 0 不代表壞掉。** Capitolium 走 Cloud-Edge 混合，智慧路由把**簡單任務送到地端模型**（`llama3.1-local`，跑在 Server B 的 GPU），**那些呼叫成本就是 0**。你會看到「呼叫數很多、花費卻很低」——這是正確的、也正是這套架構的目的；只有 MEDIUM 以上難度才會路由到雲端並計費。

### Python 範例

```python
import os, requests

BASE = "http://localhost:8080"
TOKEN = os.environ["CAPITOLIUM_USAGE_TOKEN"]   # 從環境變數讀，不要寫死

def fetch_usage(from_date: str, to_date: str) -> dict:
    r = requests.get(
        f"{BASE}/api/platform/usage",
        params={"from": from_date, "to": to_date},
        headers={"Authorization": f"Bearer {TOKEN}"},
        timeout=30,
    )
    r.raise_for_status()
    data = r.json()
    if data["schema_version"] != 1:
        raise RuntimeError(f"未預期的 schema_version: {data['schema_version']}")
    return data

usage = fetch_usage("2026-07-01", "2026-07-14")
print(usage["totals"]["cost_usd"], usage["totals"]["total_tokens"])
```

---

## 常見錯誤對照

| 現象 | 多半是 | 怎麼辦 |
|------|--------|--------|
| `401 Unauthorized`（呼叫 LLM） | key 錯 / 過期 | 確認 `api_key` 正確 |
| `403 Forbidden`（呼叫 LLM） | 你**直接指定了此 key 未開放的模型**（含 embedding） | 把 `model` 改回 `smart-router`，或請 admin 把該模型加進白名單 |
| `429 Too Many Requests` | 超過 RPM/TPM | 指數退避重試（見契約 1）；持續發生 → 找 admin 調額或查 app 迴圈 bug |
| **回應被截斷 / `finish_reason: length`** | **`max_tokens` 太小** | **帶足夠的 `max_tokens`**；長輸出考慮串流（見「長輸出」節） |
| embedding 呼叫失敗或維度怪異 | 送去了 `smart-router`，或混用了不同 embedding 模型 | embedding 用**明確模型名**；同一索引只用同一模型（見「Embedding」節） |
| `400` + `model=None` 之類怪錯 | curl 送非 ASCII（中文）payload 的編碼問題 | 用 `--data-binary @file.json` 送檔案，別把中文直接塞進 `-d` |
| usage API 回 `401` | token 錯誤或未帶 | 檢查 `Authorization` header；跟 admin 確認 usage token |
| usage API 回 `403` | client-id 不是有效 app_user（帳號不存在或已停用） | 聯絡 admin |
| usage API 回 `400` | 日期格式錯、`from`/`to` 未成對、或跨度超過 31 天 | 修正參數 |

---

## 上線前檢查清單

- [ ] `base_url` 指向 `http://<server-b-ip>:4000`，`api_key` 用的是 Gateway 的 Virtual Key（不是 provider 金鑰）
- [ ] `model` 用 `smart-router`（除非有具體需求）
- [ ] **需要長輸出的呼叫有帶足夠 `max_tokens`**，並偵測 `finish_reason == "length"`
- [ ] **長輸出用串流**（`stream=True`），改善等待體驗
- [ ] **429 有指數退避重試**，且**沒有**任何無限重打的路徑
- [ ] 每次請求帶 `user` 參數標記終端用戶（穩定內部 ID，無 PII）
- [ ] 用 `examples/hello_gateway.py` 或一支 curl 驗證過端到端接通
- [ ]（若用 embedding）用**明確模型名**呼叫、同一索引固定同一個 embedding 模型（維度不相容，見「Embedding」節）
- [ ]（選用）接了 usage API 監看自己的用量/成本，並處理 `cost_usd = 0` 的正常情況

---

## 相關

- 更深的治理與運維（智慧路由評分細節、Virtual Key 四層閘門、多租戶身分模型、部署）：見 repo 根目錄 `README.md`。
