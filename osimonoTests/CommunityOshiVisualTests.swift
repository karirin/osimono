import SwiftUI
import XCTest
@testable import osimono

@MainActor
final class CommunityOshiVisualTests: XCTestCase {
    func testCardsInLightDarkAndLargeText() throws {
        let profiles = [
            CommunityOshi(id: "1", creatorID: "sora", creatorName: "そら", name: "凛", introduction: "今日あったこと、少し聞かせて。あなたのペースで話せる、穏やかな聞き上手。", category: "gentle", tags: ["日常", "雑談"], personality: "優しい", speakingStyle: "穏やかな口調", signaturePhrase: "", sampleLine: "", publishedAt: 0),
            CommunityOshi(id: "2", creatorID: "mio", creatorName: "みお", name: "陽向", introduction: "落ち込んだ日も、一緒に笑えることを見つけてくれる幼なじみ。", category: "cheerful", tags: ["幼なじみ", "元気"], personality: "明るい", speakingStyle: "", signaturePhrase: "", sampleLine: "", publishedAt: 0)
        ]
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        defer { previous?.makeKeyAndVisible() }
        for (scheme, size) in [(ColorScheme.light, DynamicTypeSize.large), (.dark, .accessibility1)] {
            let content = NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("気になる推しと、\n新しい会話を。").font(.largeTitle.bold())
                        Text("みんなが公開した推しを、あなたの一覧に。").font(.subheadline).foregroundStyle(.secondary)
                        Text("新しく公開された推し").font(.headline)
                        ForEach(profiles) { CommunityProfileCard(profile: $0) }
                        CommunityDiscoveryEntry {}
                    }.padding(20)
                }.background(Color(.systemGroupedBackground))
                    .navigationTitle("みんなの推し").navigationBarTitleDisplayMode(.inline)
            }.environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, size)
            let controller = UIHostingController(rootView: content)
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            window.rootViewController = controller; window.makeKeyAndVisible()
            controller.view.frame = window.bounds; controller.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "community-\(scheme)-\(size)"; attachment.lifetime = .keepAlways
            add(attachment)
            window.isHidden = true; window.rootViewController = nil
        }
    }
}
