import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            CoachOnlyView()
                .tabItem { Label("Coach", systemImage: "figure.strengthtraining.traditional") }

            TrainingStubView()
                .tabItem { Label("Training", systemImage: "dumbbell") }

            ProgressStubView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }

            SettingsStubView()
                .tabItem { Label("Settings", systemImage: "gearshape") }

            ProfileStubView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}

struct TrainingStubView: View { var body: some View { NavigationStack { Text("Coming soon").navigationTitle("Training") } } }
struct ProgressStubView: View { var body: some View { NavigationStack { Text("Coming soon").navigationTitle("Progress") } } }
struct SettingsStubView: View { var body: some View { NavigationStack { Text("Coming soon").navigationTitle("Settings") } } }
struct ProfileStubView: View { var body: some View { NavigationStack { Text("Coming soon").navigationTitle("Profile") } } }

#Preview { RootTabView() }
