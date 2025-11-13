import SwiftUI

struct CoachingView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Coaching")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Coaching")
        }
    }
}

