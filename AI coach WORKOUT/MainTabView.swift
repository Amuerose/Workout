import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            CoachOnlyView()
                .tabItem { Label("Сегодня", systemImage: "sun.max") }
            NavigationStack { Text("Тренировка") }
                .tabItem { Label("Тренировка", systemImage: "figure.run") }
            NavigationStack { Text("Прогресс") }
                .tabItem { Label("Прогресс", systemImage: "chart.bar") }
            NavigationStack { Text("Настройки") }
                .tabItem { Label("Настройки", systemImage: "gear") }
            NavigationStack { Text("Профиль") }
                .tabItem { Label("Профиль", systemImage: "person.crop.circle") }
        }
    }
}

#Preview { MainTabView() }
