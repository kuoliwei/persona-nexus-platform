# 用 Cloudflare Tunnel 把服務公開到公網教學

> 這份教學針對 Persona Nexus 的**同源部署架構**（Caddy 反向代理 + 相對路徑前端）量身寫。
> 2026-07-29 從 ngrok 換過來的：ngrok 被 Windows Defender 標記為 Trojan/PUA 隔離掉，
> 且新版本持續被重新標記（[官方已知問題](https://learn.microsoft.com/en-us/answers/questions/3870084/)，
> 非個案），排除項加了也沒用。詳見 [ngrok公開服務教學.md](ngrok公開服務教學.md) 第 8 節補記。
>
> 以下所有指令都在這台機器上**實際跑過並驗證成功**，不是抄官方文件的猜測版本。

---

## 0. 核心觀念：兩種 Tunnel，先搞懂差異

Cloudflare Tunnel 有兩種模式，**選錯會卡很久**（今天就卡在這裡）：

| | Quick Tunnel | 具名 Tunnel（Named / Remote-managed） |
|---|---|---|
| 要不要帳號 | ❌ 不用 | ✅ 要 |
| 要不要網域 | ❌ 不用 | ✅ **要，而且要 Cloudflare 管該網域的 DNS** |
| 網址 | 隨機，`https://xxx.trycloudflare.com`，每次重啟會變 | 固定，你自己指定的 hostname |
| 啟動方式 | 一行指令 | dashboard 建 tunnel + 設定 Public Hostname |
| 適合場景 | 偶爾 demo、跟 ngrok 免費版同等定位 | 長期公開、需要固定網址 |

**卡關的根本原因**：具名 Tunnel 的 dashboard 頁面有個「Add route → Published application → Select domain」表單，那個 **Domain 下拉選單只會列出「已加入 Cloudflare 帳號、且 DNS 交給 Cloudflare 管」的網域**。空帳號（沒買網域、也沒把任何網域轉入 Cloudflare）進去那個下拉永遠是反灰的空白——**這不是付費限制，是「帳號裡有沒有網域」這個先決條件沒滿足**，跟 ngrok 的免費/付費方案是兩回事。

只要你的目的是「偶爾開給人看」，**直接跳到第 2 節用 Quick Tunnel**，不用管具名 Tunnel。

---

## 1. 前置條件

1. 本機 `http://localhost:8080` 能正常運作（Caddy + 所有服務都起來）
2. 完全不需要 Cloudflare 帳號（Quick Tunnel 這條路不用登入）

---

## 2. 安裝 cloudflared

### 用 winget 安裝

```powershell
winget install Cloudflare.cloudflared
```

### 開一個全新的 PowerShell 視窗

**這步不能跳過**——裝完 PATH 不會馬上在目前視窗生效，必須開新視窗（跟 ngrok 一樣的坑）。

### 驗證安裝

在新視窗跑（**用完整路徑**，即使開新視窗 `cloudflared` 這個指令有時仍抓不到，用完整路徑最保險）：

```powershell
& "C:\Program Files (x86)\cloudflared\cloudflared.exe" --version
```

**預期**：印出版本號，例如 `cloudflared version 2026.7.3`

> 這台機器實測：`cloudflared.exe` 裝在 `C:\Program Files (x86)\cloudflared\`（winget 版）。

---

## 3. 開通道（Quick Tunnel，實測可用）

```powershell
& "C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel --url http://localhost:8080
```

**實際輸出範例**：

```
INF Requesting new quick Tunnel on trycloudflare.com...
+--------------------------------------------------------------------------------------------+
|  Your quick Tunnel has been created! Visit it at (it may take some time to be reachable):  |
|  https://ccd-loose-necessity-weed.trycloudflare.com                                        |
+--------------------------------------------------------------------------------------------+
```

那段 `https://xxx.trycloudflare.com` 就是公網網址。**這個視窗要一直開著**，`Ctrl+C` 關閉通道（本機 8080 不受影響，繼續跑）。

跑起來後會看到一堆 `Registered tunnel connection` 的連線建立訊息，以及一段 `CONNECTIVITY PRE-CHECKS` 健檢表，全部 `PASS` 代表環境正常。

### 驗證

用**手機關掉 wifi、走 4G/5G** 打開那段網址，能看到平台首頁（大廳）就成功。用同一個 wifi 測不準，可能是走內網通的。

---

## 4. 具名 Tunnel + 固定網址（需要自己的網域，本次未完成，先記錄卡點）

如果之後想要固定網址，流程是：

1. 買一個網域（Porkbun、Namecheap 等，一年約 US$10 內），或用免費子網域服務（例如 `dpdns.org`）申請一個免費子網域
2. 把該網域加進 Cloudflare 帳號，並將其 NS 記錄指向 Cloudflare（讓 Cloudflare 接管 DNS）
3. 這樣做完，dashboard → Tunnels → 建 tunnel → Routes → Add route → Published application 裡的「Select domain」下拉才會有東西可選
4. 選好網域、填 hostname、Service 選 HTTP、URL 填 `http://localhost:8080`，Add route
5. 用 dashboard 給的 token 啟動：
   ```powershell
   & "C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel run --token <token>
   ```

> ⚠️ `cloudflared tunnel route dns <name> <hostname>` 這個 CLI 指令**對具名/token 型 tunnel 無效**——實測會報錯
> `Error locating origin cert: client didn't specify origincert path`，因為它要找本機登入產生的 `cert.pem`，
> 是給「本地管理 tunnel」（`cloudflared login` 那條路）用的指令，跟 dashboard 建的 token 型 tunnel 是兩套機制，不能混用。
> 要幫具名 tunnel 加路由，只能透過 dashboard 的 Routes 頁面（前提是網域已加好）。

---

## 5. 常見問題（今天實際踩過的坑）

| 症狀 | 原因 / 解法 |
|------|-------------|
| `cloudflared` 說找不到指令 | PATH 還沒更新。開新 PowerShell 視窗；還是不行就用完整路徑 `C:\Program Files (x86)\cloudflared\cloudflared.exe`。 |
| `tunnel --config xxx.yml run` 說 `unknown flag: -config` | `--config` 要放在 `tunnel` 這層，不是 `run` 這層：正確是 `cloudflared tunnel --config xxx.yml run`，不是 `cloudflared tunnel run --config xxx.yml`。 |
| 跑 `tunnel --config ... run` 報 `Cannot determine default origin certificate path` / `Error locating origin cert` | 用了本地設定檔語法，但這個 tunnel 是 dashboard 建的 token 型（遠端管理），沒有本機 `cert.pem`。改用 `tunnel run --token <token>` 這個指令，不要用 `--config` 檔案。 |
| Dashboard 的「Add route」表單，Domain 下拉一直反灰選不了 | 帳號裡沒有任何網域。這不是付費限制，是先決條件沒滿足——要嘛用第 3 節的 Quick Tunnel（不需要網域），要嘛先把網域加進帳號（見第 4 節）。 |
| `tunnel route dns <name> <hostname>` 報 `Error locating origin cert` | 這個指令只認本地登入（`cloudflared login`）產生的憑證，對 token 型 tunnel 無效。具名 tunnel 的路由只能走 dashboard 設定。 |
| 通道開起來了但網址打不開 | 確認本機 `http://localhost:8080` 能正常訪問；Cloudflare 只會把通暢的服務原樣公開，不會修好本機的問題。 |
| Quick Tunnel 網址每次都變 | 這是設計行為，不是 bug。要固定網址得走第 4 節具名 tunnel + 自己的網域。 |
| 訪客打開網址看到 **Cloudflare Error 1033** | Tunnel 連線暫時斷線中，還沒重連上。看開通道那個視窗的 log，若持續出現 `timeout: no recent network activity` 反覆斷線重連（[已知的 QUIC/UDP 問題](https://github.com/cloudflare/cloudflared/issues/1085)，常見於防火牆干擾 UDP 流量的網路），改用 HTTP/2 協定啟動：`cloudflared tunnel --protocol http2 --url http://localhost:8080`，走一般 TCP/443 比較不受防火牆影響。啟動後多等 30 秒讓連線穩定再測試。 |

---

## 6. 停止通道

在開通道的 PowerShell 視窗按 `Ctrl+C`。本機 8080 不受影響，繼續跑。

---

## 7. 安全提醒

跟 ngrok 一樣，這把你的服務**真的公開到公網**。

- 平台目前是開發階段，沒有針對公網暴露做完整防護（rate limiting、防爆破等）
- 只在需要 demo / 讓特定的人測試時才開，用完就 `Ctrl+C` 關掉
- 別把 URL 貼到公開場合（論壇、社群）
- Quick Tunnel 官方條款：無 uptime 保證，僅供實驗/測試用途，正式使用需改用具名 tunnel（見官方 Terms of Use）

---

## 附錄：相關檔案

- [ngrok公開服務教學.md](ngrok公開服務教學.md)：舊方案，因 Windows Defender 持續誤判而棄用，保留供對照
- [INSTALLATION.md](INSTALLATION.md)：新機器部署教學，第 10 節公網暴露可改參照本文件
- [MICROSERVICES.md](MICROSERVICES.md#L105)：公網暴露那段仍寫的是 ngrok，待更新
