## Context

character-service 已通過架構層稽核（commit 日期：2026-07-25），消除了結構性缺陷（死代碼、錯誤映射分散、CORS 多餘設定）。現在進行**程式碼層精化**——補完文件、簡化註解、加強可讀性。

參考先例：auth-service（2026-07-30）和 user-service（2026-07-30）已完成同級別的代碼層優化，標準已確立。本輪複用同一套做法，確保全平台風格一致。

**當前狀況：**
- characterService 的 5 個方法（create/update/get/list/delete）無 JSDoc
- characterRepository 的 6 個方法無 JSDoc
- characterService.js 無區段註解（8 個方法：3 個 helper + 5 個 service 方法）
- listCharacters 的註解過長（4 行解釋做什麼，不是為什麼）

**約束：**
- 無單元測試配置（預期），只需語法檢查
- 無業務邏輯改動，純文件補完
- 與 auth-service / user-service 風格保持一致

## Goals / Non-Goals

**Goals:**
1. ✅ 補完 characterService 與 characterRepository 的 JSDoc（@param、@returns、@throws）
2. ✅ 加區段註解到 characterService.js，快速導航三個職責區段
3. ✅ 簡化 listCharacters 的過長註解（移除詳細邏輯解釋，保留「為什麼」）
4. ✅ 確保代碼層品質與 user-service 對齐（目標：⭐⭐⭐⭐⭐）

**Non-Goals:**
- 不拆檔（職責分離已清晰，無必要拆分）
- 不改業務邏輯（純文件補完）
- 不引入型別系統（留給後續的 TypeScript 遷移）
- 不添加單元測試（character-service 無測試配置）

## Decisions

### 1. JSDoc 標籤集合（@param、@returns、@throws）

**決策：** 每個 public 方法補完三種標籤。

**例：**
```javascript
/**
 * 建立新角色
 * @param {string} authorId - 角色作者 ID
 * @param {Object} characterData - 角色資料 {name, introduction, ...}
 * @returns {Promise<Character>} 已建立的角色物件
 * @throws {Error} 'UNAUTHORIZED' 若 authorId 缺失
 * @throws {Error} 'CHARACTER_NOT_FOUND' 若不存在
 */
async createCharacter(authorId, characterData) { ... }
```

**為什麼：** 
- Service 層方法被 controller 直接調用，缺文件會讓呼叫方無法快速了解邊界
- Repository 層方法被 service 調用，明確回傳值邊界（null vs exception）防止誤用
- 與 auth-service / user-service 同一套標準

**替代方案考慮：**
- ❌ TypeScript：超出本輪範圍，留給後續遷移
- ✅ JSDoc：成本低、效果好、符合現有風格

### 2. 區段註解標準

**決策：** 用 `// ========== 職責名稱 ==========` 分割職責。

**位置：**
- characterService.js 最頂部：三個區段（Helpers → 驗證 → CRUD 操作）

**格式（參考 user-service）：**
```javascript
// ========== Helpers（序列化/反序列化/ID生成） ==========
function generateCharacterId() { ... }
function serializeCharacter(character) { ... }
function deserializeCharacter(character) { ... }

// ========== 驗證 ==========
function validateCreateInput(authorId, characterData) { ... }

// ========== CRUD 操作 ==========
async createCharacter(authorId, characterData) { ... }
// ... 其他 4 個方法
```

**為什麼：**
- 新人上手時能 30 秒內掌握檔案全貌
- 與 user-service 一致

### 3. 註解簡化原則

**決策：** 移除「詳細解釋做什麼」的註解，保留「為什麼」。

**例（簡化前）：**
```javascript
} else if (requesterId) {
    // 場景 3：不帶 authorId/visibility，只憑登入者身份查詢——
    // 回傳「自己的所有角色（含 private）」聯集「所有 public 角色（不限作者）」。
    // public 角色對所有人可見，不需要排除自己，兩個集合天然可能重疊（自己的 public 角色），
    // 用 Map（依 id 為 key）去重即可。
```

**簡化後：**
```javascript
} else if (requesterId) {
    // 登入者看到自己的所有角色（含 private）+ 所有公開角色
    // 用 Map 去重（自己的 public 角色可能重疊）
```

**為什麼：** 代碼本身已清楚表達「做什麼」，過長註解反而干擾可讀性。

## Risks / Trade-offs

| 風險 | 概率 | 影響 | 緩解 |
|------|------|------|------|
| JSDoc 與實現脫離 | 中 | 維護者被誤導 | 新增/改動方法時同步更新 JSDoc；code review 時檢查 |
| 區段註解位置偏差 | 低 | 導航失效 | 區段只用在 characterService.js（單一職責），不跨檔 |
| 註解簡化過度 | 低 | 遺漏必要說明 | 保留「為什麼」級別的註解（業務邏輯、設計意圖） |

---

## 預期工時

| 階段 | 工作 | 時間 |
|------|------|------|
| 1 | characterService JSDoc（5 個方法） | 8 分 |
| 2 | characterRepository JSDoc（6 個方法） | 7 分 |
| 3 | characterService.js 區段註解 | 3 分 |
| 4 | 簡化 listCharacters 註解 | 2 分 |
| 5 | 驗證 + git commit | 5 分 |
| **總計** | | **25 分** |

---

## 無可開放問題

本輪設計清晰，無待決策項。實施可直接進行。
