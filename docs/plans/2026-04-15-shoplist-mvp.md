# shoplist MVP

## 概要・やりたいこと
iOS で使える買い物リストアプリを作る。データは Cloudflare Workers + D1 に持ち、iOS アプリはそのクライアント。将来的にはアレクサ経由でのアイテム追加も見据えるが、今回は API + iOS アプリ + ウィジェットの MVP を完成させる。

## 前提・わかっていること
- 技術スタック・構成は todo-app（~/todo-app）を踏襲する
  - バックエンド: Hono + Cloudflare Workers + D1 (SQLite)
  - iOS: SwiftUI + WidgetKit、XcodeGen でプロジェクト生成
  - モノレポ: npm workspaces で API / iOS / shared を管理
  - 認証: Bearer トークンのみ（個人利用）
  - スクリプト: generate-projects.sh 等を流用
- macOS アプリは不要
- データモデル: `id, name, purchased, position, purchased_at, created_at, updated_at`
- 購入済みアイテムは `purchased_at` から12時間後に自動で非表示
- 並び替え: drag & drop（position フィールド）
- ウィジェット: 未購入アイテム一覧を表示、タップでアプリを起動
- アイテムのフィールドは `name` のみ（数量・メモは将来追加）
- デプロイ: 別 Worker + 別 D1 データベース、todo-app とは完全に独立
- iOS はローカルビルドで自分の iPhone にインストール（ストア不要）
- デザイン: DESIGN.md（Apple HIG 準拠、SwiftUI ネイティブ）を正とする。iOS 実装時は必ず参照

## 実装計画

### 事前準備 [人間👨‍💻]
- [x] Cloudflare ダッシュボードで D1 データベース「shoplist-db」を作成し、database_id を控える

### Phase 1: プロジェクト基盤 [AI🤖]
- [x] モノレポ構成のセットアップ（package.json, npm workspaces, .mise.toml）
- [x] todo-app から共通スクリプト（generate-projects.sh 等）を移植・調整
- [x] shared パッケージに型定義を作成（Item, ItemsResponse, CreateItemRequest, UpdateItemRequest, ReorderRequest）
- [x] .gitignore, .env.example 等の設定ファイルを配置

### Phase 2: API [AI🤖]
- [x] Hono アプリの雛形作成（wrangler.toml, src/index.ts）
- [x] D1 マイグレーション作成（items テーブル）
- [x] API エンドポイント実装
  - `GET /items` — 未購入 + 購入後12時間以内のアイテムを返す
  - `POST /items` — アイテム追加（name のみ、position 自動割り当て）
  - `PATCH /items/:id` — 更新（name, purchased, position）
  - `DELETE /items/:id` — 削除
  - `PATCH /items` — 一括並び替え（reorder）
- [x] Bearer トークン認証ミドルウェア
- [x] テスト（Vitest + miniflare）

### Phase 2 の確認 [AI🤖]
- [x] curl で全エンドポイントの動作確認

### Phase 3: iOS アプリ [AI🤖]
- [x] project.yml 作成（XcodeGen 定義、Widget Extension 含む）
- [x] データモデル（Item.swift, Codable）
- [x] APIClient（Actor ベースのネットワーククライアント）
- [x] ItemViewModel（@Observable、CRUD + reorder + 自動リフレッシュ）
- [x] メイン画面 UI
  - アイテム一覧（未購入が上、購入済みが下）
  - 追加フォーム
  - スワイプで購入済みトグル
  - drag & drop で並び替え
  - タップで編集・削除
- [x] DESIGN.md 準拠（システムカラー、SF Symbols、.insetGrouped List）

### Phase 4: ウィジェット [AI🤖]
- [x] TimelineProvider 実装（未購入アイテム取得）
- [x] ウィジェット UI（未購入アイテム一覧）
- [x] WidgetAPIClient（Widget 用の軽量 API クライアント）
- [x] アプリ側で変更時に `WidgetCenter.shared.reloadAllTimelines()` 呼び出し

### Phase 4 の確認 [人間👨‍💻]
- [x] Xcode でビルドし iPhone にインストール
- [ ] アイテムの追加・編集・削除・購入済みトグル・並び替えの動作確認
- [ ] ウィジェットの表示確認
- [ ] 購入済みアイテムが12時間後に非表示になることの確認（API レベルで確認済み）

### Phase 5: デプロイ [AI🤖 + 人間👨‍💻]
- [x] [AI🤖] wrangler.toml に本番 D1 の database_id を設定
- [x] [AI🤖] マイグレーション適用コマンドを用意
- [x] [人間👨‍💻] `npx wrangler deploy` で本番デプロイ
- [x] [人間👨‍💻] 本番 API に対して iOS アプリで動作確認（実機で動作確認済み）

## ログ
### 試したこと・わかったこと
- デプロイ直後は error code 1042 (Worker not found) が返った。DNS 反映に数分かかる模様。再デプロイ後に解消

### 方針変更
（実装中に随時追記）
