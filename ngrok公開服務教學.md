# 用 ngrok 把服務公開到公網教學

> 這份教學針對 Persona Nexus 的**同源部署架構**（Caddy 反向代理 + 相對路徑前端）量身寫。
> 讀之前請先理解一件事：**ngrok 跟 Caddy 是兩回事**，先搞懂它們的關係再往下看。

---

## 0. 核心觀念：ngrok ≠ Caddy，別搞混

這是最多人卡住的地方，先講清楚：

```
外網訪客的瀏覽器
   │  打 https://abc123.ngrok-free.app  （公網網址）
   ▼
ngrok 通道（把公網流量轉進你本機）
   │
   ▼
你本機的 Caddy（localhost:8080）  ← 這才是「服務的單一入口」
   │  依路徑分流
   ├─ /api/*      → api-gateway (8000) → 各微服務
   ├─ /login*     → auth 前端 (5173)
   ├─ /character* → character 前端 (5174)
   ├─ /chat*      → chat 前端 (5176)
   └─ 其餘         → lobby 大廳 (5175)
```

- **Caddy（8080）是本機正常的入口**，不管有沒有 ngrok，它都在跑，你本機一律用 `http://localhost:8080`。
- **ngrok 只是額外把「已經在 8080 跑的 Caddy」往公網轉一層**。它是疊加，不是替代。
- 所以：**ngrok 沒開 / 開失敗，完全不影響你本機用 8080。** 之前會以為「ngrok 失敗就不能用」是誤解。

> ⚠️ 鐵則：**ngrok 永遠轉發 8080（Caddy），不要轉發其他 port。**
> 轉發 5173/5175 等單一前端的裸 port，會因為缺少 Caddy 的 `/api/*` 分流而整個壞掉。

---

## 1. 為什麼這個架構「隨便換公網網址都能動」

這是同源部署 + 相對路徑帶來的好處，值得知道，因為它解釋了為什麼你**不用**為 ngrok 改任何設定：

- 4 個前端呼叫後端一律用**相對路徑**（`/api/config`、`/api/characters`…），不寫死 `http://localhost:8000`。
- 當外網訪客打開 `https://abc123.ngrok-free.app` 時，瀏覽器把相對路徑解析成
  `https://abc123.ngrok-free.app/api/config` → ngrok 通道 → 你的 Caddy → gateway。
- 全程**同源**（瀏覽器眼中 origin 一直是那段 ngrok 網址），所以**零 CORS 問題**、也不用把 ngrok 網址加進任何白名單。

> 對照組：如果前端寫死 `http://localhost:8000`，外網訪客的瀏覽器會去打**他自己電腦的 localhost:8000**（根本不存在）→ 整個壞掉。
> 這也是為什麼前端的 `config-loader.js` 一定要用相對路徑 `/api/config`——它同時是「本機走 8080」和「ngrok 公開」兩條路都能動的前提。

另外，Vite dev server 的 `allowedHosts: true`（已在各前端 `vite.config.js` 設好）會放行 ngrok 轉進來的 Host 標頭，所以前端頁面本身也接得住。**這些都已經配好，不用再動。**

---

## 2. 前置條件

開 ngrok 前，先確認本機服務都正常：

1. `start-all-services.bat` 已經跑過，所有後端 + 前端 + Caddy 都起來了。
2. 用真瀏覽器開 `http://localhost:8080` 能正常登入、使用——**本機都不通就先別開 ngrok**，ngrok 只會把「本機能動的東西」原樣公開，不會修好本機的問題。

確認 Caddy 活著：

```powershell
docker ps --filter "name=nexus-caddy"
curl http://localhost:8080/
```

---

## 3. 安裝 ngrok（這台家用電腦目前還沒裝）

> 公司電腦當初裝在 `C:\Users\MSI3090\ngrok`，家裡這台是乾淨的，要重裝一次。

以下四種擇一即可，前三種都是純指令、不用開瀏覽器。

**方式 A：winget（最快，Win10/11 內建）**

```powershell
winget install ngrok.ngrok
```

裝完後 `ngrok` 會自動進 PATH（可能要重開一個新的終端機視窗才吃得到）。

**方式 B：Scoop 或 Chocolatey（有裝套件管理員的話）**

```powershell
# Scoop
scoop install ngrok

# 或 Chocolatey（需系統管理員權限的終端機）
choco install ngrok -y
```

**方式 C：純 PowerShell 指令下載＋解壓（不想裝套件管理員就用這個）**

把 ngrok 直接抓下來解壓到 `C:\Users\Guo Li-Wei\ngrok\`，全程指令、不碰瀏覽器：

```powershell
# 1. 建立目標資料夾
$dest = "C:\Users\Guo Li-Wei\ngrok"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

# 2. 下載官方 Windows 64 位元穩定版 zip
$zip = Join-Path $env:TEMP "ngrok.zip"
Invoke-WebRequest -Uri "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip" -OutFile $zip

# 3. 解壓（會得到 ngrok.exe）
Expand-Archive -Path $zip -DestinationPath $dest -Force
Remove-Item $zip

# 4. 確認
& "$dest\ngrok.exe" version
```

> 這個資料夾路徑（`C:\Users\Guo Li-Wei\ngrok`）待會第 5 節設 `NGROK_PATH` 時會用到，記住它。
> 用這個方式裝的 `ngrok` **不會自動進 PATH**，所以之後要嘛用完整路徑呼叫、要嘛靠 `NGROK_PATH`（方式二啟動）幫你定位。

**方式 D：官網手動下載（最後備案，要開瀏覽器）**

1. 到 https://ngrok.com/download 下載 Windows 版 `ngrok.exe`。
2. 解壓到一個你記得住的資料夾，例如 `C:\Users\Guo Li-Wei\ngrok\`。

裝完不管哪種方式，確認版本（有進 PATH 的話）：

```powershell
ngrok version
# 若說找不到指令，代表沒進 PATH，改用完整路徑：
& "C:\Users\Guo Li-Wei\ngrok\ngrok.exe" version
```

---

## 4. 首次設定 authtoken（現在 ngrok 強制要登入）

ngrok 現在免費版也要求綁定帳號，第一次用要設 authtoken，只需做一次：

1. 到 https://dashboard.ngrok.com/signup 註冊免費帳號。
2. 登入後在 https://dashboard.ngrok.com/get-started/your-authtoken 複製你的 authtoken。
3. 執行（把 `<你的token>` 換成實際字串）：

   ```powershell
   ngrok config add-authtoken <你的token>
   ```

這會把 token 寫進 ngrok 的設定檔，之後開通道就不用再輸入。

---

## 5. 兩種啟動方式

### 方式一：手動跑（單次測試最簡單）

```powershell
ngrok http 8080
```

跑起來後，視窗會顯示一段像這樣的網址：

```
Forwarding   https://abc123.ngrok-free.app -> http://localhost:8080
```

那段 `https://abc123.ngrok-free.app` 就是你的公網網址，傳給別人、或自己用手機外網開都可以。
`Ctrl+C` 就關掉通道（本機的 Caddy 不受影響，繼續跑）。

### 方式二：整合進 `start-all-services.bat`（每次啟動順便問要不要開）

`start-all-services.bat` 最後會問：

```
Do you want to expose the app to the public internet with ngrok? (y/n):
```

答 `y` 時，它會去讀 `NGROK_PATH` 這個變數、自動開一個新視窗跑 `ngrok http 8080`。
但這個變數要你自己設在**機器專屬的本地設定檔**裡（不進版控，每台機器各自設）：

1. 把範本複製成實際設定檔：

   ```powershell
   Copy-Item start-config.local.bat.example start-config.local.bat
   ```

2. 編輯 `start-config.local.bat`，把最後那行取消註解、填成 `ngrok.exe` 所在的**資料夾**（不含檔名）：

   ```bat
   set NGROK_PATH=C:\Users\Guo Li-Wei\ngrok
   ```

   > 如果你是用 `winget` 裝的，`ngrok.exe` 通常在
   > `C:\Users\Guo Li-Wei\AppData\Local\Microsoft\WinGet\Links\` 或它的套件資料夾下，
   > 用 `(Get-Command ngrok).Source` 查實際路徑，取它的所在資料夾填進去。

3. 重跑 `start-all-services.bat`，這次答 `y` 就會自動開 ngrok 視窗，裡面顯示公網網址。

> `start-config.local.bat` 已列入 `.gitignore`，不會被 commit，也不會帶到別台機器——每台機器各自建自己的。

---

## 6. 免費版的限制（不是設定問題，別白花時間查）

- **網址每次重開會變**：免費版每次重啟 ngrok（或連續跑約 2 小時後）都會換一段新的隨機網址。要固定網址得升級付費方案，或用付費的 reserved domain。
- **首次訪問有一個警告頁**：免費版的 `ngrok-free.app` 網址，訪客第一次進去會先看到 ngrok 的「You are about to visit...」提示頁，按一下 Visit Site 才進得去。這是免費版的行為，正常。
- **同時只能開一條通道**：免費版單一 authtoken 同時只能有一個 agent session。

---

## 7. 疑難排解

| 症狀 | 原因 / 解法 |
|------|-------------|
| 答 `y` 卻出現 `[SKIPPED] NGROK_PATH is not set` | 還沒建 `start-config.local.bat` 或沒設 `NGROK_PATH`，見第 5 節方式二。 |
| ngrok 視窗閃一下就關 / 說找不到 `ngrok.exe` | `NGROK_PATH` 指到的資料夾裡沒有 `ngrok.exe`，或路徑打錯。用 `(Get-Command ngrok).Source` 查實際位置。 |
| ngrok 說 `authentication failed` | 還沒跑第 4 節的 `ngrok config add-authtoken`。 |
| 公網網址打開整站壞掉 / 一直轉圈 | 幾乎都是「轉發錯 port」。確認是 `ngrok http 8080`（Caddy），不是 5173/5175 等裸 port。 |
| 本機 8080 自己就不通 | 先修本機，ngrok 只公開本機能動的東西。回頭看 `start-all-services.bat` 有沒有把 Caddy 起來。 |

---

## 8. 安全提醒

ngrok 是把你本機的服務**真的公開到公網**，任何拿到那段網址的人都連得進來。

- 這個平台目前是開發階段，沒有針對公網暴露做完整的防護（rate limiting、防爆破等）。
- 只在需要 demo / 讓特定的人測試時才開，用完就 `Ctrl+C` 關掉通道。
- 別把 ngrok 網址貼到公開場合（論壇、社群），免得被不特定人士連進來。

---

## 附錄：相關檔案

- [start-all-services.bat](start-all-services.bat)：ngrok 那段在最後（會問 y/n、讀 `NGROK_PATH`、跑 `ngrok http 8080`）。
- [start-config.local.bat.example](start-config.local.bat.example)：機器專屬設定範本，複製成 `start-config.local.bat` 後填 `NGROK_PATH`。
- [deploy/Caddyfile](deploy/Caddyfile)：Caddy 的路由規則（8080 如何分流到各服務）。
- [部署除錯測試.md](部署除錯測試.md)：整個環境從零建置、除錯、測試的完整過程紀錄。
