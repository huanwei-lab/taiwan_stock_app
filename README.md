# 台股飆股分析（stock_checker）

Flutter 專案，提供台股候選篩選、風險提示、診斷與追蹤。

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
