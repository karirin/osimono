#if DEBUG
import Foundation

/// #Preview 専用のサンプル。Firebase・AIには接続しない。
enum StoryPreviewData {
    static let sakura = StoryCharacter(id: "sakura", name: "さくら", imageURL: nil, profile: [:], role: "クラスメイト")
    static let ren = StoryCharacter(id: "ren", name: "蓮", imageURL: nil, profile: [:], role: "生徒会長")
    static let mio = StoryCharacter(id: "mio", name: "ミオ", imageURL: nil, profile: [:], role: "転校生")
    static let cast = [sakura, ren, mio]

    static func configuration(cast: [StoryCharacter] = cast, title: String = "放課後、秘密の作戦会議",
                              participation: StoryParticipation = .member) -> StoryConfiguration {
        var pairs: [StoryPair] = []
        for first in cast.indices {
            for second in cast.indices where second > first {
                pairs.append(StoryPair(firstID: cast[first].id, secondID: cast[second].id))
            }
        }
        return StoryConfiguration(
            title: title, setting: .school,
            synopsis: "文化祭まであと1週間。クラス展示を「思い出に残るもの」にしたいさくらの一言から、放課後の空き教室で秘密の作戦会議が始まる。",
            mood: .youth, romance: false, participation: participation,
            leadID: participation == .member ? cast.first?.id : nil,
            userName: "あなた", userRole: "クラスの実行委員", language: "ja",
            cast: cast, relationships: pairs)
    }

    private static let narrations = [
        "放課後の廊下。文化祭まであと1週間という張り紙の前で、さくらがあなたの袖を小さく引いた。",
        "空き教室。夕日が差し込む黒板に、4人で出し合った案がびっしりと並んでいく。いつの間にか、生徒会長の蓮も腕を組んで加わっていた。",
        "実行委員室の前。ドアの向こうから、誰かが言い争う声が聞こえてくる。さくらが、そっとあなたの顔を見上げた。",
        "翌朝の昇降口。掲示板に、展示の場所が体育館裏に変更されたという紙が貼られていた。",
        "体育館裏の倉庫。ほこりをかぶった古い幕を広げると、ミオが目を輝かせた。",
        "夜の教室。作業が進まず、蓮が珍しく声を荒げた。",
        "文化祭当日の朝。準備が終わった教室に、朝の光が差し込む。",
        "開場直後。思った以上の人が、展示の前に列を作り始めた。",
        "後夜祭。校庭のキャンプファイヤーを見ながら、4人は並んで座っていた。"
    ]

    private static let choiceSets = [
        ["みんなの意見を一度整理して、もう一度話し合う", "さくらの案に乗って、実行委員に相談しに行く", "黒板の案を写真に撮り、蓮にだけ見せる"],
        ["ドアをノックして中に入る", "しばらく様子をうかがう", "さくらと一度教室へ戻る"],
        ["新しい場所を下見しに行く", "変更の理由を聞きに行く", "クラスのみんなに知らせる"]
    ]

    static func scene(_ index: Int) -> StoryScene {
        let speakers = [sakura, mio, ren]
        let lines = [
            StoryLine(speakerID: speakers[index % 3].id, text: "ねえ、今年のクラス展示、このままでいいのかな。"),
            StoryLine(speakerID: speakers[(index + 1) % 3].id, text: "それなら、わたしも手伝う！ 初めての文化祭だもん。")
        ]
        return StoryScene(index: index, narration: narrations[index], lines: lines,
                          choices: index == 8 ? [] : choiceSets[index % 3])
    }

    /// 場面数を指定したサンプル（0 = 扉、9 = 完結）
    static func record(sceneCount: Int, cast: [StoryCharacter] = cast, title: String = "放課後、秘密の作戦会議") -> StoryRecord {
        var record = StoryRecord(id: "preview-\(sceneCount)-\(cast.count)", ownerID: "preview",
                                 configuration: configuration(cast: cast, title: title))
        record.scenes = (0..<sceneCount).map(scene)
        record.decisions = (0..<max(0, sceneCount - 1)).map { index in
            StoryDecision(sceneIndex: index, intent: record.scenes[index].choices[1], choiceIndex: 1)
        }
        record.revision = sceneCount
        return record
    }

    static let libraryRecords: [StoryRecord] = [
        record(sceneCount: 2),
        record(sceneCount: 6, cast: [mio, ren], title: "灯を取り戻す旅"),
        record(sceneCount: 9, cast: [sakura], title: "シェアハウスの小さな約束")
    ]
}

/// プレビューでセッションを組み立てるための何もしない保存・生成。
struct StoryPreviewService: StorySaving, StoryGenerating {
    func save(_ record: StoryRecord, expectedRevision: Int?) async throws {}
    func generate(record: StoryRecord, decision: StoryDecision?) async throws -> StoryScene {
        try await Task.sleep(nanoseconds: 1_500_000_000)
        return StoryPreviewData.scene(record.scenes.count)
    }
}
#endif
