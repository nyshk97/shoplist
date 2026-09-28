import XCTest

// ローカルの API（wrangler dev, API_SECRET=local-test）に向けて動かす UI テスト。
// 毎回データを消して入れ直すので本番に向けないこと。手順は VERIFY.md を参照。

private let base = "http://localhost:8787"

private struct APIItem: Decodable { let id: String; let name: String; let purchased: Bool }
private struct APIItems: Decodable { let items: [APIItem] }

private func call(_ method: String, _ path: String, _ body: [String: Any]? = nil) -> Data {
    var req = URLRequest(url: URL(string: base + path)!)
    req.httpMethod = method
    req.setValue("Bearer local-test", forHTTPHeaderField: "Authorization")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let body { req.httpBody = try! JSONSerialization.data(withJSONObject: body) }
    let sem = DispatchSemaphore(value: 0)
    var out = Data()
    URLSession.shared.dataTask(with: req) { d, _, _ in out = d ?? Data(); sem.signal() }.resume()
    sem.wait()
    return out
}

private func items() -> [APIItem] {
    (try? JSONDecoder().decode(APIItems.self, from: call("GET", "/items")).items) ?? []
}

final class ShoplistUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        for i in items() { _ = call("DELETE", "/items/\(i.id)") }
        for n in ["卵", "食パン", "バナナ", "豆腐", "トマト"] { _ = call("POST", "/items", ["name": n]) }
        if name.contains("Scroll") { for i in 1...25 { _ = call("POST", "/items", ["name": "item\(i)"]) } }
        app = XCUIApplication()
        // キーボードの検証は、通信を 0.8 秒遅らせる中継を通して実回線の遅延を再現する
        app.launchEnvironment["SHOPLIST_API_URL"] = name.contains("Keyboard") ? "http://localhost:8788" : base
        app.launchEnvironment["SHOPLIST_API_SECRET"] = "local-test"
        app.launch()
        XCTAssertTrue(app.staticTexts["卵"].waitForExistence(timeout: 10))
    }

    private func purchased(_ name: String) -> Bool? { items().first { $0.name == name }?.purchased }

    private func waitPurchased(_ name: String, _ expected: Bool, timeout: TimeInterval = 5) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if purchased(name) == expected { return true }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return false
    }

    private func drag(_ name: String, dx: CGFloat, dy: CGFloat = 0, press: TimeInterval = 0.05, hold: TimeInterval = 0.1) {
        let start = app.staticTexts[name].coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
        start.press(forDuration: press, thenDragTo: start.withOffset(CGVector(dx: dx, dy: dy)),
                    withVelocity: .slow, thenHoldForDuration: hold)
    }

    func testShortSwipeDoesNotToggle() {
        drag("卵", dx: 50)
        Thread.sleep(forTimeInterval: 1.5)
        print("RESULT short-swipe purchased=\(String(describing: purchased("卵")))")
        XCTAssertEqual(purchased("卵"), false)
    }

    func testSwipeTogglesBothWays() {
        drag("卵", dx: 140)
        XCTAssertTrue(waitPurchased("卵", true), "未購入→購入済み")
        XCTAssertTrue(app.staticTexts["購入済み"].waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1)
        drag("卵", dx: 140)
        XCTAssertTrue(waitPurchased("卵", false), "購入済み→未購入")
        print("RESULT toggle-both-ways ok")
    }

    func testVerticalDragDoesNotToggle() {
        drag("食パン", dx: 60, dy: 160)
        Thread.sleep(forTimeInterval: 1.5)
        let any = items().filter(\.purchased).map(\.name)
        print("RESULT vertical purchased=\(any)")
        XCTAssertEqual(any, [])
    }

    func testLeftSwipeRevealsDeleteButton() {
        let row = app.staticTexts["バナナ"]
        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -120, dy: 0)),
                    withVelocity: .slow, thenHoldForDuration: 0.1)
        let shown = app.buttons["削除"].waitForExistence(timeout: 3)
        XCTAssertTrue(shown)
        XCTAssertEqual(purchased("バナナ"), false, "左スワイプで購入済みにならない")
        XCTAssertNotNil(purchased("バナナ"), "ボタンが出るだけで削除はされない")
        app.buttons["削除"].tap()
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertNil(purchased("バナナ"), "削除ボタンで消える")
        print("RESULT left-swipe delete ok")
    }

    func testLongPressReorderStillWorks() {
        let before = items().map(\.name)
        let from = app.staticTexts["卵"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let to = app.staticTexts["トマト"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.2))
        from.press(forDuration: 1.2, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.5)
        Thread.sleep(forTimeInterval: 2)
        let after = items().map(\.name)
        print("RESULT reorder before=\(before) after=\(after) purchased=\(items().filter(\.purchased).map(\.name))")
        XCTAssertNotEqual(before, after)
        XCTAssertEqual(items().filter(\.purchased).map(\.name), [])
    }

    func testCircleTapStillToggles() {
        app.staticTexts["豆腐"].coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .withOffset(CGVector(dx: -24, dy: 0)).tap()
        XCTAssertTrue(waitPurchased("豆腐", true))
        print("RESULT circle-tap ok")
    }

    private func hasFocus(_ e: XCUIElement) -> Bool { (e.value(forKey: "hasKeyboardFocus") as? Bool) ?? false }

    /// return 直後から 2 秒間フォーカスを見張り、一度でも外れたら false
    private func focusHeld(_ e: XCUIElement) -> (Bool, Int) {
        var samples = 0
        let end = Date().addingTimeInterval(2.0)
        while Date() < end {
            samples += 1
            if !hasFocus(e) { return (false, samples) }
        }
        return (true, samples)
    }

    func testKeyboardStaysOpenAfterAdd() {
        let field = app.textFields["アイテムを追加"]
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        field.typeText("apple\n")
        let (held1, n1) = focusHeld(field)
        field.typeText("lemon\n")
        let (held2, n2) = focusHeld(field)
        let names = items().map(\.name)
        print("RESULT keyboard held1=\(held1)(samples=\(n1)) held2=\(held2)(samples=\(n2)) names=\(names)")
        XCTAssertTrue(held1)
        XCTAssertTrue(held2)
        XCTAssertTrue(names.contains("apple") && names.contains("lemon"))
        field.typeText("\n")
        Thread.sleep(forTimeInterval: 1.0)
        let kb3 = app.keyboards.firstMatch.exists
        print("RESULT keyboard after-empty-return=\(kb3)")
        XCTAssertFalse(kb3, "空で return を押したら閉じる")
    }

    func testScrollStillWorks() {
        let first = app.staticTexts["卵"]
        let startY = first.frame.minY
        let c = app.staticTexts["バナナ"].coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
        c.press(forDuration: 0.05, thenDragTo: c.withOffset(CGVector(dx: 0, dy: -300)), withVelocity: .fast, thenHoldForDuration: 0)
        Thread.sleep(forTimeInterval: 1.0)
        let endY = first.exists ? first.frame.minY : -9999
        print("RESULT scroll startY=\(startY) endY=\(endY) purchased=\(items().filter(\.purchased).map(\.name))")
        XCTAssertLessThan(endY, startY - 100)
        XCTAssertEqual(items().filter(\.purchased).map(\.name), [])
    }

}
