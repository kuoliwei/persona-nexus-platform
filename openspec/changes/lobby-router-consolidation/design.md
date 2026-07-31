## Context

`persona-nexus-lobby` 目前有兩種互相矛盾的「頁面渲染函式該不該管 history」慣例並存：
- `chat-page.js`／`character-create.js`／`character-edit.js` 三個 loader **自己管**（各自內部判斷是否要 `pushState`/`replaceState`，並各寫一套「避免 popstate 觸發時重複推送造成無窮迴圈」的防呆條件）
- `home.js`／`my-character.js` 兩個 loader **不自己管**（`home.js` 的註解明確寫出「歷史狀態由呼叫端負責」），history 管理落在呼叫端：`main.js` 的 `restoreRouteFromUrl()`／`popstate` 監聽器、`sidebar.js` 的按鈕事件

稽核找到 7 個直接觸發導航的呼叫點（`sidebar.js` 3 處、`home.js` 1 處、`my-character.js` 3 處），全部用「動態 `import()` 對應模組 + 呼叫其渲染函式」的寫法，且各自要知道該不該再手動 `pushState`——這知識目前分散在呼叫端與被呼叫端之間，沒有單一權威來源。

## Goals / Non-Goals

**Goals:**
- 用一張路由表（`router.js` 內的 `routes` 陣列）取代目前分散在 5+ 個檔案的路徑↔頁面↔渲染函式對照關係
- 讓「渲染」與「history 讀寫」完全分離：所有頁面 loader 只負責渲染，`router.js` 是唯一寫 `history` 的地方
- 消除三個 loader 各自持有的「避免 popstate 無窮迴圈」防呆邏輯——設計上直接讓 popstate 處理路徑不寫 history，這類防呆會變得不必要（見 Decisions）
- 統一 7 個觸發點的呼叫慣例：一律呼叫 `router.navigateTo(path)`，不再各自動態 import 頁面模組

**Non-Goals:**
- 不改變任何路徑格式（`/`、`/my-characters`、`/my-characters/create`、`/my-characters/edit?id=`、`/rooms/:id`）
- 不引入路由框架（YAGNI，5 條路由不需要）
- 不處理 `persona-nexus-chat` 或其他前端專案（已在 `chat-frontend-code-quality` change 獨立處理）
- 不修正任何既有功能性 bug，僅解決路由知識重複與管理慣例不一致的問題

## Decisions

### 1. 路由表用陣列 + `match(pathname, searchParams)` 函式，不用字串樣板比對
```js
const routes = [
  { page: 'home', match: (pathname) => pathname === '/' ? {} : null, render: async () => {...} },
  { page: 'myCharacters', match: (pathname) => pathname === '/my-characters' ? {} : null, render: async () => {...} },
  { page: 'create', match: (pathname) => pathname === '/my-characters/create' ? {} : null, render: async () => {...} },
  { page: 'edit', match: (pathname, search) => {
      if (pathname !== '/my-characters/edit') return null;
      const id = search.get('id');
      return id ? { characterId: id } : undefined; // undefined = 已知路徑但缺參數
    }, render: async ({ characterId }) => {...} },
  { page: 'chat', match: (pathname) => {
      const m = pathname.match(/^\/rooms\/(.+)$/);
      return m ? { characterId: decodeURIComponent(m[1]) } : null;
    }, render: async ({ characterId }) => {...} },
];
```
`match()` 回傳三種值：`null`（不符合）、`undefined`（路徑符合但缺必要參數——對應原本 `/my-characters/edit` 缺 `id` 的特殊分支）、或參數物件（符合）。這個三態設計讓「已知但缺參數」與「完全不認得的路徑」可以用同一個迴圈處理，同時保留原本兩種情況分別的錯誤訊息行為。

### 2. 「渲染」與「history 寫入」徹底分離，是解掉無窮迴圈防呆的根本方法
原本 `character-edit.js`／`character-create.js`／`chat-page.js` 都需要防呆邏輯（`if (options.replace || history.state?.page !== 'edit' || ...)`），根因是這些函式**同時**被兩種情境呼叫：(a) 使用者主動點擊觸發，需要 `pushState`；(b) `popstate` 事件觸發時重新渲染，此時絕對不能再 `pushState`（否則會把瀏覽器已經處理好的 history stack 又推一筆，造成上一頁/下一頁行為錯亂甚至迴圈）。

新設計讓 `render()` 函式**永遠不寫 history**，只有 `router.navigateTo()`（使用者主動導航）與 `router.restoreFromUrl()`（頁面載入時）會寫 history，而 `popstate` 處理路徑只呼叫 `render()`、完全不碰 history（瀏覽器已經處理好了）。三個模組原本的防呆判斷因此整段消失，不是「移到 router.js」，而是「這個問題不再存在」。

### 3. `navigateTo(path)` 內建去重檢查，取代原本三份各自寫的判斷
```js
async function navigateTo(path) {
  const url = new URL(path, location.origin);
  const matched = matchRoute(url.pathname, url.searchParams);
  if (!matched) return; // 不認得的路徑，navigateTo 只接受呼叫端已知合法的路徑
  const { route, params } = matched;
  if (history.state?.page === route.page && shallowEqual(history.state?.params, params)) {
    return; // 已經在這個狀態，不重複渲染、不重複推送
  }
  await route.render(params);
  history.pushState({ page: route.page, params }, '', path);
}
```
去重檢查集中一處，取代原本 `character-edit.js`（比對 `page` + `characterId` 兩個條件）、`character-create.js`（比對 `page`）、`chat-page.js`（比對 `page` + `characterId`）三份各自寫的邏輯。

### 4. `restoreFromUrl()` 與 `popstate` handler 共用同一個內部 `renderForLocation()`
兩者都是「依目前網址渲染對應頁面」，差別只在於要不要寫 history（`restoreFromUrl` 用 `replaceState`，`popstate` 完全不寫）。抽出共用的 `renderForLocation(pathname, searchParams)` 避免同一份路由比對邏輯又出現第三份。

### 5. 移除 `main.js` 的 debug 代碼
`window.history.pushState`/`replaceState` 的 monkey-patch 與 `window.historyLog` 陣列不屬於任何現有職責（YAGNI），且集中式的 `router.js` 讓「一個地方看懂所有導航」的除錯需求本身就被滿足了，不再需要額外的偵錯儀器。使用者已確認直接移除。

## Risks / Trade-offs

- **[風險] 7 個觸發點呼叫方式全部要改，範圍比 chat.js 拆分更廣** → 緩解：每個觸發點的改動是機械式的（`import X + 呼叫` → `router.navigateTo(path)`），逐一修改後個別驗證對應的導航路徑
- **[風險] `/my-characters/edit` 缺 `id` 參數的錯誤訊息時機（原本要等 `loadHomePage()` 渲染完、抓到子頁插座才顯示）容易在重構時弄錯順序** → 緩解：`renderForLocation()` 內的 fallback 分支照搬原本「先渲染首頁、再呼叫 `showMessage`」的順序，不重新設計這段
- **[取捨] 路由表用陣列線性掃描而非查找表（Map）** → 可接受：只有 5 條路由，線性掃描的效能差異可忽略，陣列讓 `match()` 函式可以寫成任意複雜的比對邏輯（如正則、query 參數檢查），比純字串 key 的 Map 更彈性

## Migration Plan

依序進行，每步驟後 `npm run build` 確認打包成功：
1. 建立 `router.js`，先只實作路由表 + `renderForLocation()` + `restoreFromUrl()`，不動其他檔案
2. 把 `main.js` 的 `restoreRouteFromUrl()` 呼叫換成 `router.restoreFromUrl()`，移除原本的函式定義與 debug 代碼；驗證 F5 重新整理在 5 個路徑都正確還原
3. `router.js` 加上 `popstate` 監聽（呼叫 `renderForLocation()`，不寫 history），移除 `main.js` 原本的 popstate if/else 鏈；驗證瀏覽器上一頁/下一頁
4. `router.js` 加上 `navigateTo()`；依序改 7 個觸發點（`sidebar.js` 3 處、`home.js` 1 處、`my-character.js` 3 處）為呼叫 `router.navigateTo()`
5. 移除 `chat-page.js`／`character-create.js`／`character-edit.js` 內部的 history 管理程式碼，只保留純渲染邏輯
6. 全流程回歸驗證（見 tasks.md）

無需 rollback 策略——純前端內部重構，不涉及資料庫或已部署契約。

## Open Questions

無——設計已涵蓋所有既知的呼叫點與邊界情況（`/my-characters/edit` 缺參數、popstate 迴圈防呆的根本消除）。
