import SwiftUI

public struct TodayView: View {
    @State private var store: TodayStore = TodayStore()
    @StateObject private var coachStore = TodayCoachStore()
    @State private var userState = UserState()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    heroSection

                    // Dynamic modular cards
                    if store.isSleepLow { SleepAdviceCard(store: store) }
                    if store.stressHigh || store.isHRVLow { StressCard(store: store) }
                    if let phase = store.cyclePhase, !phase.isEmpty { CycleCard(store: store) }
                    if store.isPregnant { PregnancyCard(store: store) }
                    ActivitySummaryCard(store: store)
                    HydrationCard(store: store)
                    if store.calendarWorkoutTime != nil { ScheduleCard(store: store) }
                    if store.workoutsIn7Days >= 4 { AchievementCard(store: store) }

                    dayStateBanner
                    readinessSection
                    dayPlanSection
                    quickActionsSection
                    aiCoachSection
                    miniProgressSection

                    // AI Coach dynamic cards feed
                    GlassCard(title: "Инициативы ИИ", icon: "sparkles") {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 8) {
                                    ForEach(coachStore.cards) { card in
                                        Text(card.text)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(10)
                                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                            .id(card.id)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .frame(minHeight: 120)
                            .onChange(of: coachStore.cards.count) { _, _ in
                                if let last = coachStore.cards.last?.id { withAnimation { proxy.scrollTo(last, anchor: .bottom) } }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .task { await coachStore.loadToday(userState: userState) }
            }
            .safeAreaInset(edge: .bottom) {
                ResponseBar(store: coachStore, userStateProvider: { userState })
                    .opacity(coachStore.activeWidget == nil ? 0 : 1)
                    .animation(.easeInOut, value: coachStore.activeWidget == nil)
            }
            .overlay(alignment: .center) {
                if coachStore.isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                }
            }
            .alert("Ошибка", isPresented: Binding(get: { coachStore.errorMessage != nil }, set: { _ in coachStore.errorMessage = nil })) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(coachStore.errorMessage ?? "")
            }
        }
    }

    // MARK: - 1) HERO "Сегодня"
    private var heroSection: some View {
        GlassCard(title: "Сегодня", icon: "sun.max.fill") {
            VStack(alignment: .leading, spacing: 12) {
                // Дата + статус
                Text(dateString(Date()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                let readiness = store.readinessScore()
                Text("Готовность: \(readiness)% • Энергия: \(energyLabel(readiness))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Divider().opacity(0.08)

                // Рекомендация тренировки
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.recommendation.title).font(.headline)
                    Text(store.recommendation.subtitle).font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Label("Шаги: \(store.recommendation.stepsToday)", systemImage: "figure.walk")
                        Label("Сон: \(Int(store.recommendation.sleepHours)) ч", systemImage: "bed.double.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text(store.recommendation.explanation).font(.caption).foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button("Начать") { store.miniWorkout() }
                            .buttonStyle(PrimaryButtonStyle())
                        Button("Изменить") { store.rescheduleWorkout() }
                            .buttonStyle(SecondaryButtonStyle())
                    }

                    HStack(spacing: 12) {
                        Button("Пропустить без чувства вины") { store.markSkipped() }
                            .buttonStyle(.plain)
                        Button("Мне тяжело") { store.applyEasierPlan() }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 2) Readiness / Контекст
    private var readinessSection: some View {
        GlassCard(title: "Контекст дня", icon: "bolt.heart") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    metricChip(system: "bed.double.fill", value: "\(String(format: "%.1f", store.userContext.sleepHours)) ч", label: "Сон")
                    metricChip(system: "figure.walk", value: "\(store.userContext.steps)", label: "Шаги")
                    metricChip(system: "heart.fill", value: "78 bpm", label: "Пульс")
                }
                // Самочувствие 1..5
                HStack(spacing: 6) {
                    Text("Самочувствие:").font(.caption).foregroundStyle(.secondary)
                    ForEach(1...5, id: \.self) { n in
                        Button(action: { store.selfFeeling = n; store.refreshRecommendation() }) {
                            Text("\(n)")
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(n == store.selfFeeling ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08)))
                        }.buttonStyle(.plain)
                    }
                }
                Text(readinessSummary()).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 3) План на день
    private var dayPlanSection: some View {
        GlassCard(title: "План на день", icon: "calendar") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Окно тренировки: \(timeLabel(store.userContext.timeOfDay))", systemImage: "clock")
                    Spacer()
                    Button("Перенести") { store.rescheduleWorkout() }.buttonStyle(.plain)
                }
                Divider().opacity(0.08)
                HStack {
                    Label("Если нет времени: мини 5 минут", systemImage: "timer")
                    Spacer()
                    Button("Сделать 5 минут") { store.miniWorkout() }.buttonStyle(.plain)
                }
                Divider().opacity(0.08)
                HStack {
                    Label("Вечер: восстановление/дыхание 2 минуты", systemImage: "moon")
                    Spacer()
                    Button("Перед сном") { store.recoveryWorkout() }.buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 4) Быстрые действия
    private var quickActionsSection: some View {
        GlassCard(title: "Быстрые действия", icon: "bolt.fill") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    quickAction("У меня 5 минут") { store.miniWorkout() }
                    quickAction("Я без сил") { store.recoveryWorkout() }
                }
                HStack(spacing: 10) {
                    quickAction("Хочу сложнее") { store.increaseIntensityIfReady() }
                    Menu {
                        ForEach(PainArea.allCases, id: \.self) { area in
                            Button(area.rawValue) { store.painAdaptation(area: area) }
                        }
                    } label: {
                        quickAction("Болит/дискомфорт") {}
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 5) ИИ-коуч
    private var aiCoachSection: some View {
        GlassCard(title: "ИИ-коуч", icon: "message") {
            VStack(alignment: .leading, spacing: 10) {
                Text(store.aiMessage).font(.subheadline)
                HStack(spacing: 6) {
                    chip("Сделай тренировку на 10 минут")
                    chip("У меня болят колени — что делать?")
                    chip("Я пропустил 3 дня — как вернуться?")
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                if let response = store.aiLastResponse {
                    Text(response).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Button("Обновить строку от ИИ") { store.refreshAIMessage() }.buttonStyle(SecondaryButtonStyle())
                }
                Button("Спросить коуча") { /* Navigate to TodayChatCoachView externally */ }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    // MARK: - 6) Мини-прогресс
    private var miniProgressSection: some View {
        GlassCard(title: "Прогресс", icon: "chart.line.uptrend.xyaxis") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Серия дней", systemImage: "flame.fill")
                    Spacer()
                    Label("За 7 дней: \(store.workoutsIn7Days)", systemImage: "figure.run")
                }
                HStack {
                    Label("Направление: \(store.trend)", systemImage: store.trendUp ? "arrow.up" : "arrow.down")
                    Spacer()
                }
                Text("Ты тренировался \(store.workoutsIn7Days) раз за 7 дней — это стабильно.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers UI
    private func metricChip(system: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Image(systemName: system).foregroundStyle(.secondary); Spacer() }
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func quickAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func chip(_ title: String) -> some View {
        Button(action: { store.submitAIQuery(title) }) {
            Text(title).font(.caption)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = .current; f.dateStyle = .full; return f.string(from: date)
    }

    private func energyLabel(_ readiness: Int) -> String { readiness < 40 ? "низкая" : (readiness < 70 ? "средняя" : "высокая") }
    private func timeLabel(_ t: TimeOfDay) -> String { switch t { case .morning: return "утро"; case .afternoon: return "день"; case .evening: return "вечер" } }
    private func readinessSummary() -> String {
        let r = store.readinessScore(); return r < 40 ? "Сегодня лучше коротко + техника" : (r < 70 ? "Стабильно, можно умеренно" : "Можно нагрузиться")
    }

    // MARK: - Day State Banner
    private var dayStateBanner: some View {
        switch store.dayState {
        case .completed:
            return AnyView(
                GlassCard(title: "Сегодня выполнено", icon: "checkmark.seal.fill") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Отлично! Фокус на восстановлении и мягкой мобилити.").font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Button("Перед сном") { store.recoveryWorkout() }.buttonStyle(SecondaryButtonStyle())
                            Button("Следующий шаг") { store.applyHarderPlan() }.buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }
            )
        case .skipped:
            return AnyView(
                GlassCard(title: "Сегодня пропущено", icon: "exclamationmark.triangle.fill") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ничего страшного — сделай минимум 5 минут и закроем день.").font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Button("Минимум 5 минут") { store.miniWorkout() }.buttonStyle(PrimaryButtonStyle())
                            Button("Перенести на позже") { store.rescheduleWorkout() }.buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }
            )
        case .lateEvening:
            return AnyView(
                GlassCard(title: "Поздний вечер", icon: "moon.zzz.fill") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Лучше короткое восстановление вместо полной тренировки.").font(.subheadline).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Button("2 мин дыхания") { store.recoveryWorkout() }.buttonStyle(SecondaryButtonStyle())
                            Button("Мягкая растяжка") { store.miniWorkout() }.buttonStyle(SecondaryButtonStyle())
                        }
                    }
                }
            )
        case .normal:
            return AnyView(EmptyView())
        }
    }
}

#Preview {
    TodayView()
}
