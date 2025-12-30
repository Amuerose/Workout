import SwiftUI
import Observation

public struct TodayView: View {
    @State private var store = TodayStore()
    public init() {}
    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GlassCard(title: "Сегодня", icon: "sun.max.fill") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Готовность: \(store.readinessScore())%")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(store.recommendation.title).font(.headline)
                        Text(store.recommendation.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Button("Начать") { store.miniWorkout() }.buttonStyle(PrimaryButtonStyle())
                            Button("Изменить") { store.rescheduleWorkout() }.buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }
                ActivitySummaryCard(store: store)
                HydrationCard(store: store)
            }
            .padding()
        }
        .navigationTitle("Сегодня")
    }
}

#Preview { NavigationStack { TodayView() } }

