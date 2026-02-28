# 台股飆股分析（stock_checker）

Flutter 專案，提供台股候選篩選、風險提示、診斷與追蹤。

## 最新優化（2026-02）

- 盤中成交值正規化：早盤會以交易時段進度估算「全日等效成交值」，降低早盤因成交值尚未累積造成的漏抓。
- 每日候選快照：每日保存核心候選、前20候選、強勢候選，支援回看驗證。
- 上週飆股回看：可輸入多檔代號，檢查最近區間是否曾被前一天抓到。
- 命中率三份 CSV 匯出：`predictions.csv`、`outcomes.csv`、`context.csv`。
- 每週命中率摘要：在 App 內直接看最近 7 天強勢/觀察訊號表現。
- 命中率自動調參建議：依最近 30 天結果產生 2~3 組建議，並可一鍵套用。

## 本機開發

- 安裝相依套件：`flutter pub get`
- 啟動：`flutter run`
- 測試：`flutter test`

## 產出 APK（給 Android 手機）

- 建置指令：`flutter build apk --release`
- 產物路徑：`build/app/outputs/flutter-apk/app-release.apk`

### 安裝到其他手機

- 將 `app-release.apk` 傳到手機（LINE/雲端/USB 均可）。
- 在手機開啟 APK，依系統提示允許「安裝未知來源應用程式」。
- 首次安裝完成後，即可直接使用。

## 給其他 Windows 電腦執行（桌面版）

- 建置指令：`flutter build windows --release`
- 產物目錄：`build/windows/x64/runner/Release/`
- 將整個 `Release` 資料夾打包給其他電腦（不要只傳 `.exe`）。

> 若建置時出現 symlink/developer mode 提示，先執行：
> `start ms-settings:developers`
> 並在 Windows 開啟 Developer Mode。

## GitHub 推送 SOP

### 首次初始化（已做過可略過）

```bash
git init
git add .
git commit -m "init"
```

### 設定遠端

```bash
git remote add origin https://github.com/<your-account>/<your-repo>.git
```

### 推送

```bash
git push -u origin master
```

若出現 `please complete authentication in your browser...`：

- 到瀏覽器完成 GitHub 登入授權。
- 回到終端再執行一次 `git push -u origin master`。

## 注意事項

- 本專案已設定 `.gitignore`，會忽略 build 與平台 generated 檔。
- 若要重新產出乾淨版本，可先刪除 `build/` 再重新建置。

## 命中率資料匯出（給 Copilot 優化）

App 內路徑：`篩選診斷 -> 匯出命中率 CSV`

自動調參路徑：`每週命中率摘要 -> 命中率自動調參建議`

- 會提供三份 CSV（複製到剪貼簿）：
	- `predictions.csv`：每日候選與信號（rank/score/core/top20/strong）
	- `outcomes.csv`：訊號後 1/3/5 日報酬追蹤
	- `context.csv`：當日盤勢與參數指紋（breadth/news risk/mode/hash）
- 建議每週匯出一次（最近 30 天），貼給 Copilot 分析。

## 之後請這樣下提示詞（可直接複製）

### 1) 先做問題診斷

```text
我貼上 predictions.csv / outcomes.csv / context.csv。
請先做：
1. 強勢/觀察訊號的 1D/3D/5D 命中率與勝率分解
2. 漏抓飆股的主要原因排序（前 5 名）
3. 哪些條件太嚴、哪些條件太鬆
4. 給我「最小改動」版本的優化方案（不要大改架構）
```

### 2) 直接要求改程式

```text
根據這三份 CSV，直接修改程式提升命中率，要求：
1. 優先提升「前一天抓到飆股」的覆蓋率
2. 不能大幅增加假訊號（請同時回報勝率變化）
3. 先做最小改動，保留現有 UX
4. 修改後請跑 tests，並告訴我哪些指標改善/退步
```

### 3) 做 A/B 比較

```text
請把目前策略當 A，提出 B（僅改 2~3 個參數/規則），
輸出 A/B 差異、預期影響、風險，然後直接實作 B。
```
