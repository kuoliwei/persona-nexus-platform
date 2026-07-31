# 前情提要：character-service 程式碼層面優化

## 這是什麼

前兩個聊天室完成了 **auth-service** 和 **user-service** 的程式碼層面優化（commit 635bd4a、a86455e）。本聊天室應接續針對 **character-service** 進行相同的流程：現況掃描 → 設計規劃 → 實施驗證 → 收尾記錄。

---

## 背景脈絡

### 已完成的工作

- ✅ **《程式撰寫設計原則.md》**（根目錄）— 六大維度的通用程式碼設計原則（Phase 1 新建）
- ✅ **auth-service 完整優化**（commit 635bd4a）
  - 補完 JSDoc、簡化註解、統一錯誤格式
  - 測試全通過（14/14）
  - OpenSpec change `auth-service-code-quality` 已歸檔
  
- ✅ **user-service 完整優化**（commit a86455e）
  - 補完 JSDoc、新增區段註解、改進日誌
  - 品質優於 auth-service（低嚴重度項少 40%）
  - OpenSpec change `user-service-code-quality` 已歸檔

### 本輪目標

對 **character-service** 進行相同的程式碼稽核和優化：
1. **稽核**現有代碼（用《程式撰寫設計原則.md》六大維度）
2. **設計**優化方案（OpenSpec change）
3. **實施**改動
4. **驗證**測試通過
5. **提交**并記錄

---

## Character-Service 概況

### 職責
AI 角色 CRUD（建立/編輯/刪除角色、角色搜尋、角色詳情查詢等）

### 技術棧
- Node.js + Express 5
- Prisma 7 + SQLite
- 三層架構（controller/service/repository）
- 無 TypeScript、無 ESLint 設定、無單元測試

### 文件結構
```
character-service/src/
  ├── app.js
  ├── controllers/       # HTTP 層
  ├── services/         # 業務邏輯層
  ├── repositories/     # 資料存取層
  └── lib/             # 工具（prisma 等）
```

### 程式碼量預估
- 預計代碼量：150-200 行（與 user-service 相近）
- 複雜度：中等（CRUD + 搜尋邏輯）

---

## 預期的工作流程

### Phase 1：現況掃描（15-30 分鐘）

用《程式撰寫設計原則.md》逐條掃描代碼，找違反點：

**檢查清單**：
- [ ] 檔案長度是否超過 800 行，職責是否清晰？
- [ ] 函數是否有完整的 JSDoc（@param、@returns、@throws）？
- [ ] 錯誤處理是否集中化（ERROR_MAP）？
- [ ] 是否有過度詳細的「做什麼」型註解？
- [ ] 重複代碼是否應該抽象？
- [ ] 變數命名是否清楚（不用 data、result、tmp 等泛稱）？

**產出物**：
- `character-service/mistake.md`：記錄所有違反項（🔴 高、🟡 中、🟢 低、📋 建議 四個等級）

### Phase 2：設計與規劃（20-30 分鐘）

建立 OpenSpec change（仿 auth-service / user-service 的模式）：

```bash
openspec new change "character-service-code-quality"
# 建立 4 個 artifacts：
# - proposal.md      — 為什麼做、改什麼、影響範圍
# - specs/*.md       — 新 capability 的詳細需求（若有）
# - design.md        — 技術決策、風險、遷移計畫
# - tasks.md         — 實施步驟（預計 10-15 個）
```

**預期改動範圍**（基於 auth-service / user-service 規模）：
- JSDoc 補完（service/repository/controller 方法）
- 註解簡化（catch 區塊、過度詳細解釋）
- 錯誤格式統一（如適用）
- 可能的拆檔（如果某個檔案職責過多）

### Phase 3：實施與驗證（30-40 分鐘）

執行 OpenSpec tasks：

```bash
/opsx:apply character-service-code-quality
```

**預期檢查點**：
- npm test 通過（或確認無測試配置）
- 手動驗證關鍵端點（CRUD 操作）
- 語法檢查通過
- git commit 成功

### Phase 4：收尾與記錄（5-10 分鐘）

- 更新 mistake.md 的稽核記錄
- 記錄長期記憶
- 歸檔 OpenSpec change
- 準備下一個服務的前情提要

---

## 關鍵決策與原則

### 資料格式改動必謹慎

**教訓**（來自 auth-service / user-service）：
- ✅ 改「JSDoc 文件」（純補充）
- ✅ 改「內部註解風格」（可讀性增強）
- ✅ 改「錯誤碼映射」（業務層決策）
- ❌ 改「API 回應結構」（需要跨應用協調）

### 不過度設計

**原則**（來自 user-service 經驗）：
- 如果改動簡單（補文件、簡化註解），直接改
- 內部檢查重複 3 次是邊界（按三次法則，不值得抽象）
- 但**多個改動合併為一個 OpenSpec change** 有利於追蹤

### 測試過時風險

**教訓**（來自 auth-service）：
- 改代碼時要檢查對應的測試是否需要同步
- character-service 無單元測試，所以無此風險
- 但要做好手動驗證（CRUD 端點測試）

---

## 使用說明

**下一個聊天室應該**：

1. **讀這份前情提要**，理解背景和工作流程
2. **讀《程式撰寫設計原則.md》**（根目錄），熟悉六大維度
3. **讀 auth-service/mistake.md 和 user-service/mistake.md**，了解稽核報告的格式
4. **掃描 character-service 程式碼**，用稽核清單逐檔檢查
5. **記錄違反項**到 `character-service/mistake.md`
6. **與我討論優先度與範圍**（哪些改動該做、哪些留給後續）
7. **建立 OpenSpec change**，驅動實施流程
8. **執行改動並驗證**，提交 git commit
9. **更新長期記憶**，為下一個聊天室準備

---

## 預期工時

| 階段 | 估計 | 備註 |
|------|------|------|
| Phase 1：稽核掃描 | 20-30 分鐘 | 取決於 character-service 代碼量 |
| Phase 2：設計規劃 | 20-30 分鐘 | 建立 OpenSpec change |
| Phase 3：實施驗證 | 30-40 分鐘 | 含手動驗證 |
| Phase 4：收尾 | 5-10 分鐘 | 記憶更新 + 歸檔 |
| **總計** | **75-110 分鐘** | 預計 1-2 小時 |

---

## 後續三個微服務

完成 character-service 優化後，還有三個微服務待優化：

1. **chat-service**（埠 6000）— 最複雜，conversationService.js 1081 行
2. **ai-service**（埠 6001）— Python + FastAPI
3. **api-gateway**（埠 8000）

每個服務的流程相同，預計總耗時 **6-8 小時**（全部服務，包括已完成的 auth/user）。

---

## 記住

- **程式碼品質優化** 與 **功能開發** 不同：改文件、簡化、統一，無業務改動
- **用《程式撰寫設計原則.md》驅動**：六大維度檢查清單，確保一致性
- **用 OpenSpec 驅動**：保持流程一致，方便後續追蹤和對比
- **記錄違反項**：mistake.md 是重要的知識庫，未來 code review 時會引用
- **與既有服務對齊**：參考 auth-service、user-service 的優化成果，保持風格一致

---

## 成功案例參考

### auth-service（commit 635bd4a）
- ✅ JSDoc 補完（authService / userRepository）
- ✅ 註解簡化（catch 區塊 over-detailed 註解）
- ✅ 錯誤格式統一（ERROR_MAP）
- ✅ 死代碼清除（authMiddleware、verifyToken、me、users.json）
- ✅ 測試全通過（14/14）
- 時間：2 小時

### user-service（commit a86455e）
- ✅ JSDoc 補完（userService × 4 方法、userRepository × 4 方法）
- ✅ 區段註解新增（職責清晰化）
- ✅ 日誌改進（NODE_ENV 條件式）
- ✅ 代碼質量優於 auth-service
- ✅ 無測試配置（預期）
- 時間：50 分（少 60%）

**character-service 預期效果**：與 user-service 相近（簡潔、高效）

---

祝下一個聊天室順利！🚀

如有任何疑問，參考已歸檔的 OpenSpec changes：
- `openspec/archives/2026-07-30-auth-service-code-quality/`
- `openspec/archives/2026-07-30-user-service-code-quality/`
