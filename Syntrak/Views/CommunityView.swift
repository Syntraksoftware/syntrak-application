import SwiftUI

struct CommunityView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Community")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Community")
        }
    }
}

