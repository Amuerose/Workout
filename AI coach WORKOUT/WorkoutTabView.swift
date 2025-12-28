import SwiftUI

public struct WorkoutTabView: View {
    @State private var store = WorkoutStore()
    @State private var weekDays: [WeekDay] = Self.makeWeek()
    @State private var showChangeMenu: Bool = false
    @State private var showRescheduleSheet: Bool = false
    @State private var showActionConfirm: Bool = false
    @State private var pendingAction: String? = nil

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    sectionToday
                    sectionReadiness
                    sectionWeek
                    sectionPlan
                    sectionQuickActions
                    sectionMarketplace
                }
                .padding(16)
            }
            .background(LinearGradient(colors: [.white, .blue.opacity(0.05)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .navigationTitle("Тренировка")
            .toolbarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showRescheduleSheet) { rescheduleSheet }
        .confirmationDialog("Подтвердить действие", isPresented: $showActionConfirm, titleVisibility: .visible) {
            if pendingAction == "light" { Button("Сделать легче", role: .none) { store.adaptLighter() } }
            if pendingAction == "hard" { Button("Усложнить", role: .none) { store.adaptHarder() } }
            if pendingAction == "move" { Button("Перенести на завтра", role: .none) { store.rescheduleTomorrow() } }
            Button("Отмена", role: .cancel) { pendingAction = nil }
        }
    }

    // MARK: - Sections
    private var sectionToday: some View {
        GlassCard(title: "Сегодняшняя тренировка", icon: "figure.strengthtraining.traditional") {
            let plan = store.todayPlan
            VStack(alignment: .leading, spacing: 8) {
                Text(plan?.title ?? "—").font(.title2).fontWeight(.semibold)
                HStack(spacing: 12) {
                    Label("\(plan?.durationMin ?? 0) мин", systemImage: "clock")
                    Label(plan?.intensity.rawValue ?? "—", systemImage: "bolt")
                    Label(plan?.goal.rawValue ?? "—", systemImage: "target")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                Text(plan?.reason ?? "").font(.subheadline)
                HStack(spacing: 12) {
                    NavigationLink { WorkoutSessionView(store: store) } label: {
                        Label("Начать", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Button { showChangeMenu = true } label: {
                        Label("Изменить", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Menu {
                        Button("Заменить тренировку") { store.replaceToday() }
                        Button("Изменить длительность") { store.changeDuration() }
                        Button("Изменить интенсивность") { store.changeIntensity() }
                        Button("Выбрать другой стиль") { store.changeStyle() }
                    } label: {
                        Image(systemName: "ellipsis.circle").font(.title3)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var sectionReadiness: some View {
        GlassCard(title: "Готовность", icon: "gauge.with.dots") {
            let r = store.readiness
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ReadinessMiniCard(title: "Сон", value: String(format: "%.1f ч", r.sleepHours), systemImage: "bed.double.fill")
                    ReadinessMiniCard(title: "Шаги", value: "\(r.steps)", systemImage: "figure.walk")
                    ReadinessMiniCard(title: "HRV", value: "\(r.hrv) мс", systemImage: "waveform.path.ecg")
                    ReadinessMiniCard(title: "Усталость", value: "\(r.fatigue)/5", systemImage: "tortoise.fill")
                }
                HStack {
                    Label("Готовность: \(r.score)%", systemImage: "chart.bar.xaxis").font(.headline)
                    Spacer()
                    Text(r.score > 70 ? "Можно прогрессировать" : "Работаем мягко").foregroundStyle(.secondary)
                }
            }
        }
    }

    private var sectionWeek: some View {
        GlassCard(title: "План на неделю", icon: "calendar") {
            WeekCalendarView(days: $weekDays) { day in
                // Open day details or editing
                store.selectDay(day)
            }
            HStack {
                Button("Сдвинуть план") {
                    pendingAction = "move"
                    showActionConfirm = true
                }
                .buttonStyle(SecondaryButtonStyle())
                Spacer()
            }
        }
    }

    private var sectionPlan: some View {
        GlassCard(title: "План тренировки", icon: "list.bullet") {
            VStack(spacing: 8) {
                ForEach(store.todayPlan?.exercises ?? []) { item in
                    ExerciseRow(item: item) {
                        store.replaceExercise(item)
                    }
                }
            }
        }
    }

    private var sectionQuickActions: some View {
        GlassCard(title: "Быстрые действия", icon: "bolt.fill") {
            HStack(spacing: 12) {
                Button {
                    pendingAction = "light"
                    showActionConfirm = true
                } label: {
                    Label("Мне тяжело", systemImage: "tortoise.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
                Button {
                    showRescheduleSheet = true
                } label: {
                    Label("Не могу сейчас", systemImage: "calendar.badge.exclamationmark")
                }
                .buttonStyle(SecondaryButtonStyle())
                Button {
                    pendingAction = "hard"
                    showActionConfirm = true
                } label: {
                    Label("Хочу сложнее", systemImage: "flame.fill")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var sectionMarketplace: some View {
        GlassCard(title: "Библиотека и тренеры", icon: "sparkles") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Популярные программы").font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<5, id: \.self) { idx in
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 160, height: 90)
                                Text("Программа #\(idx+1)").font(.subheadline)
                                Text("Цель: \(WorkoutGoal.allCases[idx % WorkoutGoal.allCases.count].rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                Text("Тренеры недели").font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<5, id: \.self) { idx in
                            VStack(alignment: .leading, spacing: 6) {
                                Circle()
                                    .fill(Color.orange.opacity(0.2))
                                    .frame(width: 56, height: 56)
                                    .overlay(Image(systemName: "person.fill").foregroundStyle(.orange))
                                Text("Коуч #\(idx+1)").font(.subheadline)
                            }
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sheets
    private var rescheduleSheet: some View {
        NavigationStack {
            Form {
                Section("Перенос тренировки") {
                    DatePicker("Новое время", selection: $store.rescheduleDate, displayedComponents: .hourAndMinute)
                    Picker("Длительность", selection: $store.rescheduleDuration) {
                        Text("10 мин").tag(10)
                        Text("20 мин").tag(20)
                        Text("30 мин").tag(30)
                    }
                }
            }
            .navigationTitle("Перенести")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        store.rescheduleWorkout(date: store.rescheduleDate, duration: store.rescheduleDuration)
                        showRescheduleSheet = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        showRescheduleSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Helpers
    static private func makeWeek() -> [WeekDay] {
        let cal = Calendar.current
        return (0..<7).map { i in
            let d = cal.date(byAdding: .day, value: i, to: Date())!
            return WeekDay(date: d, state: [.none, .scheduled, .done, .missed].randomElement()!)
        }
    }
}
