# Math Study Materials 數學學習資料

四年級 / MOEMS 類型數學練習資料庫，並收錄 MathCounts / MOEMS 官方免費題庫（ICPS 準備資源）。

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

## 題庫整合原則

- `questions.json` 保留為基礎核心題庫（core）。
- 進階來源一律標記來源，例如 `source: "mathcounts"`、`source: "moems"`。
- 題目再用 `track` 分流：
  - `core`：預設顯示
  - `advanced`：進階練習
  - `challenge`：挑戰題
- 難度建議採 1~5 級：
  - `1~2`：基礎
  - `3`：中階
  - `4~5`：進階 / 挑戰
- 預設不主動混出 `advanced` / `challenge` 題；需使用者手動切換才顯示。
- 之後新增 MOEMS 時，沿用同一套欄位，避免日後再改 schema。

## Container / PDF Ingest 開發方向

- 先把 PDF ingest worker 做成獨立 container image，之後再決定是用 `Deployment` 還是 `Job`。
- 這個 image 目標是支援：
  - PDF 讀取
  - PDF 轉文字
  - PDF 轉圖片
  - OCR（需要時）
  - 輸出 JSON + images
- `Kbis-par` 可以作為 image build repo，未來若要更名再調整。
- 之後若要在 K8s 部署，建議同一個 image 同時支援：
  - `serve`：長駐 worker / API
  - `ingest`：單次批次處理
- 目前先不強制選 `Deployment` 或 `Job`，先把 image build 起來最重要。

| 檔案 | 分類 | 說明 |
|------|------|------|
| `index.html` | 數學 | 四年級英文互動練習網頁（可篩選題型、難度、adaptive difficulty 自動升降難度、即時檢查答案；LocalStorage 自動儲存、JSON 匯出/匯入備份、錯題 Review mode（答對 1 次後移除）、固定題目 id/version、作答 history、email 回報練習成果） |
| `questions.json` | 數學 | 互動練習網站題庫（標準 JSON 格式，目前 107 題） |
| `math/week01.md` | 數學 | 第 1 週練習卷（升四年級，一天一題，含家長版答案與觀察記錄表） |
| `math/grade4-math-practice.txt` | 數學 | 四年級英文數學練習題與答案 |
| `math/us-grade4-scope-and-level-map.md` | 數學 | 美國四年級（Common Core）範圍與練習題庫各 Level 涵蓋對照（備查文件） |
| `mathcounts/` | 數學 | MathCounts 官方免費歷屆題庫（2025-2026 Chapter / State、School 樣本、Handbook 預覽）——ICPS 入學考官方建議練習來源 |
| `moems/` | 數學 | MOEMS 官方免費資源（Division E/M sample contests、2025-2026 每週一題、歷屆題彙整與解答）——ICPS 入學考官方建議練習來源 |

## 匿名使用統計

`index.html` 已內建可選的 GA4 匿名事件追蹤，預設關閉。要啟用時，在檔案中的 `ANALYTICS_MEASUREMENT_ID` 填入 Google Analytics 4 的 Measurement ID（格式為 `G-XXXXXXXXXX`），再部署 GitHub Pages。只會送出頁面瀏覽、開始練習、重新開始、答題（題號、主題、難度、是否答對）與完成練習等統計；不會送出姓名、答案內容、題目文字或 LocalStorage 進度。

之後每週新的練習卷會放進 `math/` 資料夾，例如 `math/week02.md`。
