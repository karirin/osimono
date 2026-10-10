import SwiftUI

/// Bundled scenery. Select only within the story's setting; keep the previous location
/// when a new scene does not name one. This also works with existing saved stories.
enum StoryBackdrop: String, CaseIterable {
    case schoolClassroom = "story_school_classroom"
    case schoolCourtyard = "story_school_courtyard"
    case schoolRooftop = "story_school_rooftop"
    case houseLivingroom = "story_house_livingroom"
    case houseKitchen = "story_house_kitchen"
    case houseBalcony = "story_house_balcony"
    case fantasyTown = "story_fantasy_town"
    case fantasyForest = "story_fantasy_forest"
    case fantasyRuins = "story_fantasy_ruins"

    static func opening(for setting: StorySetting) -> StoryBackdrop {
        switch setting {
        case .school: return .schoolClassroom
        case .house: return .houseLivingroom
        case .fantasy: return .fantasyTown
        }
    }

    static func resolve(setting: StorySetting, scenes: [StoryScene], through index: Int? = nil) -> StoryBackdrop {
        let candidates: [StoryBackdrop]
        switch setting {
        case .school: candidates = [.schoolRooftop, .schoolCourtyard, .schoolClassroom]
        case .house: candidates = [.houseBalcony, .houseKitchen, .houseLivingroom]
        case .fantasy: candidates = [.fantasyRuins, .fantasyForest, .fantasyTown]
        }
        let lastIndex = index ?? Int.max
        for scene in scenes.reversed() where scene.index <= lastIndex {
            let narration = scene.narration.lowercased()
            if let backdrop = candidates.first(where: { backdrop in
                backdrop.locationWords.contains(where: { narration.contains($0) })
            }) {
                return backdrop
            }
        }
        return opening(for: setting)
    }

    private var locationWords: [String] {
        switch self {
        case .schoolClassroom: return ["教室", "黒板", "classroom", "blackboard"]
        case .schoolCourtyard: return ["中庭", "校庭", "桜の木", "courtyard", "schoolyard", "cherry tree"]
        case .schoolRooftop: return ["屋上", "rooftop", "school roof"]
        case .houseLivingroom: return ["リビング", "居間", "ソファ", "living room", "lounge", "sofa"]
        case .houseKitchen: return ["キッチン", "台所", "ダイニング", "食卓", "kitchen", "dining room", "dining table"]
        case .houseBalcony: return ["バルコニー", "ベランダ", "テラス", "balcony", "veranda", "terrace"]
        case .fantasyTown: return ["城下町", "街", "町", "村", "広場", "town", "village", "city", "market square"]
        case .fantasyForest: return ["森", "林", "木々", "forest", "woods", "woodland"]
        case .fantasyRuins: return ["遺跡", "神殿", "聖域", "祭壇", "ruins", "temple", "sanctuary", "altar"]
        }
    }
}

/// Clip the image to the proposed bounds so its intrinsic size cannot widen a card.
struct StorySceneryImage: View {
    var backdrop: StoryBackdrop

    var body: some View {
        GeometryReader { proxy in
            Image(backdrop.rawValue)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .accessibilityHidden(true)
    }
}

struct StorySceneBackdrop: View {
    var backdrop: StoryBackdrop

    var body: some View {
        StorySceneryImage(backdrop: backdrop)
            .aspectRatio(3.0 / 2.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: StoryTheme.Radius.cardSmall, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: StoryTheme.Radius.cardSmall, style: .continuous)
                .strokeBorder(StoryTheme.border, lineWidth: 1))
            .storyShadow(.normal)
    }
}

#if DEBUG
#Preview("9つの背景") {
    ScrollView {
        LazyVStack(spacing: 16) {
            ForEach(StoryBackdrop.allCases, id: \.self) { backdrop in
                StorySceneBackdrop(backdrop: backdrop)
            }
        }
        .padding(StoryTheme.gutter)
    }
    .background(StoryTheme.background)
}
#endif
