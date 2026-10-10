import SwiftUI

/// Expanding this view is local UI state only: it never sends a message or changes affinity.
struct InnerThoughtView<Metadata: View>: View {
    let thought: String
    private let metadata: Metadata
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let accent = Color(red: 0.65, green: 0.45, blue: 0.85)

    init(thought: String, initiallyExpanded: Bool = false, @ViewBuilder metadata: () -> Metadata) {
        self.thought = thought
        self.metadata = metadata()
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                metadata
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "heart")
                        Text(LocalizedStringKey(isExpanded ? "roleplay_inner_thought_hide" : "roleplay_inner_thought_show"))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(accent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("innerThoughtToggle")
                .accessibilityValue(Text(LocalizedStringKey(isExpanded ? "roleplay_expanded" : "roleplay_collapsed")))
            }

            if isExpanded {
                Text(thought)
                    .chatMessageFont(sizeOffset: 2)
                    .foregroundStyle(.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(accent.opacity(0.4)).frame(width: 3)
                    }
                    .accessibilityLabel(Text("roleplay_inner_thought_label") + Text(": " + thought))
                    .transition(.opacity)
            }
        }
        .padding(.leading, 4)
    }
}

extension InnerThoughtView where Metadata == EmptyView {
    init(thought: String, initiallyExpanded: Bool = false) {
        self.init(thought: thought, initiallyExpanded: initiallyExpanded) { EmptyView() }
    }
}

struct InnerThoughtView_Previews: PreviewProvider {
    static var previews: some View {
        InnerThoughtView(thought: "来てくれてよかった。もう少し一緒にいたい。")
            .padding()
            .environment(\.locale, Locale(identifier: "ja"))
    }
}
