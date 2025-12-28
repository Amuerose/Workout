import SwiftUI

public struct TodayView: View {
    @State private var store: TodayStore = TodayStore()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroSection
                readinessSection
                dayPlanSection
                quickActionsSection
                aiCoachSection
                miniProgressSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
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
}

#Preview {
    TodayView()
}
