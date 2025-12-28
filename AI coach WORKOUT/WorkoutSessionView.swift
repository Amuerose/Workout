import SwiftUI

public struct WorkoutSessionView: View {
    @Bindable var store: WorkoutStore
    @State private var showSummary: Bool = false
    @State private var rpe: Int = 6
    @State private var timer: Timer? = nil

    public init(store: WorkoutStore) { self._store = Bindable(wrappedValue: store) }

    public var body: some View {
        VStack(spacing: 16) {
            header
            timerCard
            currentExerciseCard
            nextExerciseHint
            controls
        }
        .padding(16)
        .background(LinearGradient(colors: [.white, .blue.opacity(0.04)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .navigationTitle("Тренировка")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if store.isSessionActive {
                startTimer()
            } else {
                store.startSession()
                startTimer()
            }
        }
        .onDisappear {
            stopTimer()
            if store.isSessionActive {
                store.endSession()
            }
        }
        .sheet(isPresented: $showSummary) { summarySheet }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if store.isSessionActive && !store.isPaused {
                store.elapsedSec += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private var header: some View {
        HStack {
            Text(title).font(.system(.largeTitle, design: .rounded).weight(.bold))
            Spacer()
            Text(store.stage == .warmup ? "Разминка" : (store.stage == .rest ? "Отдых" : "В работе"))
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var timerCard: some View {
        GlassCard(title: "Таймер", icon: "timer") {
            HStack {
                Text(timeString(store.elapsedSec))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Spacer()
                Button {
                    store.pauseResume()
                    haptic(.light)
                } label: {
                    Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.horizontal, 8)
            .frame(height: 56)
        }
    }

    private var currentExerciseCard: some View {
        GlassCard(title: "Текущее упражнение", icon: "figure.strengthtraining.traditional") {
            let item = currentItem
            VStack(alignment: .leading, spacing: 8) {
                Text(item?.name ?? "—").font(.headline)
                Text(detailString(item)).font(.subheadline).foregroundStyle(.secondary)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(height: 140)
                    .overlay(Text("Визуализация").foregroundStyle(.secondary))
                HStack {
                    Button("Мне тяжело") {
                        store.adaptLighter()
                        haptic(.light)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Spacer()
                    Button("Завершить") {
                        store.endSession()
                        showSummary = true
                        haptic(.medium)
                        stopTimer()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }

    private var nextExerciseHint: some View {
        GlassCard(title: "Далее", icon: "arrow.right.circle") {
            let next = nextItem
            HStack {
                Text(next?.name ?? "—").font(.subheadline)
                Spacer()
                Text(detailString(next)).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                store.previous()
                haptic(.light)
            } label: {
                Label("Назад", systemImage: "backward.fill")
            }
            .buttonStyle(SecondaryButtonStyle())

            Button {
                store.next()
                haptic(.light)
            } label: {
                Label("Далее", systemImage: "forward.fill")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var summarySheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Готово!")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text("Длительность: \(timeString(store.elapsedSec))")
                Text("Выполнено упражнений: \(store.currentIndex + 1)")
                Stepper(value: $rpe, in: 1...10) {
                    Text("Субъективная нагрузка (RPE): \(rpe)")
                }
                Text("Комментарий ИИ: Отличная работа! Продолжим прогрессию завтра.")
                    .foregroundStyle(.secondary)
                Button("Сохранить и обновить план") {
                    showSummary = false
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding()
            .presentationDetents([.medium, .large])
        }
    }

    private var currentItem: WorkoutExerciseItem? {
        store.todayPlan?.exercises.indices.contains(store.currentIndex) == true ? store.todayPlan?.exercises[store.currentIndex] : nil
    }
    private var nextItem: WorkoutExerciseItem? {
        let idx = store.currentIndex + 1
        return store.todayPlan?.exercises.indices.contains(idx) == true ? store.todayPlan?.exercises[idx] : nil
    }

    private var title: String { store.todayPlan?.title ?? "Тренировка" }
    private func timeString(_ sec: Int) -> String {
        let m = sec / 60
        let s = sec % 60
        return String(format: "%02d:%02d", m, s)
    }
    private func detailString(_ item: WorkoutExerciseItem?) -> String {
        guard let item else { return "" }
        var parts: [String] = []
        parts.append("\(item.sets)×\(item.reps)")
        if let d = item.durationSec { parts.append("\(d) сек") }
        return parts.joined(separator: " • ")
    }
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        if #available(iOS 10.0, *) {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
        #endif
    }
}
