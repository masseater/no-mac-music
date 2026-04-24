# no-mac-music SPEC

## 概要

macOSでキーボードのメディアキー（Play/Pause, Next, Prev）を押したときに、
Apple純正の `Music.app` が勝手に起動するのを止める。
さらに、メディアキー押下時にユーザーが選んだ任意のアプリ（例: Spotify）を
既定で操作できるようにする。

## 背景・動機

- Bluetoothイヤホンのボタンや、キーボード上段のPlay/Pauseキーを押しただけで
  `Music.app` が立ち上がるのが不快。
- この挙動は macOS の `com.apple.rcd`（Remote Control Daemon）によって
  提供されている。
- `Music.app` 自体は `/System/Applications/Music.app` にあり、SIP下では
  通常の手段では削除できない。

## ゴール

1. メディアキー押下時に `Music.app` が起動しない。
2. メディアキー押下時に、ユーザーが指定した別アプリ（以後「ターゲットアプリ」）の
   再生/停止/次/前を操作できる。
3. 設定（有効/無効、ターゲットアプリ、挙動）を切り替えられる。
4. ログイン時に自動で有効になる。

## 非ゴール

- `Music.app` のバイナリ自体を物理削除する（SIPを無効化させない）。
  → ユーザーから見て「起動しない」状態にできれば十分とみなす。
- iOS / iPadOS 対応。
- `Music.app` の機能代替（ライブラリ管理・再生UIなど）の提供。
- 純正以外のメディアキー動作（輝度・音量キー等）への介入。

## 制約・前提

- macOS のバージョンにより `com.apple.rcd` の扱いが変わる。
  最新版（Sonoma / Sequoia 以降）でも動くアプローチを採用する。
- SIP (System Integrity Protection) は有効のままにする。
- Apple Silicon / Intel の両方で動くことが望ましい。
- Accessibility / Input Monitoring などの権限付与が必要になる可能性がある。

## アプローチ候補

| # | 方式 | 概要 | Musicアプリ停止 | 別アプリ起動 | 副作用 |
|---|------|------|----------------|------------|--------|
| A | `launchctl` で `com.apple.rcd` を unload | 古典的手法 | ○ | × | OS更新で戻る / 他のメディア制御も壊れる |
| B | 既存OSS (noTunes 等) を採用 | `Music.app` 起動検知→即kill | ○ | △ (別途ツール必要) | ドラスティックにkillする |
| C | メディアキーをイベントフックする独自常駐アプリを作る | `CGEventTap` でメディアキーを奪ってターゲットアプリへ転送。必要に応じて `Music.app` 起動も抑止 | ○ | ○ | 権限付与が必要 |
| D | `Music.app` をユーザー領域に差し替え / リネーム | 起動経路を潰す | ○ | × | SIPと衝突しやすい / 副作用大 |

## 採用方針（初期案）

**C（独自常駐アプリ）を第一候補**とする。理由:

- ゴール1（Music抑止）とゴール2（別アプリ操作）を単一プロセスで達成できる。
- SIPを触らない。
- 設定でターゲットアプリを差し替えられる。

ただしゴール1だけを単体で満たしたいユーザー向けに、
B（`Music.app` 起動検知→kill）相当のフォールバックを併設する。

### 最小構成（MVP）

1. メディアキー (F7/F8/F9、Play/Pause/Next/Prev) の `CGEventTap` を張る。
2. イベントを消費して純正処理に渡さない（= `Music.app` は起動しない）。
3. 代わりに、設定されたターゲットアプリに対応する操作を送る。
   - Spotify: AppleScript (`tell application "Spotify" to playpause` 等)
   - 汎用: `MediaRemote` 経由で任意プレイヤーに送る方式も検討。
4. 念のため `Music.app` の起動を `NSWorkspace` で監視し、
   `didLaunchApplicationNotification` を受け取ったら即 terminate。
5. ログイン項目として登録し、ステータスバーから ON/OFF 切替。

### 設定項目

- 有効/無効
- ターゲットアプリ（Spotify / その他 / なし）
- `Music.app` 自動killの ON/OFF
- ログイン時自動起動の ON/OFF

## 動作環境（想定）

- macOS 14 (Sonoma) 以降
- Apple Silicon / Intel 両対応
- 権限: Accessibility, Input Monitoring, (必要なら) Automation

## 実装スタック（未決）

以下から選定する:

- Swift + SwiftUI のメニューバー常駐アプリ（第一候補）
- Rust + `core-graphics` crate 等（クロスプラットフォームを意識する場合）

初版は Swift で進める想定。後続のSPECで確定させる。

## 検証方法

- Play/Pause キー押下で `Music.app` が起動しないこと。
- Play/Pause キー押下でターゲットアプリ（例: Spotify）が再生/停止すること。
- Next/Prev キーでターゲットアプリが曲送り/戻しすること。
- ターゲットアプリが起動していない場合の挙動（起動する / 無視する）が
  設定通りに動くこと。
- 常駐アプリを終了すると通常のメディアキー挙動（Music.app 起動）に戻ること。
- 再ログイン後も自動で有効になること。

## 参考

- `com.apple.rcd` / `rcd` の挙動
- OSS: `tombonez/noTunes`, `BeardedSpice`, `SkipTunes`
- Apple Developer: `CGEventTap`, `NSWorkspace`, `MediaRemote` (private)

## 未決事項 / TODO

- 実装言語の確定（Swift を前提に次SPEC）。
- MediaRemote private frameworkに依存するか、アプリ個別に AppleScript を使うか。
- 配布形態（自ビルド / 署名付き .app / Homebrew Cask）。
- `Music.app` の "kill on launch" をデフォルト有効にするか。
