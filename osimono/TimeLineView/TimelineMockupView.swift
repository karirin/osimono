
import SwiftUI
import Firebase
import FirebaseAuth

// MARK: - Preview Mockup View
struct TimelineMockupView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack {
                Text("9:41")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100")
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 2)
            .foregroundColor(.white)
            .background(Color.black)
            
            // App content
            TimelineView()
        }
        .background(Color(UIColor.systemBackground))
        .ignoresSafeArea(edges: .bottom)
    }
}
