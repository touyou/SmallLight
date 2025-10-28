# FinderOverlayDebugger

FinderOverlayDebugger (開発コード: SmallLight) は Finder 上の操作をリアルタイムに可視化する常駐ユーティリティです。モディファイアキーを押しながらカーソルをホバーすると、背後にある Finder アイテムの絶対パスを HUD 表示し、`.zip` に対しては自動的に解凍・ログ記録・復元用のステージングを行います。

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
初回起動時はシステムからアクセシビリティ許可を求められます。アプリが右下に案内を表示し、**設定を開く**ボタンから `システム設定 → プライバシーとセキュリティ → アクセシビリティ` にジャンプできます。SmallLight を有効化してからアプリに戻るとダイアログは自動的に閉じ、以降確認は抑制されます。

## 使い方

### 常駐メニュー
- メニューバーのアイコンから監視状態を切り替え、HUD を表示/非表示、フォーカスを操作できます。
- `⌘⌥H` で HUD 表示をトグル、`⌃⌥Space` で HUD を最前面にフォーカスできます。
- **環境設定を開く…** からショートカットや起動オプションを変更できます。

### Finder での操作
1. デフォルトのトリガーキー (Option) を押しながら Finder アイテムにカーソルを合わせると、透明オーバーレイ上にインジケータが表示され、HUD に絶対パスが記録されます。
2. `.zip` をホバーすると `/usr/bin/ditto` で同階層へ即時解凍され、既存フォルダがある場合は `_unpacked`, `_unpacked2`, ... のサフィックスが付きます。
3. 成功すると HUD に展開先・ステージング先のパスも併記され、監査ログにも記録されます。失敗時はデデュープが解除されるため `⌃⌥P` (Manual Resolve) で即時再実行できます。
4. HUD の Copy ボタン、あるいは `⌘C` で最新エントリのパスをクリップボードへコピーできます (Auto Copy を有効化すると自動コピー)。
5. HUD 上部にはアクセシビリティ許可のステータスが常時表示されます。未許可の場合はメニューから設定を開いて有効化してください。

### ショートカット (初期値)
- `Option` : ホバー検出トリガー
- `⌃⌥Space` : HUD にフォーカス
- `⌃⌥P` : Manual Resolve (デデュープを無視して再実行)
- `⌘⌥H` : HUD 表示トグル

### ログ / 復元
- 解凍操作は `~/Library/Application Support/SmallLight/staging/` に原本をステージングし、`~/Library/Application Support/SmallLight/logs/actions.log` へ監査ログを追記します。
- 失敗時はログとステージングを参照することで手動復旧が可能です。

## 開発メモ

- ソース構成は責務ごとに `Application`, `Coordination`, `Interaction`, `Presentation`, `Services`, `Infrastructure`, `Preferences`, `Configuration` に整理されています。
- `swift test` でユニット / 統合テスト一式を実行できます。
- ドキュメントは `docs/` にまとめています。

## 今後の TODO
- ZIP 以外のファイル種別に対するコンテキスト情報の HUD 表示拡充
- 解凍の Undo UI、ステージングとの連携強化
- アクセシビリティ許可フローの GUI 改善
