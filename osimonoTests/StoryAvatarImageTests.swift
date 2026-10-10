import Testing
import UIKit
@testable import osimono

@MainActor
struct StoryAvatarImageTests {
    private let firstURL = URL(string: "https://example.com/first.png")!
    private let secondURL = URL(string: "https://example.com/second.png")!

    @Test
    func loadedAvatarIsImmediatelyAvailableWithoutRefetching() async throws {
        let expected = UIImage(systemName: "person.fill")!
        var fetchCount = 0
        let store = StoryAvatarImageStore { _ in
            fetchCount += 1
            return expected
        }

        let first = try await store.image(for: firstURL)
        // 再生成されたViewが、非同期処理を待たずに同じ画像を表示できる。
        #expect(store.cachedImage(for: firstURL) === first)
        let second = try await store.image(for: firstURL)
        #expect(second === first)
        #expect(fetchCount == 1)
    }

    @Test
    func changedAvatarURLLoadsTheNewImage() async throws {
        let first = UIImage(systemName: "person.fill")!
        let second = UIImage(systemName: "star.fill")!
        var fetchedURLs: [URL] = []
        let store = StoryAvatarImageStore { url in
            fetchedURLs.append(url)
            return url == firstURL ? first : second
        }

        _ = try await store.image(for: firstURL)
        #expect(store.cachedImage(for: secondURL) == nil)
        let changed = try await store.image(for: secondURL)
        #expect(changed === second)
        #expect(store.cachedImage(for: firstURL) === first)
        #expect(fetchedURLs == [firstURL, secondURL])
    }

    @Test
    func multipleAvatarsShareAnUnfinishedRequest() async throws {
        let expected = UIImage(systemName: "person.fill")!
        var pending: CheckedContinuation<UIImage, Never>?
        var fetchCount = 0
        let store = StoryAvatarImageStore { _ in
            fetchCount += 1
            return await withCheckedContinuation { pending = $0 }
        }
        let first = Task { try await store.image(for: firstURL) }
        while pending == nil { await Task.yield() }
        let second = Task { try await store.image(for: firstURL) }
        await Task.yield()
        // 最初の表示が消えても、別のアバターの読み込みを中断しない。
        first.cancel()
        pending?.resume(returning: expected)

        let firstImage = try await first.value
        let secondImage = try await second.value
        #expect(firstImage === expected)
        #expect(secondImage === expected)
        #expect(fetchCount == 1)
    }

    @Test
    func failedRequestCanBeRetried() async throws {
        let expected = UIImage(systemName: "person.fill")!
        var fetchCount = 0
        let store = StoryAvatarImageStore { _ in
            fetchCount += 1
            if fetchCount == 1 { throw URLError(.notConnectedToInternet) }
            return expected
        }

        await #expect(throws: URLError.self) { try await store.image(for: firstURL) }
        #expect(store.cachedImage(for: firstURL) == nil)
        let retried = try await store.image(for: firstURL)
        #expect(retried === expected)
        #expect(fetchCount == 2)
    }
}
