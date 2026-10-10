import XCTest
import SwiftUI
@testable import osimono

@MainActor
final class CharacterConversationFeatureVisualTests: XCTestCase {
    func testPersonaAndInnerVoiceAtStandardAndAccessibleSizes() throws {
        let persona = RoleplayUserPersona(dictionary: ["isEnabled": true, "name": "春", "age": "22歳",
            "role": "推しのマネージャー", "personality": "明るいけれど、好きな人の前では照れ屋",
            "relationship": "幼なじみ。久しぶりに再会した", "background": "子どもの頃、同じ町で育った。"])
        for (scheme, size) in [(ColorScheme.light, DynamicTypeSize.large), (.dark, .accessibility1)] {
            let scene = NavigationStack {
                Form {
                    Section("返信の長さ") {
                        Picker("返信の長さ", selection: .constant(RoleplayReplyLength.standard)) {
                            ForEach(RoleplayReplyLength.allCases) { length in Text(length.title).tag(length) }
                        }.pickerStyle(.segmented)
                    }
                    Section {
                        Text("別に、待ってたわけじゃないし。")
                        InnerThoughtView(thought: "来てくれてよかった。もう少し一緒にいたい。", initiallyExpanded: true) {
                            HStack(spacing: 4) {
                                Text("18:42").foregroundStyle(.secondary)
                                Text("☺️")
                            }.font(.system(size: 10)).fixedSize()
                        }
                        InnerThoughtView(thought: "勇気を出して伝えられてよかった。") {
                            HStack(spacing: 4) {
                                Text("18:45").foregroundStyle(.secondary)
                                Text("🥰")
                            }.font(.system(size: 10)).fixedSize()
                        }
                    }
                    RoleplayPersonaSection(persona: .constant(persona))
                }
                .navigationTitle("ロールプレイ設定")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("ロールプレイ設定").font(.headline).foregroundStyle(.primary)
                    }
                }
            }
            .environment(\.locale, Locale(identifier: "ja"))
            .environment(\.colorScheme, scheme)
            .environment(\.dynamicTypeSize, size)
            let controller = UIHostingController(rootView: scene)
            let windowScene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let previousWindow = windowScene.windows.first(where: \.isKeyWindow)
            let window = UIWindow(windowScene: windowScene)
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            window.rootViewController = controller
            window.makeKeyAndVisible()
            controller.view.frame = window.bounds
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
            }
            XCTAssertEqual(image.size.width, 390)
            let pixels = try XCTUnwrap(image.cgImage?.dataProvider?.data)
            let bytes = try XCTUnwrap(CFDataGetBytePtr(pixels))
            let samples = stride(from: 0, to: CFDataGetLength(pixels), by: 100).map { bytes[$0] }
            XCTAssertGreaterThan(Set(samples).count, 8, "A blank screenshot is not visual verification.")
            let attachment = XCTAttachment(image: image)
            attachment.name = "character-features-\(scheme)-\(size)"
            attachment.lifetime = .keepAlways
            add(attachment)
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
        }
    }
}
