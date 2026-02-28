# 台股飆股分析（stock_checker）

Flutter 專案，提供台股候選篩選、風險提示、診斷與追蹤。

## 最新優化（2026-02）

- 盤中成交值正規化：早盤會以交易時段進度估算「全日等效成交值」，降低早盤因成交值尚未累積造成的漏抓。
- 每日候選快照：每日保存核心候選、前20候選、強勢候選，支援回看驗證。
- 上週飆股回看：可輸入多檔代號，檢查最近區間是否曾被前一天抓到。
- 命中率三份 CSV 匯出：`predictions.csv`、`outcomes.csv`、`context.csv`。
- 每週命中率摘要：在 App 內直接看最近 7 天強勢/觀察訊號表現。
- 命中率自動調參建議：依最近 30 天結果產生 2~3 組建議，並可一鍵套用。
- 篩選器增強：
  - 允許為成交量、漲跌%、股價距離、籌碼集中度、成交值設定權重
  - 新增籌碼集中度過濾與主力誘多偵測選項
  - 分數會依盤勢/類股輪動調整（弱勢板塊扣分）
  - 提供 A/B 策略設定比較工具（使用 compareFilterStates 函數）

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
## Google 備份設定教學

### 1. Google Cloud Console 設定

#### 一鍵產生 SHA-1 指令

在專案根目錄（有 android 資料夾）執行：

Windows Powershell：
```
keytool -list -v -keystore .\android\app\debug.keystore -alias androiddebugkey -storepass android -keypass android | Select-String "SHA1"
```
Mac/Linux Terminal：
```
keytool -list -v -keystore ./android/app/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep SHA1
```

複製 SHA-1 到 Google Cloud Console 建立 Android OAuth Client。

#### Android OAuth Client 設定步驟

1. 前往 https://console.cloud.google.com/
2. 建立專案（如：taiwan_stock_app）。
3. 啟用 Google Drive API。
4. 左側「API 與服務」→「憑證」→「建立憑證」→「OAuth 用戶端 ID」。
5. 選擇「Android」，套件名稱填 `com.example.stock_checker`。
6. SHA-1 填上剛剛取得的值。
7. 完成後複製 Client ID，備份不用填到程式，Google Sign-In 會自動偵測。

### 2. OAuth 同意畫面

#### Google OAuth 同意畫面設定教學

1. Google Cloud Console 左側選單「API 與服務」→「OAuth 同意畫面」。
2. 選「外部」類型（大多數 App 用戶都選這個）。
3. 填寫：
	- App 名稱：隨意（如「台股飆股分析」）。
	- 使用者支援電子郵件：你的 Google 帳號。
	- 開發者聯絡資訊：同上。
4. 範圍（Scopes）：預設即可，Drive API 會自動加上。
5. 測試使用者（Test users）：
	- 必須加上你要登入的 Google 帳號（否則測試模式下會被拒絕登入）。
6. 儲存並送出。

#### Android OAuth Client 設定教學

1. Google Cloud Console 左側選單「API 與服務」→「憑證」。
2. 點「建立憑證」→「OAuth 用戶端 ID」。
3. 選「Android」。
4. 填寫：
	- 套件名稱（Package name）：`com.example.stock_checker`（需與專案一致）。
	- SHA-1：用 README 指令取得。
5. 建立後，Client ID 會自動生效，程式不需手動填入。
6. 若更換 keystore 或打包機器，記得重新取得 SHA-1 並更新。

### 3. 手機端操作
1. App 右上角雲朵圖示「Google 備份」→「連接 Google」→「立即備份」。
2. 成功會顯示「已備份到 Google（你的信箱）」。
3. 新手機安裝同 App，按「雲端還原」即可。
4. 「每日自動備份」建議打開（開啟 App 更新時觸發）。

### 4. 常見錯誤對照表
| 錯誤訊息 | 可能原因 | 解法 |
|---|---|---|
| DEVELOPER_ERROR | SHA-1 不符、OAuth Client 未建立 | 重新建立 Android OAuth Client，確認 SHA-1 正確 |
| 登入失敗：origin_mismatch | Web Client ID 未設 localhost/127.0.0.1 | OAuth Web Client 設定 Authorized origins |
| 登入被拒 | OAuth 同意畫面未完成、帳號未加到 Test users | 完成同意畫面、加入測試帳號 |
| Google 雲端尚無備份檔 | 尚未備份過 | 先執行「立即備份」 |

---
