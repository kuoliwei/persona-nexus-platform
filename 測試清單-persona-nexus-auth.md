# persona-nexus-auth 前端 API 測試清單

> 目的：驗證 `persona-nexus-auth`（登入/註冊頁）實際會發出的每一種前端→後端請求都正常運作。不開瀏覽器，改用指令模擬 `src/main.js` 裡 `fetch()` 呼叫的**完全相同的 URL、method、payload 結構**，確保測的是真前端會走的路徑，不是隨便編的請求。允許建立測試帳號，測完不用刪除。

## 依據（讀原始碼確認，不是猜的）

- `src/config-loader.js:7`：頁面載入時打 `GET http://localhost:8000/api/config`（寫死直打 gateway 裸 port，不經過 Caddy）。
- `src/main.js:46-47`：`BACKEND_REGISTER_URL` / `BACKEND_LOGIN_URL` = `${config.services.gateway}/auth/register` / `/auth/login`，`config.services.gateway` 目前解析為 `http://localhost:8080/api`（同源修復後的預設值）。
- `src/main.js:94-97`、`158-161`：register/login 的 request body 都是 `{ email, password }`，`Content-Type: application/json`。
- `src/main.js:188-193`：login 成功後導向 `${LOBBY_APP_URL}/?token=...`（不在本清單測試範圍，屬於跳頁後的行為）。
- 後端實際回應（讀 `auth-service/src/controllers/authController.js` 的 `ERROR_MAP` 與 `auth-service/src/schemas/authSchema.js`）：
  - 註冊成功：`201`，`{status:"success", message:"註冊成功！", data:{id, email}}`
  - 註冊 email 重複：`400`，`{status:"error", message:"該電子郵件已被註冊，請更換帳號。"}`
  - 註冊格式不正確（email 格式錯 or password < 6 碼）：`400`，`{status:"error", message:"EMAIL或密碼格式不正確"}`
  - 登入成功：`200`，`{status:"success", message:"登入成功！", data:{id, email, token}}`
  - 登入帳密錯誤／email 不存在：`400`，`{status:"error", message:"Email或密碼錯誤，請輸入正確的Email或密碼。"}`
  - **login 路由沒有格式驗證**（`auth-service/CLAUDE.md` 明記：只有 register 掛 `validateMiddleware`），所以登入格式不對的 email 不會被攔在「格式錯誤」，會直接走到「帳密錯誤」那條路徑。

## 執行方式注意事項（實測踩過的坑，2026-07-25）

用 PowerShell 執行下面這些案例時，有幾個會讓結果誤判的陷阱，都是實測時真的踩到才發現的：

1. **不要把 `Get-Content` 讀出來的字串直接塞進要送出的 JSON body**：`Get-Content` 回傳的字串物件會帶隱藏的 `PSPath`／`PSParentPath` 等中繼資料，一旦這個值被放進要 `ConvertTo-Json` 的物件欄位（例如 `@{email=$emailFromFile; ...}`），會把整包物件序列化進去而不是純字串，後端收到的 `email` 欄位變成一個物件，Zod 驗證當然失敗，回傳「格式不正確」——**案例 3、8 第一次測都因此得到錯誤的判定**（明明是測重複 email／密碼錯誤，卻顯示成格式錯誤）。修法：讀出來的值一定要 `[string]` 強制轉型，例如 `$email = [string](Get-Content "path.txt" -Raw)`。只用在 URL 字串插值或 Header 值不受影響，只有塞進 JSON body 才會中招。
2. **抓錯誤回應的 body 用 `$_.ErrorDetails.Message`，不要手動讀 `$_.Exception.Response.GetResponseStream()`**：這個環境的 Windows PowerShell 5.1 下，手動讀 stream 常常拿到空字串，看不到後端實際回傳的錯誤訊息文字。
3. **中文欄位要轉成 UTF-8 bytes 再送 `-Body`**：直接把字串丟給 `-Body` 中文會變亂碼，要用 `[System.Text.Encoding]::UTF8.GetBytes(...)`。

三點修好後能用的 helper 函式：
```powershell
function Req($method, $url, $token, $obj) {
  $headers = @{}
  if ($token) { $headers["Authorization"] = "Bearer $token" }
  $params = @{ Uri = $url; Method = $method; Headers = $headers; UseBasicParsing = $true; TimeoutSec = 15 }
  if ($obj) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($obj | ConvertTo-Json))
    $params["Body"] = $bytes
    $params["ContentType"] = "application/json; charset=utf-8"
  }
  try {
    $r = Invoke-WebRequest @params
    return @{ status = [int]$r.StatusCode; body = $r.Content }
  } catch {
    $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { -1 }
    return @{ status = $status; body = $_.ErrorDetails.Message }
  }
}
```

## 測試案例

| # | 情境 | 請求 | 預期結果 |
|---|---|---|---|
| 1 | 頁面載入時的設定端點 | `GET http://localhost:8000/api/config` | `200`，JSON 含 `services.gateway` 與 `frontends.*` |
| 2 | 註冊成功（新 email） | `POST {gateway}/auth/register` body `{email:"<新的測試信箱>", password:"testpass123"}` | `201`，`data.id`／`data.email` 有值 |
| 3 | 註冊重複 email | 用第 2 案例同一組 email 再註冊一次 | `400`，message 為「該電子郵件已被註冊，請更換帳號。」 |
| 4 | 註冊 email 格式錯誤 | `POST .../auth/register` body `{email:"not-an-email", password:"testpass123"}` | `400`，message 為「EMAIL或密碼格式不正確」 |
| 5 | 註冊密碼太短（<6 碼） | `POST .../auth/register` body `{email:"<新的測試信箱>", password:"123"}` | `400`，message 為「EMAIL或密碼格式不正確」 |
| 6 | 註冊缺欄位 | `POST .../auth/register` body `{email:"<新的測試信箱>"}`（沒有 password） | `400`（格式驗證失敗，走同一條錯誤路徑） |
| 7 | 登入成功 | `POST {gateway}/auth/login` body 用案例 2 建立的帳密 | `200`，`data.token` 是一組 JWT |
| 8 | 登入密碼錯誤 | `POST .../auth/login` body 用案例 2 的 email + 錯誤密碼 | `400`，message 為「Email或密碼錯誤，請輸入正確的Email或密碼。」 |
| 9 | 登入 email 不存在 | `POST .../auth/login` body `{email:"nobody-xyz@test.com", password:"whatever123"}` | `400`，message 為「Email或密碼錯誤，請輸入正確的Email或密碼。」 |
| 10 | 登入 email 格式錯誤（驗證登入不做格式檢查這個設計） | `POST .../auth/login` body `{email:"not-an-email", password:"whatever"}` | `400`，但 message 應該是「Email或密碼錯誤」（不是「格式不正確」）——用來確認 CLAUDE.md 記載的「login 不做格式驗證」這個設計現在還成立 |

## 資料庫驗證（API 回應之外，順便查底層有沒有真的落地）

`auth-service` 自己沒有資料庫，實際存使用者資料的是 `user-service`（透過內部 HTTP API 呼叫），落地在 `user-service/prisma/dev.db`（SQLite，表名 `User`，欄位 `id`／`email`／`password`）。已確認機器上有 `sqlite3` 指令列工具可以直接查，不用另外寫程式。

| # | 驗證時機 | 查詢 | 預期結果 |
|---|---|---|---|
| A | 案例 2（註冊成功）之後 | `sqlite3 user-service/prisma/dev.db "SELECT id, email, password FROM User WHERE email='<案例2的email>'"` | 剛好 1 筆；`password` 欄位是 `$2b$` 開頭的 bcrypt 雜湊值，**不是明文** `testpass123`（這是 `user-service/CLAUDE.md` 特別記載的分工：雜湊責任在 auth-service，user-service 自己不雜湊，只存呼叫端傳來的值） |
| B | 案例 3（重複 email 註冊被拒）之後 | 同一句查詢再跑一次 | 還是剛好 1 筆、`id` 跟 A 查到的完全相同——確認重複註冊真的被擋下來，資料庫沒有被插入第二筆 |

## 不在這份清單範圍內（原因）

- **登入成功後的導頁與 `localStorage` 存 token 行為**：那是瀏覽器 `window.location`／`localStorage` 的行為，指令測試模擬不到，且 `auth-service/CLAUDE.md` 上記載的「沒存 token」說法你已經提醒可能過時，之前讀原始碼 `main.js:188-193` 已經確認現在其實有做，不需要重複驗證。
- **HTML5 表單驗證**（`required`、`type="email"` 擋空白/格式）：那是瀏覽器端擋，指令測試繞過瀏覽器本來就測不到，但案例 4-6 直接測後端在「假設瀏覽器沒擋住」時是否仍會正確拒絕，涵蓋了防禦縱深這一層。

---

## 實測結果（2026-07-25）

**10/10 案例 + 2/2 資料庫驗證全數通過。** 案例 3、8 第一次執行時因為上面「執行方式注意事項」第 1 點的 bug 誤判成格式錯誤，修正測試腳本後重測，結果正確（該電子郵件已被註冊／Email或密碼錯誤）。
