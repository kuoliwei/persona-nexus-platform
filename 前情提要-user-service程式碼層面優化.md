# 前情提要：user-service 程式碼層面優化

## 這是什麼

上一個聊天室完成了 **auth-service 程式碼層面優化**（稽核 → 設計 → 實施 → 測試 → 提交）。本聊天室應接續針對 **user-service** 進行相同的流程。

---

## 背景脈絡

### 已完成的工作
- ✅ **《程式撰寫設計原則.md》**（根目錄）建立完成——六大維度的通用程式碼設計原則
- ✅ **auth-service 完整優化**（OpenSpec change `auth-service-code-quality`）
  - 補完 JSDoc（authService/userRepository 方法）
  - 簡化內部註解（catch 區塊）
  - 統一錯誤回應格式（validateMiddleware）
  - 測試全通過（14/14）
  - 提交成功（commit 635bd4a）

### 本輪目標
對 **user-service** 進行相同的程式碼稽核和優化：
1. **稽核**現有代碼（用《程式撰寫設計原則.md》六大維度）
2. **設計**優化方案（OpenSpec change：proposal + design + specs + tasks）
3. **實施**改動（補完文件、簡化註解、統一格式等）
4. **驗證**測試通過
5. **提交**并記錄

---

## 已建立的工具

### 《程式撰寫設計原則.md》（根目錄）

六大維度的完整原則文件：

| 維度 | 內容 | 檢查重點 |
|------|------|---------|
| **A. 單檔案結構** | 模組邊界、內部清晰性、獨立可修改性 | 職責數量、區段註解、改動隔離 |
| **B. 函數粒度** | 職責單一性、函數長度、簽名清晰性 | 改變的理由、50-100 行閾值、JSDoc 完整 |
| **C. 資料流與狀態** | 副作用隔離、狀態透明性 | 純邏輯 vs 副作用分離、全域狀態隱性依賴 |
| **D. 錯誤處理** | 集中化、邊界清晰 | ERROR_MAP、@throws 文件、null vs exception |
| **E. 重複與抽象** | 重複判斷準則、抽象形式選擇 | 三次法則、成本評估、常數表 vs 函數 vs 策略物件 |
| **F. 可讀性** | 命名規範、註解與文件 | 動詞+名詞、不用 handle/process、為什麼 vs 做什麼 |

### auth-service/mistake.md（參考）

既有的稽核報告（同時包含架構層和程式碼層違反項），可作為 user-service 稽核報告的參考格式。

---

## 預期的工作流程

### Phase 1：現況掃描（15-30 分鐘）

用《程式撰寫設計原則.md》逐條掃描 user-service 的所有程式碼：

**文件結構**：
```
user-service/src/
  ├── app.js
  ├── controllers/        # HTTP 層
  ├── services/          # 業務邏輯層
  ├── repositories/      # 資料存取層
  ├── schemas/           # 驗證 schema
  ├── middlewares/       # 中介軟體
  └── utils/             # 工具函數
```

**檢查清單**（基於 auth-service 經驗）：
- [ ] 檔案長度是否超過 800 行，職責是否清晰？
- [ ] 函數是否有完整的 JSDoc（@param、@returns、@throws）？
- [ ] 錯誤處理是否集中化（ERROR_MAP）？
- [ ] 是否有過度詳細的「做什麼」型註解？
- [ ] 重複代碼是否應該抽象？
- [ ] 變數命名是否清楚（不用 data、result、tmp 等泛稱）？

**產出物**：
- `user-service/mistake.md`：記錄所有違反項（分 🔴 高、🟡 中、🟢 低、📋 建議 四個等級）

### Phase 2：設計與規劃（30-40 分鐘）

建立 OpenSpec change（仿 auth-service 的模式）：

```bash
openspec new change "user-service-code-quality"
# 建立 4 個 artifacts：
# - proposal.md      — 為什麼做、改什麼、影響範圍
# - specs/*.md       — 新 capability 的詳細需求（Given/When/Then scenario）
# - design.md        — 技術決策、風險、遷移計畫
# - tasks.md         — 實施步驟（13 個左右）
```

**預期改動範圍**（基於 auth-service 規模）：
- JSDoc 補完（service/repository/middleware 方法）
- 註解簡化（catch 區塊、過度詳細解釋）
- 錯誤格式統一（如適用）
- 可能的拆檔（如果某個檔案職責過多）

### Phase 3：實施與驗證（30-45 分鐘）

執行 OpenSpec tasks：

```bash
/opsx:apply user-service-code-quality
```

**預期檢查點**：
- npm test 通過（確保無迴歸）
- 手動驗證關鍵端點（如適用）
- 測試檔案更新（如需要）
- git commit 成功

### Phase 4：收尾與記錄（5-10 分鐘）

- 更新 mistake.md 的稽核記錄
- 記錄長期記憶
- 準備下一個服務的前情提要

---

## 關鍵決策與原則

### 資料格式改動必謹慎

**教訓**（來自 auth-service）：
- 錯誤回應格式的改動（`{error, message}` 統一）是可以的
- 但成功回應格式的改動（資料傳輸結構）必須**全量影響所有消費方**（前端也要改）
- 如果只改 user-service 的回應格式，而 api-gateway 或前端依賴舊格式，會破裂

**原則**：
- ✅ 改「錯誤碼映射」（業務層決策）
- ✅ 改「JSDoc 文件」（純補充）
- ✅ 改「內部註解風格」（可讀性增強）
- ❌ 改「API 回應結構」（需要跨應用協調）

### 測試過時風險

**教訓**（來自 auth-service）：
- commit 45ae5f3 改了 controller 回應格式，但 test 沒同步
- 導致實施時測試失敗，需要更新期望值
- 後續稽核時要特別檢查「test 與代碼是否一致」

### 不要過度設計

**原則**（來自 grilling 決策）：
- 如果改動簡單（補文件、簡化註解），直接改
- 不是每個改動都要拆成 OpenSpec change
- 但**多個改動合併為一個 change** 有利於追蹤和審查

---

## 使用說明

**下一個聊天室應該**：

1. **讀這份前情提要**，理解背景和工作流程
2. **讀《程式撰寫設計原則.md》**（根目錄），熟悉六大維度
3. **讀 auth-service/mistake.md**，了解稽核報告的格式
4. **掃描 user-service 程式碼**，用稽核清單逐檔檢查
5. **記錄違反項**到 `user-service/mistake.md`
6. **與我討論優先度與範圍**（哪些改動該做、哪些留給後續）
7. **建立 OpenSpec change**，驅動實施流程
8. **執行改動並驗證**，提交 git commit
9. **更新長期記憶**，為下一個聊天室準備

---

## 預期工時

| 階段 | 估計 | 備註 |
|------|------|------|
| Phase 1：稽核掃描 | 20-30 分鐘 | 取決於 user-service 代碼量 |
| Phase 2：設計規劃 | 30-40 分鐘 | 建立 OpenSpec change |
| Phase 3：實施驗證 | 30-45 分鐘 | 含測試調整 |
| Phase 4：收尾 | 5-10 分鐘 | 記憶更新 |
| **總計** | **90-120 分鐘** | 含討論和決策時間 |

---

## 後續五個微服務

完成 user-service 優化後，還有四個微服務待優化：

1. **character-service**（埠 5000）
2. **chat-service**（埠 6000）— 最複雜，conversationService.js 1081 行
3. **ai-service**（埠 6001）— Python + FastAPI
4. **api-gateway**（埠 8000）

每個服務的流程相同，預計總耗時 **6-8 小時**（包括所有服務）。

---

## 記住

- **程式碼品質優化** 與 **功能開發** 不同：改文件、簡化、統一，無業務改動
- **測試很重要**：實施後務必 `npm test` 驗證
- **謹慎改 API 格式**：如果改了，要確認所有消費方都能適應
- **用 OpenSpec 驅動**：保持流程一致，方便後續追蹤和對比
- **記錄違反項**：mistake.md 是重要的知識庫，未來 code review 時會引用

祝下一個聊天室順利！🚀
