# 動作確認手順

## iOS アプリの UI（スワイプ・入力欄）

`apps/ios/UITests/ShoplistUITests.swift` の XCUITest で、シミュレータ上の操作を自動で確認する。
合成マウス（CGEvent）でシミュレータの画面を触る方法は、ユーザーの操作と衝突するので使わない。

**本番の API に向けないこと**（テストは毎回データを全件消して入れ直す）。Debug ビルドは環境変数 `SHOPLIST_API_URL` / `SHOPLIST_API_SECRET` で API の向き先を差し替えられるので、ローカルの API に向ける。

```sh
# 1. ローカル API（D1 は使い捨てのディレクトリに置く）
cd apps/api
npx wrangler d1 migrations apply shoplist-db --local --persist-to /tmp/shoplist-d1
npx wrangler dev --local --persist-to /tmp/shoplist-d1 --port 8787 --var API_SECRET:local-test

# 2. 通信の遅延を再現する中継（8788 → 8787、0.8 秒遅延。キーボードのテストが使う）
python3 scripts/slow-proxy.py

# 3. UI テスト
cd apps/ios
bash ../../scripts/generate-projects.sh
xcodebuild -project Shoplist.xcodeproj -scheme Shoplist \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test > /tmp/uitest.log 2>&1
grep -E "RESULT|Test Case .*(passed|failed)|\*\* TEST" /tmp/uitest.log
```

- シミュレータのソフトウェアキーボードを出すため、事前に `defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false` にしておく
- `RESULT ...` の行に実測値（購入状態・並び順・フォーカスのサンプル数など）が出る
- キーボードのテストは、遅延の中継を通さないと、通信を待ってから再フォーカスする実装でも通ってしまう（通信が速すぎて差が出ない）。**2 を省かない**
- Xcode 27 では Simulator.app が `Xcode.app/Contents/Applications/DeviceHub.app` に置き換わっている
- `xcrun simctl io booted screenshot` は、複数のシミュレータが起動していると別の端末を撮る。UDID を指定する
- 下の入力欄の幅は`testAddFieldSpansWidth`で見る（`RESULT add-field row=… idle=… focused=…`。入力欄がリストの行の7割を超えていれば合格）。入力欄をツールバー（`.bottomBar`）に置いていたころ、iOS 27で111ptに縮んだ（ツールバーの項目の幅はOSが決める。いまは`safeAreaInset`で自前に置いている）。**新しいiOSが出たらそのランタイムで回す**
- iOS 27のシミュレータは`xcodebuild -downloadPlatform iOS`で入る。**iOS 27.1のランタイムはiPhone Duo専用**で、iPhone Air・17 Pro等は27.0のランタイムが要る（2026-10-22時点）。iPhone Duoは画面の右側がセーフエリアの外なので、幅はウィンドウでなくリストの行と比べる
