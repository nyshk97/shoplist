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
  -destination 'platform=iOS Simulator,name=iPhone Duo' test > /tmp/uitest.log 2>&1
grep -E "RESULT|Test Case .*(passed|failed)|\*\* TEST" /tmp/uitest.log
```

- シミュレータのソフトウェアキーボードを出すため、事前に `defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false` にしておく
- `RESULT ...` の行に実測値（購入状態・並び順・フォーカスのサンプル数など）が出る
- キーボードのテストは、遅延の中継を通さないと、通信を待ってから再フォーカスする実装でも通ってしまう（通信が速すぎて差が出ない）。**2 を省かない**
- Xcode 27 では Simulator.app が `Xcode.app/Contents/Applications/DeviceHub.app` に置き換わっている
- `xcrun simctl io booted screenshot` は、複数のシミュレータが起動していると別の端末を撮る。UDID を指定する。iPhone Duo は画面が 2 枚（閉じた画面・開いた画面）あるので `--display=primary`（閉じた画面）も付ける
- 下の入力欄の幅は`testAddFieldSpansWidth`で見る（`RESULT add-field row=… idle=… focused=…`。入力欄がリストの行の7割を超えていれば合格）。入力欄をツールバー（`.bottomBar`）に置いていたころ、iOS 27で111ptに縮んだ（ツールバーの項目の幅はOSが決める。いまは`safeAreaInset`で自前に置いている）。**新しいiOSが出たらそのランタイムで回す**
- iOS 27のシミュレータは`xcodebuild -downloadPlatform iOS`で入る。**iOS 27.1のランタイムはiPhone Duo専用**で、iPhone Air・17 Pro等は27.0のランタイムが要る（2026-10-22時点）。2026-11-21のminiでは27.2も、Duo専用（24B91016s）とそれ以外（24B8117）の2つ。UIテストの既定はDuo（自分のスマホ）で、2026-11-21に9件とも通った。iPhone Duoは画面の右側がセーフエリアの外なので、幅はウィンドウでなくリストの行と比べる

## ウィジェット（実機）

ウィジェットは実機の画面を撮って見る。iPadは「今日の表示」（ホームの1枚目を右へスワイプ）に置いてある。

```sh
mise run ios:device iPad   # iPhoneなら iPhone
xcrun devicectl list devices   # 撮る端末のUDIDを見る
xcrun devicectl device capture screenshot --device <UDID> --destination /tmp/widget.png
```

- 入れてからウィジェットが描き直されるまで20秒ほど待つ。`ios:device`はアプリを前に出すので、ホームに戻って今日の表示を出す操作は、miniのDevice Hubの「View Screen」に映した画面をドラッグする（終わったらDevice Hubを終了する）
- **ウィジェットで使う画像は、表示する大きさに合わせる**。ヘッダーのアイコンに1024×1024（1x）の画像を使っていたとき、iPad miniだけ、灰色の棒が並ぶ仮の表示のまま変わらなかった（iPhone Duoでは出ていた。2026-11-25）。入れ直しても直らず、画像を28ptの1x・2x・3x（28・56・84px）に替えただけで出た。ウィジェットは描いた結果を保存するときに画像の大きさの上限があり、超えると黙って仮の表示のままになる（上限は端末で違う）。エラーの文も出ないので、仮の表示のまま変わらないときは先に画像の大きさを見る: `xcrun --sdk iphoneos assetutil --info <.appの中の>/PlugIns/ShoplistWidgetExtension.appex/Assets.car`の`PixelWidth`
