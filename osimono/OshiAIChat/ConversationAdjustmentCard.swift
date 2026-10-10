import SwiftUI

/// App guidance is visually separate from the character's chat bubbles and never enters chat history.
struct ConversationAdjustmentCard: View {
    @ObservedObject var store: ConversationAdjustmentStore
    @ObservedObject var viewModel: OshiViewModel
    var isReplyPending: Bool
    private let accent = Color(red: 0.65, green: 0.45, blue: 0.85)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(ConversationAdjustmentText.string("adjustment_app_guidance"), systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(accent)
                Spacer()
                if store.isSaving { ProgressView() }
                Button(action: store.close) { Image(systemName: "xmark").font(.caption) }
                    .accessibilityLabel(ConversationAdjustmentText.string("adjustment_close"))
                    .disabled(store.isSaving)
            }
            if store.selectingItem {
                Text(ConversationAdjustmentText.string("adjustment_select_item")).font(.headline)
                ForEach(ConversationAdjustmentItem.allCases) { item in
                    option(item.title) { store.selectItem(item) }
                }
            } else if let item = store.item {
                Text(item.question(name: viewModel.selectedOshi.name)).font(.headline)
                Text(String(format: ConversationAdjustmentText.string("adjustment_save_hint"), viewModel.selectedOshi.name))
                    .font(.caption).foregroundColor(.secondary)
                option(item.optionTitle(0)) { store.choose(0, viewModel: viewModel) }
                HStack(alignment: .top, spacing: 8) {
                    option(item.optionTitle(1)) { store.choose(1, viewModel: viewModel) }
                    option(item.optionTitle(2)) { store.choose(2, viewModel: viewModel) }
                }
                if item == .length {
                    option(RoleplayReplyLength.standard.title) { store.choose(3, viewModel: viewModel) }
                }
                Button(ConversationAdjustmentText.string("adjustment_later")) { store.later(viewModel: viewModel) }
                    .font(.subheadline).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .disabled(store.isSaving || isReplyPending)
            } else if let notice = store.notice {
                Text(notice).font(.subheadline.weight(.medium))
                if store.undo != nil {
                    Button(ConversationAdjustmentText.string("adjustment_undo")) { store.revert(viewModel: viewModel) }
                        .foregroundColor(accent)
                        .disabled(store.isSaving || isReplyPending)
                }
            }
            if let error = store.error {
                Text(error).font(.caption).foregroundColor(.red)
                // The original options or Undo remain available to retry the same operation.
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(accent.opacity(0.35), lineWidth: 1))
        .padding(.vertical, 12)
        .accessibilityIdentifier("conversationAdjustmentCard")
    }
    private func option(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 8)
                .background(accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .foregroundColor(accent)
        .disabled(store.isSaving || isReplyPending)
    }
}
