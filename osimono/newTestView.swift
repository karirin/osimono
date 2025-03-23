import SwiftUI
import Lottie

struct LottieView: UIViewRepresentable {
    typealias UIViewType = LottieAnimationView  // ここを変更

    var filename: String

    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView()
        let animation = LottieAnimation.named(filename)
        animationView.animation = animation
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.play()
        return animationView
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        // 更新が必要な場合に記述
    }
}

struct TestView: View {
    var body: some View {
        LottieView(filename: "test")
            .frame(width: 200, height: 200)
    }
}

#Preview {
    TestView()
}

