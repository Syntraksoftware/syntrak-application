import SwiftUI

struct WorkoutsView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Workouts")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Workouts")
        }
    }
}

