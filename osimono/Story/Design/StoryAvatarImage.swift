import SwiftUI
import UIKit

/// 同じURLの画像と読み込み中のリクエストを、ストーリー内のアバターで共有する。
@MainActor
final class StoryAvatarImageStore {
    static let shared = StoryAvatarImageStore()

    private let images = NSCache<NSURL, UIImage>()
    private var requests: [URL: Task<UIImage, Error>] = [:]
    private let fetch: (URL) async throws -> UIImage

    init(fetch: @escaping (URL) async throws -> UIImage = { url in
        let (data, response) = try await URLSession.shared.data(from: url)
        if let response = response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard let image = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
        return image
    }) {
        self.fetch = fetch
        images.countLimit = 100
        images.totalCostLimit = 32 * 1024 * 1024
    }

    func cachedImage(for url: URL) -> UIImage? {
        images.object(forKey: url as NSURL)
    }

    func image(for url: URL) async throws -> UIImage {
        if let image = cachedImage(for: url) { return image }
        if let request = requests[url] { return try await request.value }

        // 個々のViewが消えても、他のアバターが使う共有リクエストは継続する。
        let request = Task { try await fetch(url) }
        requests[url] = request
        defer { requests[url] = nil }
        let image = try await request.value
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        images.setObject(image, forKey: url as NSURL, cost: cost)
        return image
    }
}

/// Viewの再生成時にもキャッシュを即座に表示し、同じURLの再読み込みを防ぐ。
@MainActor
struct StoryAvatarImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?
    @State private var loadedURL: URL?

    private var displayedImage: UIImage? {
        guard let url else { return nil }
        if loadedURL == url, let loadedImage { return loadedImage }
        return StoryAvatarImageStore.shared.cachedImage(for: url)
    }

    var body: some View {
        Group {
            if let image = displayedImage {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else {
                loadedImage = nil
                loadedURL = nil
                return
            }
            do {
                let image = try await StoryAvatarImageStore.shared.image(for: url)
                guard !Task.isCancelled else { return }
                loadedImage = image
                loadedURL = url
            } catch {
                // 読み込み失敗時は既存のプレースホルダーを表示する。
            }
        }
    }
}
