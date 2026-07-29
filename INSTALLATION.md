# 新環境部署指南

> 目標：在一台**全新的 Windows 電腦**上，從 `git clone` 總倉庫開始，一路到整套 Persona Nexus 服務能在本機 `http://localhost:8080` 跑起來、並跑完所有測試清單。
>
> 這份是**整理過、可直接照步驟執行**的版本。想知道每個決定背後「為什麼、當初踩了什麼坑」，去看時序性的過程日誌 [部署除錯測試.md](部署除錯測試.md)。

---

## 0. 全貌：這套系統長什麼樣

```
瀏覽器 → http://localhost:8080（Caddy，單一入口，跑在 Docker 容器裡）
                │ 依路徑分流
                ├─ /api/*      → api-gateway (8000) → 各微服務
                ├─ /login*     → persona-nexus-auth      (5173)
                ├─ /character* → persona-nexus-character  (5174)
                ├─ /chat*      → persona-nexus-chat       (5176)
                └─ 其餘         → persona-nexus-lobby      (5175，首頁)
```

- **6 個後端**：api-gateway(8000)、auth-service(3000)、user-service(4000)、character-service(5000)、chat-service(6000)、ai-service(6001，Python/FastAPI)
- **4 個前端**：auth / character / lobby / chat（都是 Vite dev server）
- **兩個容器**：Qdrant(6333，向量資料庫)、Caddy(8080，反向代理)
- **兩個本機服務**：Ollama(11434，LLM，**是否需要視部署情境而定**，見第 4 節)、
  Docker Desktop（Qdrant/Caddy 的後端）

> **鐵則**：日常一律用 `http://localhost:8080` 進，不要直接開 5173/5175 等裸 port——同源部署後前端都用相對路徑，裸 port 沒有 Caddy 會壞掉（詳見 [部署除錯測試.md](部署除錯測試.md) 第 19 節）。

---

## 1. 先手動安裝這些工具（`setup.ps1` 不會幫你裝）

這幾樣是一次性、需要較高權限或要互動的安裝，`setup.ps1` 只會檢查它們在不在 PATH，缺了就中止。**先把它們裝好**：

| 工具 | 安裝方式 | 備註 |
|------|----------|------|
| **git** | 已有大多內建；否則 `winget install --id Git.Git` | 用來 clone |
| **Node.js LTS** | `winget install --id OpenJS.NodeJS.LTS` | 9 個 JS 專案用 |
| **conda** | Anaconda 或 Miniconda（官網下載安裝）| ai-service 的 Python 環境用；記住它裝在哪（例 `C:\ProgramData\anaconda3`） |
| **Ollama** | `winget install --id Ollama.Ollama` | 裝完會自動啟動、監聽 11434。**視第 4 節的方案選擇而定**——若這台機器的 AI 推論/向量檢索都走 Capitolium Gateway，可以不裝這個 |
| **Docker Desktop** | `winget install --id Docker.DockerDesktop` | 需要 WSL2，見下方 |

### WSL2（Docker Desktop 的必要後端）

如果這台從沒裝過 WSL2，Docker 會起不來。**用「以系統管理員身分執行」的 PowerShell** 跑：

```powershell
wsl --install
```

然後**重新開機**，並完成 Ubuntu 首次設定（建立 Linux 使用者帳號/密碼）。裝完確認：

```powershell
docker version
docker info
```

> ⚠️ **裝完工具後，務必開一個「全新的終端機視窗」**（或乾脆登出再登入一次）。Windows 的 explorer 會快取自己啟動時的環境變數，剛裝好的工具在舊視窗 / 直接雙擊 `.bat` 時可能還吃不到新 PATH（[部署除錯測試.md](部署除錯測試.md) 第 14 節踩過這個坑）。

---

## 2. Clone 總倉庫

```powershell
cd C:\Users\<你的帳號>\
git clone https://github.com/kuoliwei/persona-nexus-platform.git
cd persona-nexus-platform
```

總倉庫只含部署設定與文件，10 個微服務/前端子專案是各自獨立的 git 倉庫（被 `.gitignore` 排除），下一步的 `setup.ps1` 會自動 clone 它們。

---

## 3. 跑 `setup.ps1` 一鍵 bootstrap

```powershell
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

這支腳本是**冪等的**（可重複執行，已存在的東西自動跳過），依序做：

1. **檢查前置工具**（git/node/npm/conda/docker/ollama 在不在 PATH）——缺了會列出來並中止，回第 1 步補裝。
2. **Clone 10 個子專案**（`https://github.com/kuoliwei/<repo>.git`）。
3. **產生 5 個後端的 `.env`**——`auth-service`／`api-gateway` 共用同一組隨機生成的 `JWT_SECRET`；`user/character/chat-service` 各自的 `DATABASE_URL` 等。另外把 `ai-service/src/config/config.json` 從 `config.example.json` 複製一份（模型欄位是佔位字串，第 4 步要改）。
4. **`npm install`（9 個 JS 專案）**——含 `npm approve-scripts --all`（否則 `prisma`／`bcrypt` 的 install script 被 npm 新版擋掉，執行期會壞）。
5. **Prisma migrate + generate**（user/character/chat-service 三個 SQLite 服務）。
6. **建 ai-service 的 conda 環境**（`ai-service`，Python 3.11）+ `pip install -r requirements.txt`。
7. **印出還需要你手動處理的事**。

跑完後照它印的黃字提示，繼續下面兩步。

---

## 4. 決定 AI 推論／向量檢索方案，並設定 `config.json`

> 📖 **本節只講「怎麼選」。每個設定欄位的完整說明——合法值、必填條件、填錯會出現
> 什麼症狀——一律見 [ai-service/CONFIG.md](ai-service/CONFIG.md)。**
> `config.json` 內**不放任何註解**，設定檔只放設定，說明都在那份文件。

在下載任何 Ollama 模型之前，**先決定這台機器要用哪一種方案**——這決定了你後面
還要不要做「下載模型」這件事。

`ai-service/src/config/config.json` 有兩個**各自獨立**的開關：

| 設定 | 選項 | 決定什麼 |
|------|------|----------|
| `llm.provider` | `"ollama"` / `"gateway"` | AI 對話生成（聊天回覆、摘要）走本機 Ollama，還是打 Capitolium LLM Gateway |
| `embedding.provider` | `"ollama"` / `"gateway"` | RAG 向量化（角色背景/範例/摘要的存取與檢索）走本機 Ollama，還是打 Gateway |

兩者可以不同（例如 LLM 走 Gateway、embedding 仍走 Ollama），但**多數部署情境會兩個一起切**：

- **本機開發、不依賴外部服務** → 兩個都設 `"ollama"`，照下面繼續 pull 模型（本節其餘步驟適用）
- **部署到合作方（Capitolium）機器，AI 推論走他們的平台** → 兩個都設 `"gateway"`，
  **這台機器不需要安裝任何 Ollama**（回第 1 步，`Ollama` 那列可以跳過），改為在
  `config.json` 填 `llmGateway.*` / `embeddingGateway.*`（`baseUrl`/`apiKey`/`model`
  等，`apiKey` 需先向 Capitolium admin 申請 Virtual Key），細節見平台根目錄
  `app-integration.md`

⚠️ **目前 `llm.provider` 已可使用**（`config.json` 已有此欄位，缺少會導致服務啟動失敗）；
`embedding.provider` 仍在規劃中（見 `ai-service/openspec/changes/add-embedding-gateway-provider/`），
尚未實作，故 RAG 向量化目前**一律走本機 Ollama**。

若 `embedding.provider="gateway"`，`embeddingGateway.dimension`（向量維度）務必填對
（例如 `bge-m3-local` 是 1024 維，`nomic-embed-text` 是 768 維）——填錯不會馬上報錯，
而是之後寫入 Qdrant 時才會因維度不符失敗，故障點會離設定錯誤很遠、不好排查。

### 只用 Ollama（`llm.provider` / `embedding.provider` 皆為 `"ollama"`）

`setup.ps1` **不會**自動 pull 模型（那是好幾 GB 的下載、又是依你 GPU VRAM 決定的選擇）。自己挑一個 pull：

```powershell
# 對話模型（範例：10GB 顯卡夠用的 Gemma 4 E4B 量化版，4.22GB）
ollama pull hf.co/unsloth/gemma-4-E4B-it-qat-GGUF:UD-Q4_K_XL

# RAG embedding 模型（必要，274MB）
ollama pull nomic-embed-text
```

然後編輯 [ai-service/src/config/config.json](ai-service/src/config/config.json)，把 `ollama.model` 改成你**實際 pull 下來的對話模型名稱**（`embedModel` 保持 `nomic-embed-text`）：

```json
{
  "ollama": {
    "model": "hf.co/unsloth/gemma-4-E4B-it-qat-GGUF:UD-Q4_K_XL",
    "embedModel": "nomic-embed-text"
  }
}
```

> 這個檔案是**機器專屬、不進版控**的（每台機器 pull 的模型不同）。若忘了改、留著佔位字串，ai-service 每次聊天生成都會失敗。

---

## 5. 確認 Docker Desktop 正在跑

`start-all-services.bat` 只會呼叫 `docker run` 拉 Qdrant/Caddy 容器，**不會幫你啟動 Docker Desktop 這個 GUI 程式**。剛裝完/剛開機時，先**手動打開 Docker Desktop**，等它狀態變成 running（鯨魚圖示不再轉）。

---

## 6. 一鍵啟動全部服務

從倉庫根目錄執行（雙擊或在終端機跑）：

```powershell
.\start-all-services.bat
```

它會：檢查/啟動 Ollama、Qdrant；依序背景啟動 5 個後端 + ai-service + 4 個前端；拉起 Caddy(8080)；最後問你要不要開 ngrok（不需要就答 `n`，見第 10 節）。

> ai-service 那個視窗是靠解析 `conda env list` 拿到環境的 `python.exe` 直接執行的（不走 `activate.bat`，避開 conda 在巢狀批次下的遞迴 bug）。若自動偵測不到，見第 9 節的 `start-config.local.bat`。

---

## 7. 用 `http://localhost:8080` 驗證同源路由

用**真正的外部瀏覽器（Chrome / Edge）**開 `http://localhost:8080`。

> ⚠️ **不要用 VS Code 內建的 Simple Browser**——它的 webview 對 localStorage/history/重導有怪毛病，會造成假的重整迴圈（[部署除錯測試.md](部署除錯測試.md) 第 19 節）。

快速健檢（可在瀏覽器直接點，或用 curl）：

| 路徑 | 預期 |
|------|------|
| `http://localhost:8080/` | 200，大廳首頁 |
| `http://localhost:8080/login/` | 200，登入頁 |
| `http://localhost:8080/character/` | 200 |
| `http://localhost:8080/chat/` | 200 |
| `http://localhost:8080/api/config` | 200，回一段 JSON |

然後實際走一遍：**註冊 → 登入 → 建立角色 → 回大廳看到角色 → 進聊天室送訊息拿到 AI 回覆**。能整條走通，代表 RAG + LLM 管線是通的。

---

## 8. 跑測試清單

系統堪用後，倉庫裡有 5 份對照原始碼寫的測試清單，照裡面的「執行方式注意事項」用 PowerShell 模擬前端行為逐條測（不是手動點瀏覽器）。**順序：先四份基礎，全過了再跑進階**。

1. [測試清單-persona-nexus-auth.md](測試清單-persona-nexus-auth.md)（註冊/登入，10 案例）
2. [測試清單-persona-nexus-character.md](測試清單-persona-nexus-character.md)（角色 CRUD，14 案例）
3. [測試清單-persona-nexus-lobby.md](測試清單-persona-nexus-lobby.md)（大廳/我的角色，8 案例）
4. [測試清單-persona-nexus-chat.md](測試清單-persona-nexus-chat.md)（聊天/摘要/刪除，15 案例）
5. [測試清單-進階整合測試.md](測試清單-進階整合測試.md)（多帳號/多角色/權限/摘要聯動刪 Qdrant，23 案例）——**四份基礎都過才執行**

> 清單裡已把之前實測踩到的 PowerShell 坑寫進「執行方式注意事項」：`Get-Content` 字串要 `[string]` 強制轉型、錯誤內容讀 `$_.ErrorDetails.Message`、中文欄位要轉 UTF-8 bytes 再送。照做就不會踩重複的雷。

摘要機制的驗證會用到倉庫既有的 [list-summaries.ps1](list-summaries.ps1)（直接查 Qdrant 的 `summaries` collection、跟 DB 交叉比對、內建孤兒摘要檢查）。

---

## 9. 常見問題排除

| 症狀 | 原因 / 解法 |
|------|-------------|
| `setup.ps1` 說某工具 not found | 回第 1 步裝好那個工具，**開新終端機**再重跑 `setup.ps1`。 |
| 雙擊 `.bat` 說找不到 `docker`／`npm` | explorer 的 PATH 快取是舊的。**登出再登入**一次（不必整台重開機）。 |
| Qdrant/Caddy 連線被拒 | Docker Desktop 沒開。手動開 Docker Desktop 等它 running，再重跑 `.bat`。 |
| ai-service 視窗 `BATCH RECURSION exceeds STACK limits` | 舊版腳本的 conda activation 遞迴 bug，現版已改成直接呼叫 `python.exe`。若還遇到，用第 9 節下方的 `AI_PYTHON_EXE` 手動指定。 |
| ai-service 每次聊天生成都失敗 | `config.json` 的 `ollama.model` 還是佔位字串，或指到沒 pull 的模型。回第 4 步。若這台機器選的是 `"gateway"` 方案，檢查 `llmGateway`/`embeddingGateway` 的設定與 Virtual Key 是否正確。 |
| 登入頁「無法連線至服務器」 | 你多半是開了裸 port（5173）或用 VS Code Simple Browser。改用真瀏覽器 + `http://localhost:8080`。（此症狀的既有 bug 已於第 19 節修復——config-loader 已改相對路徑。） |
| 建立角色後大廳一直重整 | 同上，開裸 port 造成。改走 8080。 |
| 角色沒填性別就無法聊天（ai-service 回 422） | 已知的既有 bug（character-service 允許 null、ai-service 要求必填），裁示不修。建角色時填一下 `gender` 即可繞過。 |
| 改了前端 `vite.config.js` 後路由壞掉 | 跑 `powershell -File check-vite-configs.ps1` 檢查四個前端的 `base`/`host`/`allowedHosts` 有沒有漂移。 |

### 機器專屬覆寫：`start-config.local.bat`

有些值每台機器不同、無法自動偵測（conda 環境的 python 路徑、ngrok 路徑）。複製範本後填自己的：

```powershell
Copy-Item start-config.local.bat.example start-config.local.bat
# 編輯 start-config.local.bat，需要時取消註解並填：
#   set AI_PYTHON_EXE=C:\...\envs\ai-service\python.exe   （自動偵測失敗時才需要）
#   set NGROK_PATH=C:\...\ngrok                            （要開 ngrok 才需要）
```

這個檔案已列入 `.gitignore`，不進版控、不會帶到別台機器。

---

## 10. （可選）對公網公開

本機跑起來後，若要讓外網也能連（demo 用），**優先用 Cloudflare Tunnel**，見獨立教學 [cloudflared公開服務教學.md](cloudflared公開服務教學.md)。重點：它只是把本機的 8080 往公網轉一層，跟 Caddy 是疊加不是替代；用完就關，別長時間掛著。

> 原本用 ngrok，2026-07-29 因 Windows Defender 把 ngrok.exe 標記為 Trojan/PUA 反覆隔離（新機器很可能一裝就撞到這個坑，且排除項對新版本無效）而改用 Cloudflare Tunnel。若仍想用 ngrok，舊教學留在 [ngrok公開服務教學.md](ngrok公開服務教學.md)，但建議先看過 Cloudflare 那份的第 5 節疑難排解，省去重新踩坑的時間。

---

## 附錄：一頁速查

```
# 全新機器，一次到位的最短路徑：
1. 裝工具：Node LTS / conda / Docker Desktop(+WSL2)，Ollama 視第 4 步的方案選擇   → 開新終端機
2. git clone https://github.com/kuoliwei/persona-nexus-platform.git && cd persona-nexus-platform
3. powershell -ExecutionPolicy Bypass -File .\setup.ps1
4. 決定 llm.provider 方案（欄位說明見 ai-service/CONFIG.md）
   → 若 ollama：ollama pull <對話模型> && ollama pull nomic-embed-text
   → 若 gateway：填 llmGateway 設定（需先申請 Virtual Key）
   → 改 ai-service/src/config/config.json
5. 開 Docker Desktop（等 running）
6. .\start-all-services.bat
7. 真瀏覽器開 http://localhost:8080，走一遍註冊→登入→建角色→聊天
8. 跑 5 份測試清單（先 4 基礎，後 1 進階）
```

相關文件：
- [ai-service/CONFIG.md](ai-service/CONFIG.md)：**ai-service 設定欄位完整說明**（第 4 步會用到——各欄位合法值、必填條件、填錯的症狀、`llm.provider` 怎麼選）。
- [部署除錯測試.md](部署除錯測試.md)：完整過程日誌與每個坑的原因分析。
- [佈署便利性改進清單.md](佈署便利性改進清單.md)：搬遷時整理的待改進項目與完成紀錄。
- [MICROSERVICES.md](MICROSERVICES.md)：所有子倉庫的清單。
- [ARCHITECTURE.md](ARCHITECTURE.md)：整體架構說明。
- [deploy/README.md](deploy/README.md)：同源部署（Caddy）的規格。
- [app-integration.md](app-integration.md)：Capitolium LLM Gateway 接入指南（`gateway` 方案的 Virtual Key 申請、`baseUrl`/模型清單）。
- `ai-service/openspec/changes/add-llm-gateway-provider/`、`add-embedding-gateway-provider/`：`llm.provider`/`embedding.provider` 兩個 config 開關的完整設計規劃。
