import SwiftUI

struct RoleplayPersonaSection: View {
    @Binding var persona: RoleplayUserPersona

    var body: some View {
        Section {
            Toggle("roleplay_persona_enabled", isOn: $persona.isEnabled)
                .accessibilityIdentifier("roleplayPersonaEnabled")
            if persona.isEnabled {
                entry("roleplay_persona_name", placeholder: "roleplay_persona_name_hint", text: $persona.name, limit: 80)
                entry("roleplay_persona_age", placeholder: "roleplay_persona_age_hint", text: $persona.age, limit: 40)
                entry("roleplay_persona_role", placeholder: "roleplay_persona_role_hint", text: $persona.role, limit: 200)
                entry("roleplay_persona_personality", placeholder: "roleplay_persona_personality_hint", text: $persona.personality, limit: 800)
                entry("roleplay_persona_relationship", placeholder: "roleplay_persona_relationship_hint", text: $persona.relationship, limit: 400)
                entry("roleplay_persona_background", placeholder: "roleplay_persona_background_hint", text: $persona.background, limit: 1500)
            }
        } header: {
            Label("roleplay_persona_title", systemImage: "person.crop.circle")
        } footer: {
            Text("roleplay_persona_footer")
        }
    }

    private func entry(_ title: LocalizedStringKey, placeholder: LocalizedStringKey,
                       text: Binding<String>, limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: Binding(get: { text.wrappedValue }, set: { text.wrappedValue = String($0.prefix(limit)) }), axis: .vertical)
                .lineLimit(1...5)
                .accessibilityLabel(Text(title))
        }
    }
}

struct RoleplayPersonaSection_Previews: PreviewProvider {
    static var previews: some View {
        Form {
            RoleplayPersonaSection(persona: .constant(RoleplayUserPersona(dictionary: [
                "isEnabled": true, "name": "春", "role": "幼なじみ", "personality": "明るいけれど、少し照れ屋"
            ])))
        }
        .environment(\.locale, Locale(identifier: "ja"))
    }
}
