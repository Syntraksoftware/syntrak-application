import SwiftUI

struct ExploreView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Explore")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Explore")
        }
    }
}

