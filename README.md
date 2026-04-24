# NoMacMusic

macOS のメディアキー（Play/Pause, Next, Prev、および Bluetooth イヤホンの同等ボタン）を
押しても `Music.app` が起動しないようにし、代わりに任意のアプリ（Spotify, Apple Music,
Apple TV, VLC, Swinsian, Vox など）を操作できるようにするスタンドアロンアプリ。

上部メニューバーに常駐しつつ、Dock からも設定ウィンドウを開ける。
仕様の詳細は [SPEC.md](./SPEC.md) を参照。

## 動作環境

- macOS 14 (Sonoma) 以降
- Apple Silicon / Intel

## インストール

### ワンライナー（おすすめ）

Xcode Command Line Tools (`xcode-select --install`) が入っている環境で:

```sh
curl -fsSL https://raw.githubusercontent.com/masseater/no-mac-music/main/scripts/install.sh | bash
```

`/Applications/NoMacMusic.app` に配置されて自動起動する。

### 手動ビルド

```sh
git clone https://github.com/masseater/no-mac-music.git
cd no-mac-music
./scripts/build-app.sh
open dist/NoMacMusic.app
```

開発中にソースだけ素早く通したいときは `swift build`。

## 権限付与

初回起動時に macOS からダイアログが出る（Accessibility と Input Monitoring の 2 つ）。
出ない場合は

- **System Settings > Privacy & Security > Accessibility**
- **System Settings > Privacy & Security > Input Monitoring**

を開き、`NoMacMusic.app` を追加して ON にする。メニューバー／設定画面 (`⌘,`) の
Permissions タブから遷移できる。

両方の権限が無いと CGEventTap を HID 層で張れないため、メディアキー由来の `Music.app`
起動抑止や他アプリへの転送は動かない。`Kill Music.app on Launch` は `NSWorkspace`
監視のみで動くので権限なしでも機能する。

## 使い方

### メニューバー

上部の `nosign` アイコンをクリックすると

- Enabled（メディアキー横取りの ON/OFF）
- Target App（操作対象）
- Kill Music.app on Launch
- Launch at Login
- Show Main Window / Preferences… / Quit

が並ぶ。

### ターゲットアプリ

インストール済みのアプリだけが選択肢に出る（`NSWorkspace.urlForApplication` で判定）。
AppleScript 辞書を持つアプリはプリセットで対応:

- Spotify / Apple Music / Apple TV / VLC / Swinsian / Vox

それ以外のアプリは Settings → Apps → `+` → **Choose App…** で `.app` を選ぶとバンドル
情報と AppleScript 雛形が自動入力される。AppleScript 辞書を持たないアプリ
（TIDAL, IINA, Apple Podcasts など）は `tell application "System Events" to keystroke " "`
のような GUI スクリプトを自分で書き込めば動く。

## 実装メモ

- HID 層で `CGEventTap` を張り (`.cghidEventTap` + `.headInsertEventTap`)、`systemDefined`
  (type=14) の subtype 8 イベントから Play / Next / Previous を検出・消費する。消費する
  ため rcd / MediaRemote が `Music.app` を起動する前に握り潰せる。
- 検出したコマンドは `TargetAppController` (＝ `AppleScriptController`) で選択中の
  `TargetAppConfig` の 3 スクリプトへ渡す。
- `NSWorkspace.didLaunchApplicationNotification` 購読 + `com.apple.Music` 起動検知 →
  `terminate()` のフォールバックあり。
- ログイン項目は macOS 13+ の `SMAppService.mainApp` を利用。
- UI は SwiftUI の `WindowGroup` + `Settings` シーン。メニューバーは `NSStatusItem`
  を `StatusItemController` が管理して `AppCore` の `@Published` と同期。
