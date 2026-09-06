# Math Study Materials 數學學習資料

四年級 / MOEMS 類型數學練習資料庫，並收錄 MathCounts 官方免費題庫（ICPS 準備資源）。

## 資料夾結構

```
math/          → 數學（四年級資優準備、MOEMS 類型非標準題與邏輯推理）
mathcounts/    → MathCounts 官方免費題庫（ICPS 官方建議準備來源）
  school/      → School 樣本回合（Sprint / Target / Team / 答案）+ 2020 school sprint
  chapter/     → 2025-2026 Chapter（地區）回合
  state/       → 2025-2026 State（州）回合
  handbook/    → School Handbook 免費預覽（30 題）
moems/         → MOEMS 官方免費資源（ICPS 官方建議準備來源）
  sample/      → Sample contest（Division E 四年級起 / Division M 六年級起）
  problem-of-week/ → 2025-2026 每週一題 題目+解答
  archived-problems.pdf   → 官方歷屆題彙整
  archived-solutions.pdf  → 官方歷屆題解答彙整
```

## 目前的檔案

| 檔案 | 分類 | 說明 |
|------|------|------|
| `index.html` | 數學 | 四年級英文互動練習網頁（可篩選題型、難度、adaptive difficulty 自動升降難度、即時檢查答案；LocalStorage 自動儲存、JSON 匯出/匯入備份、錯題 Review mode（答對 1 次後移除）、固定題目 id/version、作答 history、email 回報練習成果） |
| `questions.json` | 數學 | 互動練習網站題庫（標準 JSON 格式，目前 107 題） |
| `math/week01.md` | 數學 | 第 1 週練習卷（升四年級，一天一題，含家長版答案與觀察記錄表） |
| `math/grade4-math-practice.txt` | 數學 | 四年級英文數學練習題與答案 |
| `math/us-grade4-scope-and-level-map.md` | 數學 | 美國四年級（Common Core）範圍與練習題庫各 Level 涵蓋對照（備查文件） |
| `mathcounts/` | 數學 | MathCounts 官方免費歷屆題庫（2025-2026 Chapter / State、School 樣本、Handbook 預覽）——ICPS 入學考官方建議練習來源 |
| `moems/` | 數學 | MOEMS 官方免費資源（Division E/M sample contests、2025-2026 每週一題、歷屆題彙整與解答）——ICPS 入學考官方建議練習來源 |

之後每週新的練習卷會放進 `math/` 資料夾，例如 `math/week02.md`。
