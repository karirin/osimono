import SwiftUI
import XCTest
@testable import osimono

@MainActor
final class StoryLimitCardTests: XCTestCase {
    func testLimitCardRendersAtCompactWidthAndWithLargeText() async throws {
        let normal = try await snapshot(name: "Story limit · compact", size: .large)
        let large = try await snapshot(name: "Story limit · accessibility", size: .accessibility2)
        XCTAssertGreaterThan(large.size.height, normal.size.height)
    }

    func testAdLoadingCardRenders() async throws {
        _ = try await snapshot(name: "Story limit · preparing ad", size: .large, isAdLoading: true)
    }

    private func snapshot(name: String, size: DynamicTypeSize, isAdLoading: Bool = false) async throws -> UIImage {
        let card = StatusCard(kind: .limit, isAdLoading: isAdLoading, adRewardCount: 5)
            .padding(20)
            .frame(width: 375)
            .background(StoryTheme.background)
            .environment(\.dynamicTypeSize, size)
            .environment(\.colorScheme, .light)
        // UIHostingController で、ProgressView など UIKit を使う表示も描画する。
        let host = UIHostingController(rootView: card.ignoresSafeArea())
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.windowLevel = .alert + 1
        window.isHidden = false
        defer { window.isHidden = true }
        await Task.yield()
        let fittingSize = host.sizeThatFits(in: CGSize(width: 375, height: 2000))
        window.frame = CGRect(origin: .zero, size: fittingSize)
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        await Task.yield()
        let renderer = UIGraphicsImageRenderer(size: fittingSize)
        let image = renderer.image { _ in
            XCTAssertTrue(host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true))
        }
        XCTAssertEqual(image.size.width, 375, accuracy: 1)
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return image
    }
}
