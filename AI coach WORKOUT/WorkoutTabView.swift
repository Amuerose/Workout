import SwiftUI

public struct WorkoutTabView: View {
    public init() {}
    public var body: some View {
        NavigationStack {
            Text("Тренировки").navigationTitle("Тренировка")
        }
    }
}
#Preview { WorkoutTabView() }

