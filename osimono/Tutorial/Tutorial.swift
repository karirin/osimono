//
//  Tutorial.swift
//  osimono
//
//  体験型チュートリアル
//  推しを登録 → 推し活を投稿 → 推しからメッセージが届く → 返信する
//  までを、実際の画面を操作しながら進める。
//

import SwiftUI

// チュートリアルのステップ
enum TutorialStep: Int, CaseIterable {
    case welcome = 0
    case registerOshi    // 推しを登録する
    case createPost      // 推し活を投稿する
    case messageArrived  // 推しからメッセージが届いた（通知バナー）
    case reply           // チャット画面で返信する
    case waitingReply    // 推しの返事待ち（オーバーレイ非表示）
    case completed
}

// スポットライトを当てる画面上の要素
enum TutorialTarget: Hashable {
    case registerOshiButton
    case addPostButton
}

// 投稿後に届いたメッセージ（通知バナー表示用）
struct TutorialArrivedMessage {
    let oshiName: String
    let oshiImageUrl: String?
    let content: String?
}

final class TutorialManager: ObservableObject {
    static let shared = TutorialManager()

    @Published var isShowingTutorial: Bool = false
    @Published var currentStep: TutorialStep = .welcome
    @Published private(set) var targetFrames: [TutorialTarget: CGRect] = [:]
    @Published private(set) var arrivedMessage: TutorialArrivedMessage?
    /// ProfileSection がこれを受けて推しとのチャットを開く
    @Published var chatOpenRequested = false

    /// 推しが1人以上登録済みか（登録済みなら推し登録ステップを飛ばす）
    private var hasOshi = false

    private init() {
        isShowingTutorial = !UserDefaults.standard.bool(forKey: "tutorialCompleted")
    }

    func isAt(_ step: TutorialStep) -> Bool {
        isShowingTutorial && currentStep == step
    }

    // MARK: - 開始・終了

    func startTutorial() {
        arrivedMessage = nil
        currentStep = .welcome
        isShowingTutorial = true
    }

    /// ようこそ画面の「やってみる」
    func begin() {
        guard isAt(.welcome) else { return }
        move(to: hasOshi ? .createPost : .registerOshi)
    }

    func completeTutorial() {
        isShowingTutorial = false
        chatOpenRequested = false
        UserDefaults.standard.set(true, forKey: "tutorialCompleted")
    }

    func skipTutorial() {
        completeTutorial()
    }

    // MARK: - 各画面からの通知

    /// 推しが登録された / 登録済みの推しが読み込まれた
    func oshiDidBecomeAvailable() {
        hasOshi = true
        if isAt(.registerOshi) {
            move(to: .createPost)
        }
    }

    /// 投稿が保存され、推しからのメッセージ生成が終わった（失敗時は content = nil）
    func postDidSave(oshiName: String, oshiImageUrl: String?, messageContent: String?) {
        guard isAt(.createPost) else { return }
        arrivedMessage = TutorialArrivedMessage(oshiName: oshiName, oshiImageUrl: oshiImageUrl, content: messageContent)
        // 投稿画面が閉じるのを待ってから通知を出す
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard self.isAt(.createPost) else { return }
            self.move(to: .messageArrived)
        }
    }

    /// 通知バナーをタップした
    func openArrivedMessage() {
        guard isAt(.messageArrived) else { return }
        chatOpenRequested = true
    }

    func chatDidAppear() {
        chatOpenRequested = false
        if isAt(.messageArrived) {
            move(to: .reply)
        }
    }

    /// 返信せずにチャットを閉じたら、もう一度通知から開けるようにする
    func chatDidDisappear() {
        if isAt(.reply) {
            move(to: .messageArrived)
        }
    }

    func replyDidSend() {
        if isAt(.reply) {
            move(to: .waitingReply)
        }
    }

    func replyDidArrive() {
        guard isAt(.waitingReply) else { return }
        // 推しの返事を読む時間をとってから完了画面を出す
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard self.isAt(.waitingReply) else { return }
            self.move(to: .completed)
        }
    }

    func replyDidFail() {
        if isAt(.waitingReply) {
            move(to: .reply)
        }
    }

    // MARK: - スポットライト対象の位置

    func setFrame(_ frame: CGRect?, for target: TutorialTarget) {
        guard targetFrames[target] != frame else { return }
        targetFrames[target] = frame
    }

    private func move(to step: TutorialStep) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = step
        }
    }
}

extension View {
    /// チュートリアルでスポットライトを当てる要素として位置を登録する
    func tutorialTarget(_ target: TutorialTarget) -> some View {
        background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { TutorialManager.shared.setFrame(geo.frame(in: .global), for: target) }
                    .onChange(of: geo.frame(in: .global)) { TutorialManager.shared.setFrame($0, for: target) }
                    .onDisappear { TutorialManager.shared.setFrame(nil, for: target) }
            }
        )
    }
}

// MARK: - オーバーレイ

struct TutorialOverlayView: View {
    @ObservedObject var tutorialManager = TutorialManager.shared
    let closeAction: () -> Void

    private let primaryColor = Color(.systemPink)
    private let accentColor = Color(.purple)

    var body: some View {
        ZStack {
            switch tutorialManager.currentStep {
            case .welcome:
                welcomeCard
            case .registerOshi:
                spotlight(
                    target: .registerOshiButton,
                    title: L10n.tutorialRegisterOshiTitle,
                    message: L10n.tutorialRegisterOshiMessage,
                    icon: "person.crop.circle.badge.plus"
                )
            case .createPost:
                spotlight(
                    target: .addPostButton,
                    title: L10n.tutorialCreatePostTitle,
                    message: L10n.tutorialCreatePostMessage,
                    icon: "square.and.pencil"
                )
            case .messageArrived:
                messageArrivedBanner
            case .reply, .waitingReply:
                // チャット画面内にヒントを表示するので、ここでは何も出さない
                EmptyView()
            case .completed:
                completedCard
            }
        }
        .transition(.opacity)
        .animation(.easeInOut, value: tutorialManager.currentStep)
    }

    // MARK: ようこそ

    private var welcomeCard: some View {
        centeredCard {
            VStack(spacing: 16) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(colors: [primaryColor, accentColor], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )

                Text(L10n.tutorialWelcomeTitle)
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text(L10n.tutorialWelcomeMessage)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    stepRow(number: 1, text: L10n.tutorialFlowRegister)
                    stepRow(number: 2, text: L10n.tutorialFlowPost)
                    stepRow(number: 3, text: L10n.tutorialFlowReply)
                }
                .padding(.vertical, 4)

                primaryButton(L10n.tutorialBegin) {
                    tutorialManager.begin()
                }

                Button(action: {
                    generateHapticFeedback()
                    tutorialManager.skipTutorial()
                    closeAction()
                }) {
                    Text(L10n.tutorialSkip)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(primaryColor))
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }

    // MARK: 完了

    private var completedCard: some View {
        centeredCard {
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundColor(primaryColor)

                Text(L10n.tutorialCompletedTitle)
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text(L10n.tutorialCompletedMessage)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                primaryButton(L10n.tutorialStart) {
                    tutorialManager.completeTutorial()
                    closeAction()
                }
            }
        }
    }

    // MARK: スポットライト

    @ViewBuilder
    private func spotlight(target: TutorialTarget, title: String, message: String, icon: String) -> some View {
        // 対象が画面に無い（入力画面に遷移中など）ときは、遷移先の画面内のヒントに任せる
        if let frame = tutorialManager.targetFrames[target] {
            let hole = frame.insetBy(dx: -10, dy: -10)
            let screenHeight = UIScreen.main.bounds.height
            let showBelow = hole.midY < screenHeight / 2

            let cornerRadius = min(hole.width, hole.height) / 2

            ZStack {
                SpotlightShape(hole: hole, cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.65), style: FillStyle(eoFill: true))
                    .allowsHitTesting(false)

                TouchBlocker(hole: hole) // 穴の外のタップは無効にする

                PulsingRing(frame: hole, cornerRadius: cornerRadius, color: primaryColor)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    if showBelow {
                        Spacer(minLength: 0).frame(height: hole.maxY + 16)
                        bubble(title: title, message: message, icon: icon)
                        Spacer()
                    } else {
                        Spacer()
                        bubble(title: title, message: message, icon: icon)
                        Spacer(minLength: 0).frame(height: screenHeight - hole.minY + 16)
                    }
                }
                .padding(.horizontal, 20)
            }
            .ignoresSafeArea()
        }
    }

    private func bubble(title: String, message: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(primaryColor)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                skipButton
            }
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(cardBackground)
    }

    // MARK: メッセージ到着通知

    private var messageArrivedBanner: some View {
        let arrived = tutorialManager.arrivedMessage
        return ZStack(alignment: .top) {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {}

            VStack(spacing: 14) {
                Button(action: {
                    generateHapticFeedback()
                    tutorialManager.openArrivedMessage()
                }) {
                    HStack(alignment: .top, spacing: 12) {
                        oshiIcon(urlString: arrived?.oshiImageUrl)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(arrived?.oshiName ?? "")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(L10n.tutorialNow)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(arrived?.content ?? L10n.tutorialMessageFallback)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.regularMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(primaryColor.opacity(0.6), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope.open.fill")
                            .foregroundColor(primaryColor)
                        Text(L10n.tutorialMessageArrivedTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        skipButton
                    }
                    Text(L10n.tutorialMessageArrivedMessage)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .background(cardBackground)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func oshiIcon(urlString: String?) -> some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        iconPlaceholder
                    }
                }
            } else {
                iconPlaceholder
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
    }

    private var iconPlaceholder: some View {
        ZStack {
            Circle().fill(primaryColor.opacity(0.2))
            Image(systemName: "heart.fill")
                .foregroundColor(primaryColor)
        }
    }

    // MARK: 共通パーツ

    private func centeredCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture {}
            content()
                .padding(24)
                .background(cardBackground)
                .padding(.horizontal, 24)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.black.opacity(0.9))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(primaryColor.opacity(0.35), lineWidth: 1)
            )
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            generateHapticFeedback()
            action()
        }) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [primaryColor, accentColor], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(12)
        }
    }

    private var skipButton: some View {
        Button(action: {
            generateHapticFeedback()
            tutorialManager.skipTutorial()
            closeAction()
        }) {
            Text(L10n.tutorialSkip)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    private func generateHapticFeedback() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

/// 画面全体から穴（hole）をくり抜いた形
private struct SpotlightShape: Shape {
    let hole: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        path.addRoundedRect(in: hole, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        return path
    }
}

/// 穴（hole）の上下左右だけタップを吸収し、穴の中のタップは下の画面に通す
private struct TouchBlocker: View {
    let hole: CGRect

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let blockers = [
                CGRect(x: 0, y: 0, width: size.width, height: max(hole.minY, 0)),
                CGRect(x: 0, y: hole.maxY, width: size.width, height: max(size.height - hole.maxY, 0)),
                CGRect(x: 0, y: hole.minY, width: max(hole.minX, 0), height: hole.height),
                CGRect(x: hole.maxX, y: hole.minY, width: max(size.width - hole.maxX, 0), height: hole.height)
            ]
            ForEach(blockers.indices, id: \.self) { index in
                let rect = blockers[index]
                Color.black.opacity(0.001)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .onTapGesture {}
            }
        }
    }
}

private struct PulsingRing: View {
    let frame: CGRect
    let cornerRadius: CGFloat
    let color: Color
    @State private var animate = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(color, lineWidth: 3)
            .frame(width: frame.width, height: frame.height)
            .scaleEffect(animate ? 1.08 : 1.0)
            .opacity(animate ? 0.4 : 1.0)
            .position(x: frame.midX, y: frame.midY)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
    }
}

/// 入力画面・チャット画面の中に出すチュートリアルのヒント
struct TutorialInlineTip: View {
    let text: String
    var icon: String = "hand.point.up.left.fill"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.white)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(colors: [Color(.systemPink), Color(.purple)], startPoint: .leading, endPoint: .trailing)
                )
        )
    }
}
