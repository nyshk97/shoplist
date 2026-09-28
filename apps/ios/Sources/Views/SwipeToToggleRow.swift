import SwiftUI
import UIKit

/// 左→右の短いスワイプで購入済みを切り替える行。
/// 標準の swipeActions は端まで引かないと確定しないため自前で実装している。
struct SwipeToToggleRow<Content: View>: View {
    let isPurchased: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: Content

    /// 行の幅に対して、この割合を超えて離したら確定する
    private static var commitRatio: CGFloat { 0.25 }

    @State private var translation: CGFloat = 0
    @State private var rowWidth: CGFloat = 0

    private var threshold: CGFloat { max(rowWidth * Self.commitRatio, 1) }

    private var offset: CGFloat {
        // しきい値の 2 倍を超えたら引っ張りを重くする
        let limit = threshold * 2
        return translation <= limit ? translation : limit + (translation - limit) * 0.3
    }

    private var isPastThreshold: Bool { offset >= threshold }

    var body: some View {
        content
            .offset(x: offset)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
            .listRowBackground(background)
            .gesture(RightSwipePanGesture { state, x in
                switch state {
                case .began, .changed:
                    translation = max(0, x)
                case .ended:
                    let commit = isPastThreshold
                    withAnimation(.snappy) { translation = 0 }
                    if commit { onToggle() }
                default:
                    withAnimation(.snappy) { translation = 0 }
                }
            })
            .sensoryFeedback(trigger: isPastThreshold) { _, past in
                past ? .impact(weight: .light) : nil
            }
    }

    private var background: some View {
        ZStack(alignment: .leading) {
            Color.green
            Image(systemName: isPurchased ? "arrow.uturn.backward" : "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .scaleEffect(isPastThreshold ? 1.15 : 0.9)
                .opacity(isPastThreshold ? 1 : 0.6)
                .animation(.snappy, value: isPastThreshold)
                .padding(.leading)
            Color(.secondarySystemGroupedBackground)
                .offset(x: offset)
        }
    }
}

/// 右向きの横スワイプのときだけ始まるパン。
/// SwiftUI の DragGesture は向きで開始を断れず、左スワイプの削除や縦スクロールまで奪ってしまうため
/// UIPanGestureRecognizer の gestureRecognizerShouldBegin で開始を絞る。
private struct RightSwipePanGesture: UIGestureRecognizerRepresentable {
    let onUpdate: (UIGestureRecognizer.State, CGFloat) -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        onUpdate(recognizer.state, recognizer.translation(in: recognizer.view).x)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let v = pan.velocity(in: pan.view)
            return v.x > 0 && abs(v.x) > abs(v.y)
        }
    }
}
