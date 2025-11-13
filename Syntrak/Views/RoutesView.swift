import SwiftUI

struct RoutesView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Routes")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Routes")
        }
    }
}

