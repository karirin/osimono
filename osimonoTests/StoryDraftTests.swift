import Foundation
import Testing
@testable import osimono

private let draftCast = (0..<4).map { StoryCharacter(id: "cast-\($0)", name: "Favorite \($0)", imageURL: nil, profile: [:], role: "") }

struct StoryDraftTests {
    @Test func debugCreationDraftUsesRegisteredCastAndIsReadyToCreate() throws {
        let draft = StoryDraft.initial(cast: draftCast)
        #if DEBUG
        #expect(draft.selected.map(\.id) == ["cast-0", "cast-1", "cast-2"])
        #expect(draft.leadID == "cast-0")
        #expect(draft.participation == .member)
        #expect(draft.blocker == nil)
        try draft.configuration(language: "ja").validate()
        #else
        #expect(draft == StoryDraft())
        #endif
    }

    @Test func blockerPrefersMissingCastOverMissingTitle() {
        var draft = StoryDraft()
        #expect(draft.blocker == .noCast)
        draft.toggle(draftCast[0])
        #expect(draft.blocker == .noTitle)
        draft.title = "  "
        #expect(draft.blocker == .noTitle)
        draft.title = "Story"
        #expect(draft.blocker == nil)
    }

    @Test func selectionIsCappedAtThreeAndRenumbersAfterRemoval() {
        var draft = StoryDraft()
        draftCast.forEach { draft.toggle($0) }
        #expect(draft.selected.map(\.id) == ["cast-0", "cast-1", "cast-2"])
        #expect(draft.pairs.count == 3)
        draft.toggle(draftCast[0])
        #expect(draft.order(of: draftCast[1]) == 1)
        #expect(draft.order(of: draftCast[2]) == 2)
        #expect(draft.pairs.map(\.id) == ["cast-1:cast-2"])
    }

    @Test func removingTheLeadFallsBackToTheFirstSelected() {
        var draft = StoryDraft()
        draft.toggle(draftCast[0])
        draft.toggle(draftCast[1])
        draft.leadID = "cast-0"
        draft.toggle(draftCast[0])
        #expect(draft.leadID == "cast-1")
    }

    @Test func pairRelationshipsSurviveReselection() {
        var draft = StoryDraft()
        draft.toggle(draftCast[0])
        draft.toggle(draftCast[1])
        draft.pairs[0].relationship = .rivals
        draft.toggle(draftCast[2])
        #expect(draft.pairs.first { $0.id == "cast-0:cast-1" }?.relationship == .rivals)
    }

    @Test func changingSettingKeepsEditedRoles() {
        var draft = StoryDraft()
        draft.toggle(draftCast[0])
        draft.toggle(draftCast[1])
        draft.selected[1].role = "Custom"
        draft.changeSetting(.fantasy)
        #expect(draft.selected[0].role == StoryDraft.defaultRole(setting: .fantasy, index: 0))
        #expect(draft.selected[1].role == "Custom")
    }

    @Test func emptyOptionalFieldsFallBackToValidDefaults() throws {
        var draft = StoryDraft()
        draft.toggle(draftCast[0])
        draft.toggle(draftCast[1])
        draft.selected[0].role = ""
        draft.title = " Story "
        draft.participation = .member
        let configuration = draft.configuration(language: "ja")
        try configuration.validate()
        #expect(configuration.title == "Story")
        #expect(!configuration.synopsis.isEmpty)
        #expect(!configuration.userName.isEmpty)
        #expect(!configuration.userRole.isEmpty)
        #expect(configuration.cast.allSatisfy { !$0.role.isEmpty })
        #expect(configuration.leadID == "cast-0")
    }

    @Test func protagonistModeDropsLead() {
        var draft = StoryDraft()
        draft.toggle(draftCast[0])
        draft.title = "Story"
        #expect(draft.configuration(language: "en").leadID == nil)
    }

    // MARK: - あなたはどうする？

    @Test func freeInputTakesPriorityOverSelectedChoice() {
        let scene = StoryScene(index: 1, narration: "N", lines: [], choices: ["A", "B", "C"])
        var draft = StoryActionDraft(choice: 1)
        #expect(draft.intent(in: scene) == "B")
        draft.text = "  My own action  "
        #expect(draft.effectiveChoice == nil)
        #expect(draft.intent(in: scene) == "My own action")
        // 消去すると直前の選択肢に戻る
        draft.text = ""
        #expect(draft.effectiveChoice == 1)
    }

    @Test func whitespaceOnlyInputCannotProceed() {
        let scene = StoryScene(index: 1, narration: "N", lines: [], choices: ["A", "B", "C"])
        let draft = StoryActionDraft(text: "   ")
        #expect(!draft.canProceed)
        #expect(draft.intent(in: scene) == nil)
    }
}
