# NoMacMusic

macOS のメディアキー（Play/Pause, Next, Prev, および Bluetooth イヤホンの同等ボタン）を押しても
`Music.app` が起動しないようにし、代わりに任意のアプリ（既定では Spotify）を操作できるようにする
メニューバー常駐アプリ。

仕様の詳細は [SPEC.md](./SPEC.md) を参照。

## 動作環境

- macOS 14 (Sonoma) 以降
- Apple Silicon / Intel

## ビルド

```sh
./scripts/build-app.sh
```

`dist/NoMacMusic.app` が生成される。

開発中にソースだけ素早く通したいときは:

```sh
swift build
```

## 実行と権限付与

```sh
open dist/NoMacMusic.app
```

初回起動時に Accessibility の許可ダイアログが出る。出ない場合は

**System Settings > Privacy & Security > Accessibility**

を開き、`NoMacMusic.app` を追加して有効化する。メニューバーの `Open Accessibility Settings…`
からも遷移できる。

Accessibility 権限が付与されないと `CGEventTap` を張れないため、メディアキーの捕捉ができず
`Music.app` の起動抑制（メディアキー経由のもの）や他アプリへの転送は動かない。
`Kill Music.app on Launch` は `NSWorkspace` 監視のみで動くため権限がなくても機能する。

## メニュー項目

- **Enabled** — メディアキーのフックを ON/OFF
- **Target App** — メディアキーで操作するアプリ（Spotify / None）
- **Kill Music.app on Launch** — `Music.app` が起動した瞬間に自動で終了させる
- **Launch at Login** — ログイン時に自動起動（`SMAppService` を利用）
- **Open Accessibility Settings…** — 権限設定画面を開くショートカット
- **Quit NoMacMusic** — 終了

## 実装メモ

- `CGEventTap` を `cgSessionEventTap` + `headInsertEventTap` で張り、`systemDefined` (type=14)
  イベントのうち subtype 8 を解析してメディアキーを検出・消費する。
- 検出したコマンドは `TargetAppController` 経由で選択中のアプリへ送る。Spotify は
  `NSAppleScript` で `tell application "Spotify" to playpause` 等を発行する。
- `NSWorkspace.shared.notificationCenter` の `didLaunchApplicationNotification` を購読し、
  `com.apple.Music` の launch を検知したら `NSRunningApplication.terminate()` する。
- ログイン項目は macOS 13+ の `SMAppService.mainApp` を使う（旧 `LSSharedFileList` 不要）。
