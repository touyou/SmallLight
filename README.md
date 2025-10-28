# SmallLight

SmallLight は Finder 上の操作をリアルタイムに補助する常駐ユーティリティです。Option キーを押さなくてもインジケータがカーソルに追従し、Option を押した瞬間に Finder アイテムの解析・HUD 記録・ZIP 展開などのアクションが発火します。

## 主な機能
- 透明オーバーレイ上でカーソル位置を追跡し、Option 押下時はリスニング状態を明示。
- Finder のアクセシビリティ API を用いてホバー先の絶対パスを即時解決し、HUD に履歴として保存。
- `.zip` を検出すると `/usr/bin/ditto` により同階層へ自動展開し、ステージングディレクトリと監査ログに操作履歴を残す。
- Deduplication により同じ対象への連続トリガーを抑制しつつ、ホットキーで再実行可能。

## 配布について
App Store 配信や自動インストーラは用意していません。利用するには Git でリポジトリをクローンし、Swift Package Manager でビルドしてください。

```
git clone https://github.com/touyou/SmallLight.git
cd SmallLight
```

## セットアップ

### 必要条件
- macOS 13 (Ventura) 以降
- Xcode 15 以降 / Swift 5.9 以降
- Finder でのアクセシビリティ許可

### ビルド & 実行
```
# 依存関係は SwiftPM のみ
swift build --product SmallLight

# 開発中は `swift run` または Xcode で `SmallLightAppHost` を実行
swift run SmallLight
```
初回起動時はアクセシビリティ許可のダイアログが表示されます。アプリの案内に従い **システム設定 → プライバシーとセキュリティ → アクセシビリティ** から SmallLight を有効化してください。

### Git フック (推奨)
CI と同じ `swift format` チェックに弾かれないよう、`pre-push` フックでフォーマットを自動実行します。クローン直後に次の設定を実行してください。

```
git config core.hooksPath githooks
```

`git push` 時にフォーマッタが差分を生成すると、フックが処理を中断します。表示された差分を確認して add/commit した上で再度 push してください。`swiftlint` の詳細チェックは `mise run lint` を手動で実行してください。

## 使い方

### メニューバー
- アイコンから監視状態のオン/オフや HUD 表示切り替えを行えます。
- `⌘⌥H` で HUD を表示/非表示、`⌃⌥Space` で HUD にフォーカス、`⌃⌥P` で manual resolve を実行します。
- 環境設定画面ではショートカットや起動オプション、カーソルアセットを変更できます。

### Finder ホバー連携
1. Option を押さずにカーソルを移動すると、グレーのインジケータが現在地を示します。
2. Option を押したまま Finder アイテムにホバーすると、インジケータがリスニング状態になり Finder アイテムが解決されます。
3. 解決したパスは HUD に履歴として追記され、`⌘C` もしくは Copy ボタンでクリップボードへコピーできます (Auto Copy を有効化すると自動コピー)。
4. `.zip` の場合は同階層へ自動展開し、HUD と監査ログにステージング先・展開先を記録します。失敗時はエラーメッセージとともに再試行可能です。

### ログと復元
- ステージング: `~/Library/Application Support/SmallLight/staging/`
- 監査ログ: `~/Library/Application Support/SmallLight/logs/actions.log`
Undo を実行するとステージングされた原本から復元できます。

## 開発メモ
- モジュールは責務ごとに分離されており、`swift test` でユニット/統合/システムテストを実行できます。
- 詳細な運用や仕様は `docs/` 内のドキュメントを参照してください。

## ライセンス
本プロジェクトは [MIT License](LICENSE) の下で提供されます。
