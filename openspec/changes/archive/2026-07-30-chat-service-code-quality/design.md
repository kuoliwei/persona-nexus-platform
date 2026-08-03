## Context

chat-service 已通過兩輪架構層稽核（2026-07-25 `simplify-chat-service`；2026-07-25～26 平台級《微服務架構準則》稽核，commit `b509562`），消除了結構性缺陷（ERROR_MAP 集中化、死代碼清除、跨帳號授權漏洞修正、記憶體 Map 改持久化）。現在進行**程式碼層精化**——補完文件、加強可讀性，不涉及業務邏輯或架構改動。

參考先例：auth-service、user-service、character-service（皆 2026-07-30）已完成同級別的代碼層優化，標準已確立。本輪複用同一套做法，唯規模明顯更大（conversationService.js 1069 行，是 character-service 210 行的 5 倍）。

**當前狀況：**
- conversationService 的 17 個 public 方法（controller 實際呼叫的 API 介面）幾乎全數無 JSDoc，而檔案內私有 helper 反而已有完整 JSDoc——本末倒置
- conversationRepository.js 的 13 個基礎 CRUD 方法（conversationRepository 6 + messageRepository 7）無 JSDoc
- conversationService.js 無區段註解，1069 行內至少 7 個職責平鋪，無法快速導航

**約束：**
- 無單元測試配置（僅 test.http 手動整合測試），只需語法檢查 + 健康檢查驗證
- 無業務邏輯改動，純文件補完
- 與 auth-service / user-service / character-service 風格保持一致
- **不拆檔**（見下方決策 3）

## Goals / Non-Goals

**Goals:**
1. ✅ 補完 conversationService 17 個 public 方法的 JSDoc（@param、@returns、@throws）
2. ✅ 加區段註解到 conversationService.js，快速導航 7+1 個職責區段
3. ✅ 補完 conversationRepository.js 13 個 CRUD 方法的 JSDoc
4. ✅ 確保代碼層品質與 user-service / character-service 對齊（目標：⭐⭐⭐⭐⭐）

**Non-Goals:**
- **不拆檔**（見下方決策 3 的理由）
- 不簡化既有的「為什麼」型長註解（assertConversationOwnership、tryAcquireLock、setFailed 上方的段落註解記錄了真實的歷史 bug 與設計動機，屬高品質知識資產）
- 不改業務邏輯（純文件補完）
- 不處理 console.log 氾濫（已於 2026-07-25 輪確認暫緩）
- 不處理 SOLID-DIP（已於 2026-07-25 輪確認 JS 環境下屬約定俗成，不處理）
- 不添加單元測試框架（chat-service 無測試配置，超出本輪範圍）

## Decisions

### 1. JSDoc 標籤集合（@param、@returns、@throws）

**決策：** 每個 public 方法補完三種標籤，與前三服務一致。

**例：**
```javascript
/**
 * 取得或建立與指定角色的對話（非同步 + 輪詢模式）
 * 若對話已存在直接回傳 ready；不存在則發起背景建立流程並回傳 preparing
 * @param {string} userId - 使用者 ID
 * @param {string} characterId - 角色 ID
 * @returns {Promise<Object>} { status: 'ready'|'preparing'|'failed', ... }
 * @throws {Error} 'UNAUTHORIZED' 若 userId 缺失
 * @throws {Error} 'MISSING_CHARACTER_ID' 若 characterId 缺失
 * @throws {Error} 'CHARACTER_NOT_FOUND' 若角色不存在
 */
async getOrCreateConversation(userId, characterId) { ... }
```

**為什麼：**
- Service 層方法被 controller 直接調用，缺文件會讓呼叫方無法快速了解邊界
- 目前檔案內私有 helper 反而有 JSDoc、public 方法沒有，是本末倒置，優先修正
- 與 auth-service / user-service / character-service 同一套標準

### 2. 區段註解標準

**決策：** 用 `// ========== 職責名稱 ==========` 分割職責，共 8 段。

**位置與順序（依 conversationService.js 現有方法排列順序，不調整方法位置）：**
```javascript
// ========== 私有 Helpers（摘要機制／RAG／擁有權檢查） ==========
function generateConversationId() { ... }
function validateUserId(userId) { ... }
async function assertConversationOwnership(...) { ... }
function calculateHistoryLength(...) { ... }
function checkIfNeedsSummary(...) { ... }
async function buildAIServiceRequest(...) { ... }
async function cleanupConversationRAG(...) { ... }
async function executeSummary(...) { ... }
async function _prepareAndCreateConversation(...) { ... }

export const conversationService = {
  // ========== 對話建立 ==========
  async getOrCreateConversation(...) { ... }

  // ========== 對話查詢 ==========
  async getAllConversations(...) { ... }
  async getConversationsSummary(...) { ... }

  // ========== 訊息 CRUD ==========
  async sendMessage(...) { ... }
  async sendMessageToConversation(...) { ... }
  async _generateAIResponseAsync(...) { ... }
  async getMessages(...) { ... }
  async getMessagesByConversationId(...) { ... }
  async deleteMessageAndSubsequent(...) { ... }
  async getMessageById(...) { ... }

  // ========== 對話刪除 ==========
  async deleteConversation(...) { ... }
  async deleteConversationsByCharacter(...) { ... }

  // ========== 主角人設 ==========
  async getProtagonist(...) { ... }
  async updateProtagonist(...) { ... }

  // ========== 建立重試 ==========
  async retryConversationCreation(...) { ... }

  // ========== AI 生成狀態 ==========
  async getAIGenerationStatus(...) { ... }
  async clearAIGenerationStatus(...) { ... }
};
```

**為什麼：**
- 新人上手時能 30 秒內掌握檔案全貌，緩解 1069 行的導航成本
- 只加註解、不搬動既有方法順序或程式碼——把「拆檔」的導航收益用零風險的方式先拿到一部分
- 與 user-service / character-service 一致的格式

### 3. 不拆檔（維持單一 conversationService.js）

**決策：** 本輪不將 conversationService.js 拆成多個檔案。

**為什麼：**
- chat-service 無任何測試框架（僅 test.http 手動測試），拆檔若不慎打斷共用狀態（`generationStatusRepository`、`assertConversationOwnership` 被多個方法共用）沒有自動化測試網可攔截回歸
- 2026-07-25 輪架構稽核已判定 SOLID-SRP 違反「把握度低，建議列為觀察項而非強制處理」，本輪延續此結論
- 前三服務（auth/user/character）的優化範圍皆為「補文件、簡化註解」，未涉及拆檔——維持「程式碼層優化 = 無結構改動」的平台慣例
- 使用者已在本輪稽核討論中確認此方向（見 mistake.md「拆檔決策」）

**替代方案（已否決）：** 拆成 conversationService.js + messageService.js + summaryService.js。否決理由：無測試網保護、超出本輪 60-80 分鐘工時預算、與既有慣例不符。若未來要拆，應先補測試框架再評估。

### 4. 保留既有的「為什麼」型長註解

**決策：** `assertConversationOwnership`、`tryAcquireLock`、`setFailed` 等函式上方的長段落註解維持原樣，不簡化、不刪減。

**為什麼：** 這些註解記錄了真實發生過的歷史 bug（例如 4 處跨帳號授權漏洞、回合身分競態導致的「訊息一閃消失」bug）與非顯而易見的設計動機（殭屍鎖時限計算、tempUserId 為何不能在 setFailed 清空），屬於 F2 原則定義的「必要註解」範疇，不是 character-service 稽核中發現的「做什麼」型冗詞。簡化這些註解會遺失重要的除錯知識。

## Risks / Trade-offs

| 風險 | 概率 | 影響 | 緩解 |
|------|------|------|------|
| JSDoc 與實現脫離 | 中 | 維護者被誤導 | 新增/改動方法時同步更新 JSDoc；code review 時檢查 |
| 區段註解位置偏差 | 低 | 導航失效 | 依現有方法排列順序加註解，不搬動程式碼，降低出錯機會 |
| 方法數量多（17+13=30 個），逐一補 JSDoc 耗時被低估 | 中 | 超出預期工時 | 已將預估工時上修至 60-80 分鐘（character-service 的 3 倍以上），並允許視情況分批提交 |
| 未拆檔導致 1069 行問題仍在 | 低 | 未來維護成本仍偏高 | 已用區段註解緩解導航成本；拆檔列為未來獨立工作項，待補測試框架後評估 |

---

## 預期工時

| 階段 | 工作 | 時間 |
|------|------|------|
| 1 | conversationService 17 個方法 JSDoc | 35 分 |
| 2 | conversationService.js 8 個區段註解 | 8 分 |
| 3 | conversationRepository.js 13 個方法 JSDoc | 15 分 |
| 4 | 驗證 + git commit | 10 分 |
| **總計** | | **68 分** |

---

## 無可開放問題

拆檔決策已與使用者確認（不拆），本輪設計清晰，可直接進行實施。
