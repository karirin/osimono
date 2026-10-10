import SwiftUI
import UIKit
import ImageIO

enum ChatBackgroundTheme: String, Codable, CaseIterable, Identifiable {
    case standard, rose, lavender, sky, mint, cream, photo
    var id: String { rawValue }
    var title: String { NSLocalizedString("chat_background_\(rawValue)", comment: "Chat background") }

    func colors(for scheme: ColorScheme) -> [Color] {
        let dark = scheme == .dark
        switch self {
        case .standard, .photo:
            return dark ? [Color(red: 0.1, green: 0.1, blue: 0.12), Color(red: 0.08, green: 0.08, blue: 0.1)]
                : [Color(red: 0.98, green: 0.97, blue: 0.99), Color(red: 0.95, green: 0.94, blue: 0.98)]
        case .rose:
            return dark ? [Color(red: 0.22, green: 0.12, blue: 0.16), Color(red: 0.13, green: 0.08, blue: 0.11)]
                : [Color(red: 1, green: 0.94, blue: 0.96), Color(red: 0.98, green: 0.84, blue: 0.89)]
        case .lavender:
            return dark ? [Color(red: 0.18, green: 0.13, blue: 0.25), Color(red: 0.1, green: 0.08, blue: 0.16)]
                : [Color(red: 0.96, green: 0.93, blue: 1), Color(red: 0.87, green: 0.83, blue: 0.97)]
        case .sky:
            return dark ? [Color(red: 0.1, green: 0.18, blue: 0.25), Color(red: 0.06, green: 0.11, blue: 0.17)]
                : [Color(red: 0.92, green: 0.97, blue: 1), Color(red: 0.8, green: 0.9, blue: 0.97)]
        case .mint:
            return dark ? [Color(red: 0.1, green: 0.21, blue: 0.18), Color(red: 0.06, green: 0.13, blue: 0.11)]
                : [Color(red: 0.93, green: 0.99, blue: 0.96), Color(red: 0.81, green: 0.94, blue: 0.88)]
        case .cream:
            return dark ? [Color(red: 0.22, green: 0.18, blue: 0.12), Color(red: 0.14, green: 0.11, blue: 0.08)]
                : [Color(red: 1, green: 0.98, blue: 0.93), Color(red: 0.96, green: 0.9, blue: 0.79)]
        }
    }
}

enum ChatFontStyle: String, Codable, CaseIterable, Identifiable {
    case standard, rounded, serif
    var id: String { rawValue }
    var title: String { NSLocalizedString("chat_font_\(rawValue)", comment: "Chat font") }

    func font(size: CGFloat) -> Font {
        switch self {
        case .standard: return .system(size: size)
        case .rounded:
            // Use the Japanese rounded face where available, and the system rounded design otherwise.
            if UIFont(name: "HiraginoMaruGothicProN-W4", size: size) != nil {
                return .custom("HiraginoMaruGothicProN-W4", fixedSize: size)
            }
            return .system(size: size, design: .rounded)
        case .serif:
            return .custom("HiraMinProN-W3", fixedSize: size)
        }
    }
}

struct ChatAppearanceSettings: Codable, Equatable {
    var background: ChatBackgroundTheme = .standard
    var fontStyle: ChatFontStyle = .standard
    var fontSize: Double = 15

    var normalized: Self {
        var result = self
        result.fontSize = fontSize.isFinite ? min(max(fontSize, 13), 23) : 15
        return result
    }
}

/// Device-local preferences shared by individual and group chats. The app never uploads these photos.
@MainActor
final class ChatAppearanceStore: ObservableObject {
    static let shared = ChatAppearanceStore()
    static let settingsKey = "chat.appearance.v1"

    @Published private(set) var settings: ChatAppearanceSettings
    @Published private(set) var photo: UIImage?
    private let defaults: UserDefaults
    private let photoURL: URL

    init(defaults: UserDefaults = .standard, directory: URL? = nil) {
        self.defaults = defaults
        let folder = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ChatAppearance", isDirectory: true)
        let savedPhotoURL = folder.appendingPathComponent("background.jpg")
        photoURL = savedPhotoURL
        var restored = defaults.data(forKey: Self.settingsKey)
            .flatMap { try? JSONDecoder().decode(ChatAppearanceSettings.self, from: $0) } ?? ChatAppearanceSettings()
        let savedPhoto = UIImage(contentsOfFile: savedPhotoURL.path)
        if restored.background == .photo && savedPhoto == nil { restored.background = .standard }
        settings = restored.normalized
        photo = savedPhoto
    }

    func setBackground(_ theme: ChatBackgroundTheme) {
        guard theme != .photo || photo != nil else { return }
        update { $0.background = theme }
    }

    func setFont(_ style: ChatFontStyle) { update { $0.fontStyle = style } }
    func setFontSize(_ size: Double) { update { $0.fontSize = size } }

    func savePhoto(_ data: Data) throws {
        guard let image = UIImage(data: data) else { throw CocoaError(.fileReadCorruptFile) }
        try FileManager.default.createDirectory(at: photoURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: photoURL, options: .atomic)
        photo = image
        setBackground(.photo)
    }

    func removePhoto() throws {
        if FileManager.default.fileExists(atPath: photoURL.path) { try FileManager.default.removeItem(at: photoURL) }
        photo = nil
        if settings.background == .photo { setBackground(.standard) }
    }

    func reset() throws {
        try removePhoto()
        update { $0 = ChatAppearanceSettings() }
    }

    private func update(_ change: (inout ChatAppearanceSettings) -> Void) {
        var next = settings
        change(&next)
        next = next.normalized
        guard next != settings else { return }
        defaults.set(try? JSONEncoder().encode(next), forKey: Self.settingsKey)
        settings = next
    }
}

enum ChatBackgroundPhoto {
    /// Downsample before decoding a full-resolution photo, and save only the rendered JPEG.
    static func prepare(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1600
              ] as CFDictionary),
              let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.82) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return jpeg
    }
}

private struct ChatAppearanceKey: EnvironmentKey {
    static let defaultValue = ChatAppearanceSettings()
}

extension EnvironmentValues {
    var chatAppearance: ChatAppearanceSettings {
        get { self[ChatAppearanceKey.self] }
        set { self[ChatAppearanceKey.self] = newValue }
    }
}

private struct ChatMessageFont: ViewModifier {
    @Environment(\.chatAppearance) private var appearance
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
    var sizeOffset: CGFloat

    func body(content: Content) -> some View {
        content.font(appearance.fontStyle.font(size: (CGFloat(appearance.fontSize) + sizeOffset) * scale))
    }
}

extension View {
    func chatMessageFont(sizeOffset: CGFloat = 0) -> some View {
        modifier(ChatMessageFont(sizeOffset: sizeOffset))
    }
}

struct ChatAppearanceBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let theme: ChatBackgroundTheme
    var photo: UIImage? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: theme.colors(for: colorScheme), startPoint: .top, endPoint: .bottom)
                if theme == .photo, let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                    // Keep timestamps and action descriptions legible over busy photos.
                    (colorScheme == .dark ? Color.black : Color.white).opacity(colorScheme == .dark ? 0.65 : 0.72)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
