import SwiftUI
import Observation

// Activity summary card
public struct ActivitySummaryCard: View {
    @Bindable var store: TodayStore
    public init(store: TodayStore) { self._store = Bindable(wrappedValue: store) }
    public var body: some View {
        GlassCard(title: "Сводка активности", icon: "gauge.medium") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Label("Шаги: \(store.userContext.steps)", systemImage: "figure.walk")
                        Label("Активные мин: \(store.activeMinutes)", systemImage: "clock")
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Label("Ккал: \(store.caloriesBurned)/\(store.caloriesGoal)", systemImage: "flame.fill")
                        Label(String(format: "Дистанция: %.1f км", store.distanceKm), systemImage: "map")
                    }
                }
                HStack { Button("Прогулка 10 мин") { store.startWalk10() }.buttonStyle(SecondaryButtonStyle()); Spacer() }
            }
        }
    }
}

// Sleep advice card
public struct SleepAdviceCard: View {
    @Bindable var store: TodayStore
    public init(store: TodayStore) { self._store = Bindable(wrappedValue: store) }
    public var body: some View {
        GlassCard(title: "Сон", icon: "moon.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: "Последняя ночь: %.1f ч • Оценка: %d", store.userContext.sleepHours, store.sleepQualityScore)).font(.subheadline).foregroundStyle(.secondary)
                Text("Совет: Недосып — лучше щадящая сессия.").font(.subheadline)
                HStack(spacing: 8) {
                    Button("Растяжка 10 мин") { store.startStretching10() }.buttonStyle(PrimaryButtonStyle())
                    Button("Позже") { store.rescheduleWorkout() }.buttonStyle(SecondaryButtonStyle())
                }
            }
        }
    }
}

// Stress card
public struct StressCard: View {
    @Bindable var store: TodayStore
    public init(store: TodayStore) { self._store = Bindable(wrappedValue: store) }
    public var body: some View {
        GlassCard(title: "Стресс", icon: "wind") {
            VStack(alignment: .leading, spacing: 8) {
                Text("HRV: \(store.hrv) мс — рекомендуется дыхание").font(.subheadline).foregroundStyle(.secondary)
                HStack { Button("Дыхание 5 мин") { store.startBreathing() }.buttonStyle(SecondaryButtonStyle()); Spacer() }
            }
        }
    }
}

// Cycle card (for women)
public struct CycleCard: View {
    @Bindable var store: TodayStore
    public init(store: TodayStore) { self._store = Bindable(wrappedValue: store) }
    public var body: some View {
        GlassCard(title: "Цикл", icon: "drop.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Фаза: \(store.cyclePhase ?? "—")").font(.subheadline).foregroundStyle(.secondary)
                Text(store.cyclePhase == "PMS" ? "Рекомендуем снизить нагрузку" : "Можно нагрузиться, если самочувствие ок")
                HStack { Button("Адаптировать план") { store.applyEasierPlan() }.buttonStyle(SecondaryButtonStyle()); Spacer() }
            }
        }
    }
}

// Pregnancy card
public struct PregnancyCard: View {
    @Bindable var store: TodayStore
    public init(store: TodayStore) { self._store = Bindable(wrappedValue: store) }
    public var body: some View {
        GlassCard(title: "Беременность", icon: "figure.pregnant") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Режим безопасности: щадящие упражнения, гидратация, отдых").font(.subheadline).foregroundStyle(.secondary)
                HStack { Button("Лёгкая разминка 10 мин") { store.startStretching10() }.buttonStyle(PrimaryButtonStyle()); Spacer() }
            }
        }
    }
}

// Achievement card
public struct AchievementCard: View {
    @Bindable var store: TodayStore
    public init(store: TodayStore) { self._store = Bindable(wrappedValue: store) }
    public var body: some View {
        GlassCard(title: "Достижения", icon: "rosette") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Тренировок за 7 дней: \(store.workoutsIn7Days)")
                Text("Готовность: \(store.readinessScore())%")
                HStack { Button("План на завтра") { store.openPlan() }.buttonStyle(SecondaryButtonStyle()); Spacer() }
            }
        }
    }
}

// Schedule reminder card
public struct ScheduleCard: View {
    @Bindable var store: TodayStore
    public init(store: TodayStore) { self._store = Bindable(wrappedValue: store) }
    public var body: some View {
        GlassCard(title: "Расписание", icon: "calendar") {
            VStack(alignment: .leading, spacing: 8) {
                if let t = store.calendarWorkoutTime {
                    Text("Сегодня в \(timeString(t)) запланирована тренировка").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("Сегодня тренировок в календаре нет").font(.subheadline).foregroundStyle(.secondary)
                }
                HStack { Button("Просмотреть план") { store.openPlan() }.buttonStyle(SecondaryButtonStyle()); Spacer() }
            }
        }
    }
    private func timeString(_ d: Date) -> String { let f = DateFormatter(); f.timeStyle = .short; return f.string(from: d) }
}

// Health alert card
public struct HealthAlertCard: View {
    @Bindable var store: TodayStore
    public init(store: TodayStore) { self._store = Bindable(wrappedValue: store) }
    public var body: some View {
        GlassCard(title: "Здоровье", icon: "heart.fill") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Пульс покоя/HRV вне нормы — сегодня без рекордов").font(.subheadline).foregroundStyle(.secondary)
                HStack { Button("Лёгкая сессия") { store.applyEasierPlan() }.buttonStyle(SecondaryButtonStyle()); Spacer() }
            }
        }
    }
}

// Hydration card
public struct HydrationCard: View {
    @Bindable var store: TodayStore
    public init(store: TodayStore) { self._store = Bindable(wrappedValue: store) }
    public var body: some View {
        GlassCard(title: "Вода", icon: "drop.fill") {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: store.hydrationProgress) {
                    Text("Стаканы: \(store.hydrationGlasses)/\(store.hydrationGoal)").font(.subheadline).foregroundStyle(.secondary)
                }
                .progressViewStyle(.linear)
                HStack { Button("Выпил стакан") { store.addWaterGlass() }.buttonStyle(SecondaryButtonStyle()); Spacer() }
            }
        }
    }
}

