# Shoplist

A simple shopping list app. Monorepo with a native iOS app and a Cloudflare Workers API.

## Structure

```
apps/
  api/     Hono + Cloudflare Workers + D1 (REST API)
  ios/     SwiftUI iOS app + Home Screen widget
packages/
  shared/  Shared TypeScript type definitions
```

## Tech Stack

**API:** Hono / Cloudflare Workers / D1 (SQLite) / Vitest

**iOS:** SwiftUI / Swift Concurrency / WidgetKit

## Setup

### API

```sh
npm install
cd apps/api
npx wrangler dev          # Local development
npx wrangler deploy       # Deploy to production
```

### iOS

Uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) with `project.yml` to generate the Xcode project:

```sh
cd apps/ios
cp .env.example .env      # Set API_URL and API_SECRET
bash ../../scripts/generate-projects.sh
open Shoplist.xcodeproj
```
