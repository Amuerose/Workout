import SwiftUI
import Observation
import Combine
import Charts

@MainActor
private var globalHealthState: HealthState?
@MainActor
private var globalRoutineState: RoutineState?
@MainActor
private var healthRefreshAction: (() async -> Void)?

private func hapticTap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
#if canImport(UIKit)
    #if os(iOS) || os(tvOS)
    if #available(iOS 10.0, tvOS 10.0, *) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    #endif
#endif
}

// MARK: - Models
struct WorkoutExercise: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var sets: Int
    var reps: Int
}

struct ScheduledWorkout: Identifiable, Hashable {
    let id = UUID()
    var date: Date
    var title: String
    var exercises: [WorkoutExercise]
}

struct UserProfile: Codable, Equatable {
    enum Sex: String, CaseIterable, Identifiable, Codable { case male = "Мужской", female = "Женский"; var id: String { rawValue } }
    var weightKg: Double? = nil
    var heightCm: Double? = nil
    var age: Int? = nil
    var sex: Sex? = nil
    var isComplete: Bool { weightKg != nil && heightCm != nil && age != nil && sex != nil }
}

@Observable
final class AuthState {
    enum Provider: String { case apple, google, facebook }
    var isAuthenticated: Bool = false
    var userName: String? = nil
    var email: String? = nil
    var provider: Provider? = nil

    func signInWithApple() { simulateSignIn(name: "Apple User", email: "user@apple.com", provider: .apple) }
    func signInWithGoogle() { simulateSignIn(name: "Google User", email: "user@gmail.com", provider: .google) }
    func signInWithFacebook() { simulateSignIn(name: "Facebook User", email: "user@facebook.com", provider: .facebook) }
    func signOut() { isAuthenticated = false; userName = nil; email = nil; provider = nil }

    private func simulateSignIn(name: String, email: String, provider: Provider) {
        // TODO: replace with real SDK integrations
        withAnimation(.spring) {
            self.userName = name
            self.email = email
            self.provider = provider
            self.isAuthenticated = true
        }
    }
}

enum DayStatus: String, CaseIterable { case ready = "Готов к тренировке", light = "Лучше легко", restOK = "Отдых допустим" }

enum TrainingLength: String, CaseIterable { case fiveToTen = "5–10 мин", tenToTwenty = "10–20 мин", any = "не важно" }

enum DayPart: String, CaseIterable { case morning = "утро", day = "день", evening = "вечер" }

@Observable
final class TodayState {
    var date: Date = Date()
    var status: DayStatus = .ready
    var recommended: (minutes: Int, intensity: String) = (12, "лёгкая")
    var aiShortLine: String = "Начни с малого — 5 минут уже победа."
    var isHeavyMode: Bool = false
    func applyHeavyMode() {
        isHeavyMode = true
        status = .light
        recommended = (max(5, min(recommended.minutes, 10)), "очень лёгкая")
        aiShortLine = "Сегодня достаточно просто двигаться."
    }
}

@Observable
final class PlanSettingsState {
    var selectedDays: Set<Int> = [1,3,5]
    var dayPart: DayPart = .morning
    var length: TrainingLength = .fiveToTen
    var reminderEnabled: Bool = true
    var reminderTime: Date = {
        var comps = DateComponents(); comps.hour = 9; comps.minute = 0
        return Calendar.current.date(from: comps) ?? Date()
    }()
    var disableForToday: Bool = false
}

// MARK: - App State
@Observable
final class WorkoutState {
    var isActive: Bool = false
    var currentExerciseIndex: Int = 0
    var completedSetsForCurrent: Int = 0
    var plan: [WorkoutExercise] = [
        WorkoutExercise(name: "Отжимания", sets: 3, reps: 12),
        WorkoutExercise(name: "Приседания", sets: 3, reps: 15),
        WorkoutExercise(name: "Планка (сек)", sets: 3, reps: 45)
    ]
    var schedule: [ScheduledWorkout] = []

    var currentExercise: WorkoutExercise? {
        guard plan.indices.contains(currentExerciseIndex) else { return nil }
        return plan[currentExerciseIndex]
    }

    func startWorkout() { isActive = true; currentExerciseIndex = 0; completedSetsForCurrent = 0 }
    func reset() { isActive = false; currentExerciseIndex = 0; completedSetsForCurrent = 0 }

    func nextSet() {
        guard let ex = currentExercise else { return }
        if completedSetsForCurrent + 1 >= ex.sets {
            completedSetsForCurrent = 0
            currentExerciseIndex += 1
            if currentExercise == nil { isActive = false }
        } else {
            completedSetsForCurrent += 1
        }
    }
}

@Observable
final class AIChatState {
    struct Message: Identifiable, Hashable { let id = UUID(); let isUser: Bool; var text: String }
    var messages: [Message] = [.init(isUser: false, text: "Привет! Я твой ИИ‑коуч. Чем могу помочь сегодня?")]
    var draft: String = ""
    var isSending: Bool = false

    private let service: AppAIStubServiceProtocol
    init(service: AppAIStubServiceProtocol = AppAIStubService()) { self.service = service }

    func send() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(.init(isUser: true, text: trimmed))
        draft = ""
        Task { await requestAIResponse() }
    }

    @MainActor
    private func requestAIResponse() async {
        isSending = true
        defer { isSending = false }
        do {
            let reply = try await service.completeChat(messages: messages.map { AppAIStubChatMessage(role: $0.isUser ? "user" : "assistant", content: $0.text) })
            messages.append(.init(isUser: false, text: reply))
        } catch {
            messages.append(.init(isUser: false, text: "Ошибка запроса к ИИ: \(error.localizedDescription)"))
        }
    }
}

// MARK: - Root ContentView
struct ContentView: View {
    @State private var workout = WorkoutState()
    @State private var chat = AIChatState()
    @State private var selected: Tab = .today
    @State private var today = TodayState()
    @State private var planSettings = PlanSettingsState()
    @State private var auth = AuthState()

    // Added new states
    @State private var routine = RoutineState()
    @State private var health = HealthState()

    enum Tab { case today, workout, progress, settings, profile }

    var body: some View {
        Group {
            if auth.isAuthenticated {
                TabView(selection: $selected) {
                    TodayViewWrapper()
                    .tabItem { Label("Сегодня", systemImage: "house.fill") }
                    .tag(Tab.today)

                    WorkoutTabView()
                        .tabItem { Label("Тренировка", systemImage: "play.circle") }
                        .tag(Tab.workout)

                    ProgressScreen()
                        .tabItem { Label("Прогресс", systemImage: "chart.line.uptrend.xyaxis") }
                        .tag(Tab.progress)

                    CoachSettingsView()
                        .tabItem { Label("Настройки", systemImage: "gearshape") }
                        .tag(Tab.settings)

                    ProfileScreen(auth: auth)
                        .tabItem { Label("Профиль", systemImage: "person.crop.circle") }
                        .tag(Tab.profile)
                }
                .onAppear {
                    Task {
                        healthRefreshAction = {
                            await health.requestAuthorization()
                            await health.refresh()
                        }
                        globalHealthState = health
                        globalRoutineState = routine

                        // Adjust today status based on health data after small delay
                        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s delay
                        await MainActor.run {
                            if health.lastNightSleepHours < globalRoutineState?.sleepGoalHours ?? 8.0 {
                                today.status = .light
                                today.recommended = (max(5, min(today.recommended.minutes, 10)), "лёгкая")
                                today.aiShortLine = "Недосып — сделаем щадящую сессию."
                            }
                        }
                    }
                }
                .task {
                    // In case we want continuous update or future extension
                }
            } else {
                AuthScreen(auth: auth)
            }
        }
        .tint(.accentColor)
    }
}

// MARK: - Screens

private struct AuthScreen: View {
    @Bindable var auth: AuthState
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "figure.walk.circle.fill")
                    .resizable().scaledToFit().frame(width: 100, height: 100)
                    .foregroundStyle(.secondary)
                Text("Вход в аккаунт")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Продолжайте через удобный сервис")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VStack(spacing: 12) {
                    Button { auth.signInWithApple() } label: { Label("Войти с Apple", systemImage: "applelogo") }
                        .buttonStyle(.borderedProminent)
                    Button { auth.signInWithGoogle() } label: { Label("Войти с Google", systemImage: "g.circle.fill") }
                        .buttonStyle(.bordered)
                    Button { auth.signInWithFacebook() } label: { Label("Войти с Facebook", systemImage: "f.cursive.circle.fill") }
                        .buttonStyle(.bordered)
                }
                .padding(.top, 8)
                Spacer()
                Text("Нажимая вход, вы соглашаетесь с правилами использования")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Вход")
        }
    }
}

private struct TodayScreen: View {
    @Bindable var today: TodayState
    var onStart: () -> Void
    var onChange: () -> Void
    var onSkip: () -> Void
    var onHeavyMode: () -> Void
    @Bindable var chat: AIChatState
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Text(Date(), style: .date)
                        .font(.subheadline)
                    Spacer()
                    Button {
                        chat.draft = "Нужна короткая поддержка на сегодня одним предложением."
                        chat.send()
                    } label: {
                        Label("Обновить строку от ИИ", systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)
                    .labelStyle(.titleAndIcon)
                    Button {
                        Task {
                            await healthRefreshAction?()
                        }
                    } label: {
                        Label("Обновить здоровье", systemImage: "heart.fill")
                    }
                    .buttonStyle(.bordered)
                    .labelStyle(.titleAndIcon)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(today.status.rawValue)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .transition(.opacity)
                        .id(today.status)
                    Text("Рекомендация: \(today.recommended.minutes) мин • \(today.recommended.intensity)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let health = globalHealthState {
                        Text("Шаги сегодня: \(Int(health.stepsToday)) • Сон: \(String(format: "%.1f", health.lastNightSleepHours)) ч")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text(today.aiShortLine)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                HStack {
                    Button(action: {
                        hapticTap(.medium)
                        withAnimation(.spring) { onStart() }
                    }) {
                        Label("Начать", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .labelStyle(.titleAndIcon)
                    Button(action: {
                        hapticTap(.light)
                        onChange()
                    }) {
                        Label("Изменить", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(.bordered)
                    .labelStyle(.titleAndIcon)
                }
                Button(action: {
                    hapticTap(.light)
                    withAnimation(.easeInOut) { onSkip() }
                }) {
                    Label("Пропустить без чувства вины", systemImage: "zzz")
                }
                .buttonStyle(.bordered)
                .labelStyle(.titleAndIcon)
                Button(action: {
                    withAnimation(.spring) {
                        hapticTap(.light)
                        onHeavyMode()
                    }
                }) {
                    Label("Мне тяжело", systemImage: "tortoise")
                }
                .buttonStyle(.bordered)
                .labelStyle(.titleAndIcon)
                .tint(.orange)

                VStack(alignment: .leading, spacing: 8) {
                    Text("ИИ поддержка").font(.headline)
                    ForEach(chat.messages.suffix(2)) { msg in
                        Text(msg.text)
                            .padding(10)
                            .background(msg.isUser ? .thinMaterial : .ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
            }
            .padding()
            .navigationTitle("Сегодня")
        }
    }
}

struct TodayViewWrapper: View {
    @AppStorage("ai_mode") private var aiMode: String = "mock"
    @StateObject private var coachStore = TodayCoachStore()
    @State private var aiNoticeBanner: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            if let banner = aiNoticeBanner {
                Text(banner)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial)
            }
            TodayView()
        }
        .onAppear { coachStore.bindAIModeBanner($aiNoticeBanner) }
    }
}

private struct WorkoutScreen: View {
    @Bindable var workout: WorkoutState
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if workout.isActive, let ex = workout.currentExercise {
                    WorkoutExerciseView(exercise: ex)

                    HStack {
                        Button("Завершить подход") {
                            hapticTap(.medium)
                            withAnimation(.spring) { workout.nextSet() }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Сброс", role: .destructive) {
                            hapticTap(.light)
                            withAnimation(.easeInOut) { workout.reset() }
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("Готов к тренировке?")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Button("Начать") { workout.startWorkout() }.buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }

                PlanCard(plan: workout.plan)
                Spacer()
            }
            .padding()
            .navigationTitle("Воркаут")
        }
    }
}

private struct PlanScreen: View {
    @Bindable var workout: WorkoutState
    var body: some View {
        NavigationStack {
            ScrollView {
                PlanCard(plan: workout.plan)
                    .padding()
            }
            .navigationTitle("План")
        }
    }
}

private struct ScheduleScreen: View {
    @Bindable var workout: WorkoutState
    @State private var selectedDate: Date = Date()
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker("Дата", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                Button("Добавить тренировку") {
                    let item = ScheduledWorkout(date: selectedDate, title: "Тренировка", exercises: workout.plan)
                    workout.schedule.append(item)
                }.buttonStyle(.borderedProminent)

                if workout.schedule.isEmpty {
                    Text("Нет запланированных тренировок").foregroundStyle(.secondary)
                } else {
                    List(workout.schedule.sorted { $0.date < $1.date }) { item in
                        VStack(alignment: .leading) {
                            HStack { Text(item.date, style: .date); Spacer(); Text(item.date, style: .time).foregroundStyle(.secondary) }
                            Text(item.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Расписание")
        }
    }
}

private struct CoachScreen: View {
    @Bindable var chat: AIChatState
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(chat.messages) { msg in
                                HStack {
                                    if msg.isUser { Spacer() }
                                    Text(msg.text)
                                        .padding(12)
                                        .background(msg.isUser ? .thinMaterial : .ultraThinMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                    if !msg.isUser { Spacer() }
                                }
                                .id(msg.id)
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: chat.messages.count) { _, _ in
                        if let last = chat.messages.last?.id { withAnimation { proxy.scrollTo(last, anchor: .bottom) } }
                    }
                }
                Divider().opacity(0.2)
                HStack(spacing: 8) {
                    TextField("Сообщение коучу", text: $chat.draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.send)
                        .onSubmit { chat.send() }
                    Button { chat.send() } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .disabled(chat.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if chat.isSending { ProgressView() }
                }
                .padding()
                .background(.thinMaterial)
            }
            .navigationTitle("ИИ‑коуч")
        }
    }
}

private struct ProgressScreen: View {
    enum Period: String, CaseIterable, Identifiable { case week = "Неделя", month = "Месяц", year = "Год", all = "Всё время"; var id: String { rawValue } }

    @State private var period: Period = .week

    // Mocked metrics (replace with HealthKit-backed values)
    @State private var stepsSeries: [(date: Date, value: Int)] = []
    @State private var caloriesSeries: [(date: Date, value: Int)] = []
    @State private var weightSeries: [(date: Date, value: Double)] = []
    @State private var sleepSeries: [(date: Date, value: Double)] = []
    @State private var workoutsDone: Int = 3
    @State private var workoutsGoal: Int = 5
    @State private var activeCaloriesToday: Double = 420
    @State private var activeCaloriesGoal: Double = 600
    @State private var streakDays: Int = 7
    @State private var stabilityIndex: Int = 78 // регулярность, %

    // Comparisons
    @State private var stepsVsLastWeek: Int = 12 // %
    @State private var stepsVsLastMonth: Int = 5 // %

    init() {
        // Seed demo data based on selected period (default week)
        _stepsSeries = State(initialValue: Self.makeIntSeries(days: 7, base: 4500, jitter: 2000))
        _caloriesSeries = State(initialValue: Self.makeIntSeries(days: 7, base: 350, jitter: 220))
        _weightSeries = State(initialValue: Self.makeDoubleSeries(days: 30, base: 74.5, drift: -0.02, jitter: 0.15))
        _sleepSeries = State(initialValue: Self.makeDoubleSeries(days: 7, base: 7.2, drift: 0.0, jitter: 0.6))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Period filter
                    AppCard(title: "Период", icon: "calendar") {
                        Picker("Период", selection: $period) {
                            ForEach(Period.allCases) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: period) { _, newValue in
                            withAnimation(.easeInOut) { updateSeries(for: newValue) }
                        }
                    }

                    // Summary rings and key KPIs
                    AppCard(title: "Сегодня", icon: "gauge.medium") {
                        HStack(spacing: 16) {
                            VStack {
                                // Active calories ring
                                ProgressView(value: min(activeCaloriesToday / max(activeCaloriesGoal, 1), 1)) {
                                    Text("Калории")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } currentValueLabel: {
                                    Text("\(Int(activeCaloriesToday))/\(Int(activeCaloriesGoal))")
                                        .font(.headline)
                                }
                                .progressViewStyle(.circular)
                            }
                            VStack {
                                // Workouts ring
                                ProgressView(value: Double(workoutsDone), total: Double(workoutsGoal)) {
                                    Text("Тренировки")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } currentValueLabel: {
                                    Text("\(workoutsDone)/\(workoutsGoal)")
                                        .font(.headline)
                                }
                                .progressViewStyle(.circular)
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Label("Стрик: \(streakDays) дн.", systemImage: "flame.fill")
                                    .font(.headline)
                                Label("Стабильность: \(stabilityIndex)%", systemImage: "chart.bar.xaxis")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Steps bar chart
                    AppCard(title: "Шаги", icon: "figure.walk") {
                        Chart(stepsSeries, id: \.date) { point in
                            BarMark(
                                x: .value("Дата", point.date),
                                y: .value("Шаги", point.value)
                            )
                            .foregroundStyle(.tint)
                        }
                        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 7)) }
                        .frame(height: 180)
                        HStack {
                            Image(systemName: stepsVsLastWeek >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .foregroundStyle(stepsVsLastWeek >= 0 ? .green : .orange)
                            Text("к прошлой неделе: \(stepsVsLastWeek)% • к прошлому месяцу: \(stepsVsLastMonth)%")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }

                    // Sleep line chart
                    AppCard(title: "Сон", icon: "bed.double.fill") {
                        Chart(sleepSeries, id: \.date) { point in
                            LineMark(
                                x: .value("Дата", point.date),
                                y: .value("Часы", point.value)
                            )
                            .foregroundStyle(.blue)
                            AreaMark(
                                x: .value("Дата", point.date),
                                y: .value("Часы", point.value)
                            )
                            .foregroundStyle(.blue.opacity(0.2))
                        }
                        .frame(height: 180)
                        Text("Средний сон: \(String(format: "%.1f", average(sleepSeries))) ч")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Weight goal progress and trend
                    AppCard(title: "Вес", icon: "scalemass") {
                        Chart(weightSeries, id: \.date) { point in
                            LineMark(
                                x: .value("Дата", point.date),
                                y: .value("Вес", point.value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(.pink)
                        }
                        .frame(height: 180)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Текущий: \(String(format: "%.1f", weightSeries.last?.value ?? 0)) кг")
                                .font(.headline)
                            ProgressView(value: 0.45) { Text("Прогресс к цели") } currentValueLabel: { Text("45%") }
                                .progressViewStyle(.linear)
                        }
                    }

                    // Calories weekly trend
                    AppCard(title: "Активные калории", icon: "flame.fill") {
                        Chart(caloriesSeries, id: \.date) { point in
                            LineMark(x: .value("Дата", point.date), y: .value("Ккал", point.value))
                                .foregroundStyle(.orange)
                            PointMark(x: .value("Дата", point.date), y: .value("Ккал", point.value))
                                .foregroundStyle(.orange)
                        }
                        .frame(height: 160)
                    }

                    // Achievements badges
                    AppCard(title: "Достижения", icon: "rosette") {
                        HStack(spacing: 12) {
                            BadgeView(title: "7 дней подряд", system: "flame.fill", color: .orange)
                            BadgeView(title: "+10% шагов", system: "figure.walk", color: .green)
                            BadgeView(title: "5 тренировок", system: "dumbbell", color: .blue)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Прогресс")
        }
    }

    // MARK: - Helpers
    static func makeIntSeries(days: Int, base: Int, jitter: Int) -> [(date: Date, value: Int)] {
        let cal = Calendar.current
        return (0..<days).map { i in
            let d = cal.date(byAdding: .day, value: -((days - 1) - i), to: Date())!
            let v = max(0, base + Int.random(in: -jitter...jitter))
            return (date: d, value: v)
        }
    }

    static func makeDoubleSeries(days: Int, base: Double, drift: Double, jitter: Double) -> [(date: Date, value: Double)] {
        let cal = Calendar.current
        var values: [(date: Date, value: Double)] = []
        var current = base
        for i in 0..<days {
            let d = cal.date(byAdding: .day, value: -((days - 1) - i), to: Date())!
            current += drift + Double.random(in: -jitter...jitter)
            values.append((date: d, value: max(0, current)))
        }
        return values
    }

    func average(_ series: [(date: Date, value: Double)]) -> Double {
        guard !series.isEmpty else { return 0 }
        return series.map { $0.value }.reduce(0, +) / Double(series.count)
    }

    func updateSeries(for period: Period) {
        switch period {
        case .week:
            stepsSeries = Self.makeIntSeries(days: 7, base: 5000, jitter: 220)
            caloriesSeries = Self.makeIntSeries(days: 7, base: 380, jitter: 60)
            sleepSeries = Self.makeDoubleSeries(days: 7, base: 7.2, drift: 0.0, jitter: 0.6)
        case .month:
            stepsSeries = Self.makeIntSeries(days: 30, base: 5200, jitter: 900)
            caloriesSeries = Self.makeIntSeries(days: 30, base: 390, jitter: 120)
            sleepSeries = Self.makeDoubleSeries(days: 30, base: 7.1, drift: 0.0, jitter: 0.7)
        case .year:
            stepsSeries = Self.makeIntSeries(days: 52, base: 5600, jitter: 1400)
            caloriesSeries = Self.makeIntSeries(days: 52, base: 400, jitter: 160)
            sleepSeries = Self.makeDoubleSeries(days: 52, base: 7.0, drift: 0.0, jitter: 0.8)
        case .all:
            stepsSeries = Self.makeIntSeries(days: 100, base: 5300, jitter: 1500)
            caloriesSeries = Self.makeIntSeries(days: 100, base: 395, jitter: 180)
            sleepSeries = Self.makeDoubleSeries(days: 100, base: 7.0, drift: 0.0, jitter: 0.9)
        }
    }
}

private struct BadgeView: View {
    let title: String
    let system: String
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: system)
                .symbolRenderingMode(.hierarchical)
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundStyle(color)
    }
}

// Fallback stubs (will be ignored if real implementations are above)
struct AppCard<Content: View>: View {
    let title: String?
    let icon: String?
    @ViewBuilder var content: Content
    init(title: String? = nil, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { Text(title).font(.caption).foregroundStyle(.secondary) }
            content
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct PlanCard: View { 
    var plan: [WorkoutExercise]
    var body: some View { 
        VStack { 
            Text("План").font(.headline)
            Divider().opacity(0.1)
            ForEach(plan) { Text($0.name) }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    } 
}

struct WorkoutExerciseView: View { 
    var exercise: WorkoutExercise
    var body: some View { 
        VStack { Text(exercise.name).font(.headline) }
    }
}

struct NewTodayScreen: View { 
    var body: some View { 
        NavigationStack { 
            ScrollView { 
                VStack(spacing: 16) { 
                    AppCard(title: "Совет дня") { Text("Placeholder") } 
                }
                .padding() 
            }
            .navigationTitle("Сегодня") 
        } 
    } 
}

struct NewWorkoutsScreen: View { 
    var body: some View { 
        NavigationStack { 
            List { Text("Тренировка 1") } 
            .navigationTitle("Тренировки") 
        } 
    } 
}

struct SettingsScreen: View { 
    @Bindable var plan: PlanSettingsState
    var body: some View { 
        NavigationStack { 
            Form { Text("Настройки") } 
            .navigationTitle("Настройки") 
        } 
    } 
}

// Replaced ProfileScreen with enhanced UI per instructions
struct ProfileScreen: View {
    @Bindable var auth: AuthState

    // Editing
    @State private var editingName: String = ""
    @State private var editingEmail: String = ""
    @State private var showEditSheet: Bool = false
    @State private var showSignOutConfirm: Bool = false

    // Personal data
    @State private var sex: UserProfile.Sex? = .male
    @State private var age: Int = 28
    @State private var heightCm: Double = 178
    @State private var weightKg: Double = 74.5

    // Goals
    @State private var weeklyWorkoutsGoal: Int = 5
    @State private var weightGoalKg: Double = 72
    @State private var sleepGoalHours: Double = 7.5

    // Preferences
    @State private var notificationsOn: Bool = true
    @State private var newsletterOn: Bool = false
    @State private var shareActivityWithFriends: Bool = false

    // Devices & Connections
    @State private var appleWatchConnected: Bool = true
    @State private var bluetoothHeadphones: Bool = true
    @State private var calendarConnected: Bool = false

    // Data management
    @State private var isExporting: Bool = false
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().fill(Color.secondary.opacity(0.15)).frame(width: 64, height: 64)
                            Image(systemName: "person.crop.circle.fill").font(.system(size: 48)).foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(auth.userName ?? "Без имени")
                                .font(.headline)
                            Text(auth.email ?? "Нет email")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let provider = auth.provider {
                                Label(providerTitle(provider), systemImage: providerIcon(provider))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button { prepareEdit() } label: { Image(systemName: "pencil").imageScale(.large) }
                            .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }

                // Quick actions
                Section("Быстрые действия") {
                    Button { /* navigate to plan or open training */ } label: { Label("Начать тренировку", systemImage: "play.fill") }
                    Button { /* open coach */ } label: { Label("Спросить ИИ‑коуча", systemImage: "sparkles") }
                }

                // Personal data
                Section("Личные данные") {
                    Picker("Пол", selection: Binding(get: { sex ?? .male }, set: { sex = $0 })) {
                        ForEach(UserProfile.Sex.allCases) { s in Text(s.rawValue).tag(s) }
                    }
                    Stepper(value: $age, in: 10...100) { HStack { Text("Возраст"); Spacer(); Text("\(age)") } }
                    HStack {
                        Label("Рост", systemImage: "ruler")
                        Spacer()
                        TextField("Рост", value: $heightCm, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("см").foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Вес", systemImage: "scalemass")
                        Spacer()
                        TextField("Вес", value: $weightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("кг").foregroundStyle(.secondary)
                    }
                }

                // Goals
                Section("Цели") {
                    Stepper(value: $weeklyWorkoutsGoal, in: 1...14) { HStack { Text("Тренировок в неделю"); Spacer(); Text("\(weeklyWorkoutsGoal)") } }
                    HStack {
                        Label("Целевой вес", systemImage: "target")
                        Spacer()
                        TextField("Цель", value: $weightGoalKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("кг").foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Сон", systemImage: "bed.double.fill")
                        Spacer()
                        TextField("Сон", value: $sleepGoalHours, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("ч").foregroundStyle(.secondary)
                    }
                }

                // Preferences
                Section("Предпочтения") {
                    Toggle(isOn: $notificationsOn) { Label("Уведомления", systemImage: "bell.fill") }
                    Toggle(isOn: $newsletterOn) { Label("Новости и советы по email", systemImage: "envelope.fill") }
                    Toggle(isOn: $shareActivityWithFriends) { Label("Делиться активностью с друзьями", systemImage: "person.2.fill") }
                }

                // Devices & connections
                Section("Устройства и подключения") {
                    Toggle(isOn: $appleWatchConnected) { Label("Apple Watch", systemImage: "applewatch") }
                    Toggle(isOn: $bluetoothHeadphones) { Label("Bluetooth‑наушники", systemImage: "headphones") }
                    Toggle(isOn: $calendarConnected) { Label("Календарь", systemImage: "calendar") }
                }

                // Data management
                Section("Данные") {
                    Button {
                        isExporting = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { isExporting = false }
                    } label: {
                        if isExporting { HStack { ProgressView(); Text("Экспортируем...") } } else { Label("Экспорт данных", systemImage: "square.and.arrow.up") }
                    }
                    Button(role: .destructive) { showDeleteConfirm = true } label: { Label("Удалить аккаунт", systemImage: "trash") }
                }

                // Sign out
                Section {
                    Button(role: .destructive) { showSignOutConfirm = true } label: {
                        Label("Выйти из аккаунта", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Профиль")
            .sheet(isPresented: $showEditSheet) {
                NavigationStack {
                    Form {
                        Section("Профиль") {
                            TextField("Имя", text: $editingName)
                            TextField("Email", text: $editingEmail)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                    }
                    .navigationTitle("Редактировать")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Отмена") { showEditSheet = false } }
                        ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { applyEdit() }.disabled(editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                    }
                }
            }
            .alert("Выйти из аккаунта?", isPresented: $showSignOutConfirm) {
                Button("Выйти", role: .destructive) { auth.signOut() }
                Button("Отмена", role: .cancel) { }
            } message: { Text("Вы сможете войти снова в любое время.") }
            .alert("Удалить аккаунт?", isPresented: $showDeleteConfirm) {
                Button("Удалить", role: .destructive) { /* hook delete flow */ }
                Button("Отмена", role: .cancel) { }
            } message: { Text("Это действие необратимо. Все данные будут удалены.") }
        }
    }

    private func prepareEdit() {
        editingName = auth.userName ?? ""
        editingEmail = auth.email ?? ""
        showEditSheet = true
    }

    private func applyEdit() {
        auth.userName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        auth.email = editingEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        showEditSheet = false
    }

    private func providerTitle(_ p: AuthState.Provider) -> String {
        switch p { case .apple: return "Apple ID"; case .google: return "Google"; case .facebook: return "Facebook" }
    }
    private func providerIcon(_ p: AuthState.Provider) -> String {
        switch p { case .apple: return "applelogo"; case .google: return "g.circle.fill"; case .facebook: return "f.cursive.circle.fill" }
    }
}

// MARK: - CoachSettingsView and supporting views

struct CoachSettingsView: View {
    // MARK: - Plan Settings
    @State private var selectedDays: Set<Int> = [2,4,6]
    @State private var workoutTime: Date = {
        var comps = DateComponents(); comps.hour = 8; comps.minute = 30
        return Calendar.current.date(from: comps) ?? Date()
    }()
    enum WorkoutType: String, CaseIterable, Identifiable { case cardio = "Кардио", strength = "Силовые", mobility = "Мобилити", mixed = "Смешанные"; var id: String { rawValue } }
    @State private var workoutTypes: Set<WorkoutType> = [.mixed]
    enum Difficulty: String, CaseIterable, Identifiable { case easy = "Лёгкий", normal = "Средний", hard = "Сложный", adaptive = "Адаптивный"; var id: String { rawValue } }
    @State private var difficulty: Difficulty = .adaptive

    // MARK: - Notifications
    @State private var remindersOn: Bool = true
    @State private var motivationOn: Bool = true
    @State private var progressUpdatesOn: Bool = true
    @State private var quietHoursOn: Bool = false
    @State private var quietStart: Date = { var comps = DateComponents(); comps.hour = 22; return Calendar.current.date(from: comps) ?? Date() }()
    @State private var quietEnd: Date = { var comps = DateComponents(); comps.hour = 7; return Calendar.current.date(from: comps) ?? Date() }()

    // MARK: - User Assistance
    @State private var showRescheduleSheet: Bool = false

    // MARK: - Location
    @State private var gpsTrackingOn: Bool = false

    // MARK: - Integrations
    @State private var watchSyncOn: Bool = true
    @State private var healthKitSharingOn: Bool = true
    @State private var calendarSyncOn: Bool = false
    @State private var musicPlaybackOn: Bool = true

    // MARK: - AI Personalization
    enum CoachTone: String, CaseIterable, Identifiable { case friendly = "Дружелюбный", neutral = "Нейтральный", strict = "Строгий"; var id: String { rawValue } }
    @State private var tone: CoachTone = .friendly
    enum Voice: String, CaseIterable, Identifiable { case none = "Без голоса", alto = "Альто", tenor = "Тенор", baritone = "Баритон"; var id: String { rawValue } }
    @State private var voice: Voice = .none
    @State private var encouragementFreq: Double = 0.5

    // AI Mode
    // Inserted new Section here as per instruction
    // 7. Display & Units comes after this

    // MARK: - Display & Units
    @State private var darkModeOn: Bool = false
    enum Language: String, CaseIterable, Identifiable { case system = "Системный", ru = "Русский", en = "English", es = "Español"; var id: String { rawValue } }
    @State private var language: Language = .system
    enum Units: String, CaseIterable, Identifiable { case metric = "Метрические", imperial = "Имперские"; var id: String { rawValue } }
    @State private var units: Units = .metric

    // MARK: - Account & Sync
    @State private var userName: String = "Иван"
    @State private var email: String = "ivan@example.com"
    @State private var iCloudSyncOn: Bool = true
    @State private var isBackingUp: Bool = false

    // MARK: - About
    private let appVersion = "1.0.0 (100)"

    // MARK: - Privacy & Permissions
    @State private var analyticsOn: Bool = false
    @State private var permissions: [(title: String, granted: Bool, systemSymbol: String)] = [
        ("Геолокация", false, "location"),
        ("HealthKit", true, "heart.fill"),
        ("Уведомления", true, "bell.badge.fill"),
        ("Календарь", false, "calendar")
    ]

    var body: some View {
        NavigationStack {
            Form {
                // 1. Plan Settings
                Section("План тренировок") {
                    DaysOfWeekInlinePicker(selectedDays: $selectedDays)
                    DatePicker("Время тренировки", selection: $workoutTime, displayedComponents: .hourAndMinute)
                    NavigationLink {
                        List(WorkoutType.allCases, id: \.self) { type in
                            MultipleSelectionRow(title: type.rawValue, isOn: workoutTypes.contains(type)) {
                                if workoutTypes.contains(type) { workoutTypes.remove(type) } else { workoutTypes.insert(type) }
                            }
                        }
                        .navigationTitle("Типы тренировок")
                    } label: {
                        HStack {
                            Label("Типы тренировок", systemImage: "dumbbell")
                            Spacer()
                            Text(workoutTypes.isEmpty ? "Не выбрано" : workoutTypes.map { $0.rawValue }.joined(separator: ", "))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Picker("Сложность", selection: $difficulty) {
                        ForEach(Difficulty.allCases) { level in Text(level.rawValue).tag(level) }
                    }
                }

                // 2. Notifications
                Section("Уведомления") {
                    Toggle(isOn: $remindersOn) { Label("Напоминания о тренировках", systemImage: "bell.fill") }
                    Toggle(isOn: $motivationOn) { Label("Мотивационные сообщения", systemImage: "sparkles") }
                    Toggle(isOn: $progressUpdatesOn) { Label("Обновления прогресса", systemImage: "chart.line.uptrend.xyaxis") }
                    Toggle("Тихие часы", isOn: $quietHoursOn)
                    if quietHoursOn {
                        HStack {
                            DatePicker("С", selection: $quietStart, displayedComponents: .hourAndMinute)
                            DatePicker("До", selection: $quietEnd, displayedComponents: .hourAndMinute)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                // 3. User Assistance
                Section("Помощь пользователю") {
                    Button { difficulty = .easy } label: { Label("Мне тяжело", systemImage: "tortoise.fill") }
                    Button { difficulty = .easy } label: { Label("Хочу проще", systemImage: "figure.cooldown") }
                    Button { showRescheduleSheet = true } label: { Label("Не могу сейчас", systemImage: "calendar.badge.exclamationmark") }
                }

                // 4. Location
                Section("Местоположение") {
                    Toggle(isOn: $gpsTrackingOn) { Label("GPS-трекинг", systemImage: "location.fill") }
                    Link(destination: URL(string: UIApplication.openSettingsURLString)!) { Label("Системные настройки геолокации", systemImage: "gearshape") }
                }

                // 5. Integrations
                Section("Интеграции") {
                    Toggle(isOn: $watchSyncOn) { Label("Синхронизация с Apple Watch", systemImage: "applewatch") }
                    Toggle(isOn: $healthKitSharingOn) { Label("Обмен данными HealthKit", systemImage: "heart.fill") }
                    Toggle(isOn: $calendarSyncOn) { Label("Синхронизация календаря", systemImage: "calendar") }
                    Toggle(isOn: $musicPlaybackOn) { Label("Музыка во время тренировок", systemImage: "music.note") }
                }

                // AI Mode
                Section("ИИ") {
                    Picker("Режим", selection: Binding(get: { UserDefaults.standard.string(forKey: "ai_mode") == "live" ? "live" : "mock" }, set: { UserDefaults.standard.set($0, forKey: "ai_mode") })) {
                        Text("Mock").tag("mock")
                        Text("Live").tag("live")
                    }
                    .pickerStyle(.segmented)
                    Text("Live требует активного биллинга. При ошибке приложение автоматически перейдёт в Mock.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // 7. Display & Units
                Section("Отображение и единицы") {
                    Toggle(isOn: $darkModeOn) { Label("Тёмная тема", systemImage: "moon.fill") }
                    Picker("Язык приложения", selection: $language) { ForEach(Language.allCases) { lang in Text(lang.rawValue).tag(lang) } }
                    Picker("Единицы измерения", selection: $units) { ForEach(Units.allCases) { u in Text(u.rawValue).tag(u) } }
                }

                // 8. Account & Sync
                Section("Аккаунт и синхронизация") {
                    HStack {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 36)).foregroundStyle(.secondary)
                        VStack(alignment: .leading) { Text(userName).font(.headline); Text(email).font(.subheadline).foregroundStyle(.secondary) }
                        Spacer()
                        NavigationLink { Text("Профиль (редактирование)") } label: { Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
                    }
                    Toggle(isOn: $iCloudSyncOn) { Label("iCloud синхронизация", systemImage: "icloud") }
                    Button { isBackingUp = true; DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { isBackingUp = false } } label: { if isBackingUp { HStack { ProgressView(); Text("Резервное копирование...") } } else { Label("Создать резервную копию", systemImage: "externaldrive.fill.badge.plus") } }
                    Button(role: .destructive) { } label: { Label("Выйти", systemImage: "rectangle.portrait.and.arrow.right") }
                }

                // 9. About
                Section("О приложении") {
                    HStack { Label("Версия", systemImage: "info.circle"); Spacer(); Text(appVersion).foregroundStyle(.secondary) }
                    Link(destination: URL(string: "https://example.com/support")!) { Label("Поддержка", systemImage: "lifepreserver") }
                    Link(destination: URL(string: "https://example.com/feedback")!) { Label("Обратная связь", systemImage: "bubble.left.and.bubble.right.fill") }
                    Link(destination: URL(string: "https://example.com/privacy")!) { Label("Политика конфиденциальности", systemImage: "lock.shield") }
                }

                // 10. Privacy & Permissions
                Section("Конфиденциальность и доступы") {
                    ForEach(permissions.indices, id: \.self) { idx in
                        HStack {
                            Image(systemName: permissions[idx].systemSymbol).frame(width: 24)
                            Text(permissions[idx].title)
                            Spacer()
                            Image(systemName: permissions[idx].granted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill").foregroundStyle(permissions[idx].granted ? .green : .orange)
                        }
                    }
                    Toggle(isOn: $analyticsOn) { Label("Делиться аналитикой", systemImage: "chart.pie.fill") }
                    Link(destination: URL(string: UIApplication.openSettingsURLString)!) { Label("Системные настройки приватности", systemImage: "gearshape.2.fill") }
                }
            }
            .navigationTitle("Настройки")
        }
        .sheet(isPresented: $showRescheduleSheet) { RescheduleSheet(selectedDays: $selectedDays, workoutTime: $workoutTime).presentationDetents([.medium, .large]) }
    }
}

// MARK: - Supporting Views
private struct DaysOfWeekInlinePicker: View {
    @Binding var selectedDays: Set<Int>
    private let days = ["Пн","Вт","Ср","Чт","Пт","Сб","Вс"]
    var body: some View {
        HStack { ForEach(1...7, id: \.self) { i in let isOn = selectedDays.contains(i); Text(days[i-1]).font(.caption).padding(.vertical, 8).frame(maxWidth: .infinity).background(isOn ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(isOn ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1)).onTapGesture { withAnimation(.easeInOut) { if isOn { selectedDays.remove(i) } else { selectedDays.insert(i) } } } } }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Дни недели")
    }
}

private struct MultipleSelectionRow: View {
    let title: String
    let isOn: Bool
    var toggle: () -> Void
    var body: some View {
        Button(action: toggle) { HStack { Text(title); Spacer(); if isOn { Image(systemName: "checkmark").foregroundStyle(.tint) } } }
        .foregroundStyle(.primary)
    }
}

private struct RescheduleSheet: View {
    @Binding var selectedDays: Set<Int>
    @Binding var workoutTime: Date
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Перенос тренировки") {
                    DaysOfWeekInlinePicker(selectedDays: $selectedDays)
                    DatePicker("Новое время", selection: $workoutTime, displayedComponents: .hourAndMinute)
                }
                Section { Button("Сохранить изменения") { dismiss() } }
            }
            .navigationTitle("Перенести")
        }
    }
}

