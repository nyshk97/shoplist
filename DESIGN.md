# Design System — Shoplist (iOS Native)

Apple HIG に準拠した SwiftUI ネイティブデザイン。iOS 標準コンポーネントを最大限活用し、カスタム UI は最小限に抑える。

## Read First

1. このファイル（DESIGN.md）
2. Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/

## Source of Truth

- カラー: SwiftUI セマンティックカラー（システム定義を優先）
- タイポグラフィ: SwiftUI Dynamic Type（SF Pro 自動適用）
- アイコン: SF Symbols
- レイアウト: SwiftUI 標準コンポーネント（List, NavigationStack, etc.）

## Rules

- SwiftUI 標準コンポーネントで実現できるものはカスタム実装しない
- ハードコードした色・サイズは使わない。セマンティックカラーと Dynamic Type を使う
- ダークモード対応はシステムカラーに委ねる（手動分岐しない）
- SF Symbols 以外のアイコンは導入しない

---

## 1. Visual Theme

Apple リマインダーアプリに近い、クリーンでネイティブな iOS 体験。装飾を排し、コンテンツとインタラクションに集中する。

**Key Characteristics:**
- Grouped List スタイルによるセクション分け
- システムカラーによるライト/ダークモード自動対応
- アクセントカラーは iOS デフォルトブルー（`.tint(.blue)`）
- SF Symbols による一貫したアイコン体系
- 標準的なスワイプアクション、drag & drop

## 2. Color Palette

### セマンティックカラー（SwiftUI）

| 役割 | SwiftUI カラー | 用途 |
|------|---------------|------|
| 背景 | `.background` | ビュー全体の背景 |
| グループ背景 | `.systemGroupedBackground` | List の背景 |
| カード背景 | `.secondarySystemGroupedBackground` | List row の背景 |
| プライマリテキスト | `.primary` | アイテム名 |
| セカンダリテキスト | `.secondary` | 補助情報、タイムスタンプ |
| アクセント | `.blue` | インタラクティブ要素、ボタン、トグル |
| 成功 | `.green` | 購入完了のフィードバック |
| 危険 | `.red` | 削除アクション |
| 区切り線 | `.separator` | セクション間の区切り |

### カスタムカラーは作らない

システムカラーだけで構成する。ダークモード対応を手動で管理する必要がなくなる。

## 3. Typography

SwiftUI の標準テキストスタイルを使う。SF Pro は iOS で自動適用される。

| 役割 | SwiftUI スタイル | 用途 |
|------|-----------------|------|
| 画面タイトル | `.largeTitle` | NavigationStack のタイトル |
| セクション見出し | `.headline` | セクションヘッダー |
| アイテム名 | `.body` | リストアイテムのテキスト |
| 補助テキスト | `.subheadline` + `.secondary` | 購入済みの日時表示 |
| キャプション | `.caption` | 注釈、件数表示 |

### Principles
- `Font.system()` のみ使用。カスタムフォントは導入しない
- Dynamic Type に対応し、ユーザーのフォントサイズ設定を尊重する
- 購入済みアイテムは `.strikethrough()` + `.foregroundStyle(.secondary)` で視覚的に区別

## 4. Iconography (SF Symbols)

| 用途 | SF Symbol | 備考 |
|------|-----------|------|
| アイテム未購入 | `circle` | 空の丸 |
| アイテム購入済み | `checkmark.circle.fill` | 塗りつぶしの丸 + チェック |
| 追加 | `plus` | ツールバーボタン |
| 削除 | `trash` | スワイプアクション |
| 編集 | `pencil` | スワイプアクション or コンテキストメニュー |
| 並び替え | 標準のドラッグハンドル | `EditButton()` / `.onMove` |
| ウィジェット | `cart` | ウィジェットアイコン |

## 5. Component Patterns

### List
```
NavigationStack {
    List {
        Section("未購入") { ... }
        Section("購入済み") { ... }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("買い物リスト")
}
```
- `.insetGrouped` スタイルで Apple 標準の角丸カード表現
- セクション分け: 未購入（上）、購入済み（下）

### List Row（未購入アイテム）
- 左: タップ可能な `circle` アイコン（購入済みトグル）
- 中央: アイテム名（`.body`）
- 右: drag ハンドル（編集モード時）

### List Row（購入済みアイテム）
- 左: `checkmark.circle.fill`（`.green`）
- 中央: アイテム名（`.strikethrough()` + `.secondary`）
- 下: 購入日時（`.caption` + `.secondary`）

### Swipe Actions
- 右スワイプ: 購入済みトグル（`.green`、`checkmark.circle.fill`）
- 左スワイプ: 削除（`.red`、`trash`）

### 追加フォーム
- List 最下部 or ツールバーの `+` ボタンからシートで表示
- TextField + 確定ボタンのシンプルな構成
- 追加後は自動で TextField をクリア、リストの先頭にアイテム表示

### Empty State
- リストが空の場合、`ContentUnavailableView` を表示
- SF Symbol: `cart`
- メッセージ: 「アイテムがありません」

## 6. Layout Principles

### Spacing
- SwiftUI 標準の spacing を使う（明示的な数値指定は避ける）
- List のパディングはシステムデフォルトに委ねる

### Safe Area
- `.safeAreaInset` は使わない。標準の NavigationStack + toolbar で配置

### Widget Layout
- `.systemSmall`: アイテム名を 4-5 件表示
- `.systemMedium`: アイテム名を 8-10 件表示
- 未購入アイテムのみ表示。購入済みは含めない
- タップでアプリを起動（Deep Link 不要、アプリ本体を開くだけ）

## 7. Animation & Feedback

- リストの追加・削除: SwiftUI 標準の `.animation(.default)` に委ねる
- 購入済みトグル: チェックマークへの切り替えをデフォルトアニメーションで
- drag & drop: `.onMove` の標準アニメーション
- 触覚フィードバック: 購入済みトグル時に `.impact(.medium)`

## 8. Do's and Don'ts

### Do
- SwiftUI 標準コンポーネントをそのまま使う（List, NavigationStack, Section, etc.）
- セマンティックカラー（`.primary`, `.secondary`, `.background`）を使う
- SF Symbols を使う
- Dynamic Type をサポートする
- `.insetGrouped` List スタイルを使う
- スワイプアクションは `.swipeActions` modifier で実装する
- 空状態は `ContentUnavailableView` で表示する

### Don't
- ハードコードした色（`Color(red:green:blue:)`、hex 値）を使わない
- カスタムフォントやフォントサイズの直接指定をしない
- UIKit コンポーネントを SwiftUI にブリッジしない（SwiftUI だけで完結）
- 過度なカスタムアニメーションを追加しない
- NavigationStack 以外のナビゲーションパターンを使わない
- サードパーティ UI ライブラリを導入しない
