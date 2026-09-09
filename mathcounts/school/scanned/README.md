# Scanned PDF 掃描結果

本資料夾由 [PDF Ingest API](https://github.com/erwin071/kbis-par/blob/main/docs/pdf-ingest-api.md) 掃描 `../` 內的 mathcounts School Round PDF 產生。

每個檔案一個子資料夾：

- `ingest.json` — PDF metadata、文字層（textPages）、OCR、imageCandidates
- `page-NNN.png` — 每頁渲染圖（dpi=150）
- `figures/page-NNN-figure-MMM.png` — 偵測到的 embedded image 裁圖