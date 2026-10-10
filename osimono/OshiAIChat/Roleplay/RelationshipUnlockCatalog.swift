//
//  RelationshipUnlockCatalog.swift
//  osimono
//
//  既定のアンロックコンテンツ（全キャラクター共通）。ロジックではなくデータとしてここに置く。
//  title / description / payload の値は Localizable のキー（見つからなければそのまま表示）。
//
//  Firebase の relationshipUnlockCatalog/{default | characterId}/{unlockId} に同じ形のデータを置くと、
//  アプリ更新なしで追加・上書きできる（同じIDなら Firebase 側が優先。写真は管理側で登録する）:
//    { "type": "photo", "requiredStage": "close", "requiredAffection": 0, "requiredTrust": 0,
//      "contentId": "https://...jpg", "title": "私服写真", "description": "…", "characterId": "*" }
//

import Foundation

enum RelationshipUnlockCatalog {
    static let defaults: [RelationshipUnlock] = [
        // 少し気になる
        RelationshipUnlock(
            id: "nickname_casual", type: .nickname, requiredStage: .acquaintance,
            contentId: RelationshipNicknameStyle.casual.rawValue,
            title: "unlock_nickname_casual_title", description: "unlock_nickname_casual_desc"
        ),

        // 親しい
        RelationshipUnlock(
            id: "scenario_holiday_cafe", type: .scenario, requiredStage: .close,
            contentId: "holiday_cafe",
            title: "unlock_scenario_cafe_title", description: "unlock_scenario_cafe_desc",
            payload: ["location": "unlock_scenario_cafe_location", "time": "unlock_scenario_cafe_time", "situation": "unlock_scenario_cafe_situation"],
            order: 1
        ),
        RelationshipUnlock(
            id: "special_message_small_secret", type: .specialMessage, requiredStage: .close,
            contentId: "small_secret",
            title: "unlock_small_secret_title", description: "unlock_small_secret_desc",
            payload: ["hint": "unlock_small_secret_hint"],
            order: 2
        ),

        // 特別な存在
        RelationshipUnlock(
            id: "nickname_custom", type: .nickname, requiredStage: .special,
            contentId: RelationshipNicknameStyle.custom.rawValue,
            title: "unlock_nickname_custom_title", description: "unlock_nickname_custom_desc"
        ),
        RelationshipUnlock(
            id: "scenario_night_walk", type: .scenario, requiredStage: .special,
            contentId: "night_walk",
            title: "unlock_scenario_night_walk_title", description: "unlock_scenario_night_walk_desc",
            payload: ["location": "unlock_scenario_night_walk_location", "time": "unlock_scenario_night_walk_time", "situation": "unlock_scenario_night_walk_situation"],
            order: 1
        ),

        // 恋人
        RelationshipUnlock(
            id: "relationship_setting_lovers", type: .relationshipSetting, requiredStage: .lover,
            contentId: "lovers",
            title: "unlock_lovers_title", description: "unlock_lovers_desc",
            payload: ["label": "unlock_lovers_label"]
        ),
        RelationshipUnlock(
            id: "special_message_true_feelings", type: .specialMessage, requiredStage: .lover,
            contentId: "true_feelings",
            title: "unlock_true_feelings_title", description: "unlock_true_feelings_desc",
            payload: ["hint": "unlock_true_feelings_hint"],
            order: 1
        )
    ]
}
