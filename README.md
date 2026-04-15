# Shoplist

シンプルな買い物リストアプリ。iOS ネイティブアプリ + Cloudflare Workers API のモノレポ構成。

## 構成

```
apps/
  api/     Hono + Cloudflare Workers + D1 (REST API)
  ios/     SwiftUI iOS アプリ + ウィジェット
packages/
  shared/  共通の型定義 (TypeScript)
```

## 技術スタック

**API:** Hono / Cloudflare Workers / D1 (SQLite) / Vitest

**iOS:** SwiftUI / Swift Concurrency / WidgetKit

## セットアップ

### API

```sh
npm install
cd apps/api
npx wrangler dev          # ローカル開発
npx wrangler deploy       # デプロイ
```

### iOS

[XcodeGen](https://github.com/yonaskolb/XcodeGen) + `project.yml` でプロジェクトを生成:

```sh
cd apps/ios
cp .env.example .env      # API_URL と API_SECRET を設定
bash ../../scripts/generate-projects.sh
open Shoplist.xcodeproj
```
