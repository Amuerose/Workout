import SwiftUI

// Главный экран «AI Фитнес-коуч»
public struct MainDashboardView: View {
    // Состояния только для демонстрации анимаций
    @State private var showContent: Bool = false
    @State private var weeklyProgress: Double = 5.0/7.0

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Заголовок экрана
                Text("Привет, Алекс!")
                    .font(.largeTitle.bold())
                    .fontDesign(.rounded)
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Карточка рекомендуемой тренировки
                RecommendedWorkoutCard(
                    title: "Тренировка дня: Ноги и корпус",
                    duration: "45 мин",
                    intensity: "Средняя нагрузка",
                    quote: "Держим темп и технику — результат не заставит себя ждать!"
                )
                .padding(.horizontal)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 8)

                // Совет от ИИ (пузырь сообщения)
                AITipBubble(
                    text: "Сегодня сфокусируемся на технике 👍",
                    askAction: { /* Открыть чат с ИИ */ }
                )
                .padding(.horizontal)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 8)

                // Блок здоровья: метрики HealthKit
                VStack(alignment: .leading, spacing: 12) {
                    Text("Здоровье")
                        .font(.title2.weight(.semibold))
                        .fontDesign(.rounded)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            HealthMetricView(systemImage: "bed.double.fill", value: "7ч 15м", label: "Сон")
                            HealthMetricView(systemImage: "figure.walk", value: "4 500", label: "Шагов")
                            HealthMetricView(systemImage: "heart.fill", value: "78 bpm", label: "Пульс")
                        }
                        .padding(.horizontal)
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 8)

                // Блок прогресса
                ProgressBlock(streakText: "🔥 5 дней подряд", progress: weeklyProgress, secondaryText: "Сила: +5%")
                    .padding(.horizontal)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 8)

                // Кнопки действий
                ActionsBar(
                    startAction: { /* Начать тренировку */ },
                    changePlanAction: { /* Изменить план */ },
                    skipAction: { /* Пропустить день */ }
                )
                .padding(.horizontal)
                .padding(.bottom, 24)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 8)
            }
        }
        .onAppear {
            // Легкая анимация появления контента
            withAnimation(.easeInOut(duration: 0.35)) {
                showContent = true
            }
        }
        .animation(.easeInOut, value: weeklyProgress)
    }
}

// MARK: - Карточка рекомендуемой тренировки
private struct RecommendedWorkoutCard: View {
    let title: String
    let duration: String
    let intensity: String
    let quote: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Градиентный фон с мягкой тенью и материалом
            LinearGradient(
                colors: [Color.orange.opacity(0.85), Color.pink.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .blendMode(.overlay)
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.title.bold())
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                HStack(spacing: 12) {
                    Label(duration, systemImage: "clock")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.95))
                    Label(intensity, systemImage: "bolt.fill")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.95))
                }
                Text("\"\(quote)\"")
                    .italic()
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.top, 6)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 5)
    }
}

// MARK: - Совет от ИИ (пузырь)
private struct AITipBubble: View {
    let text: String
    var askAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "message.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 8) {
                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
                Button {
                    askAction()
                } label: {
                    Label("Задать вопрос ИИ", systemImage: "questionmark.circle")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 5)
    }
}

// MARK: - Метрика здоровья
private struct HealthMetricView: View {
    let systemImage: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundStyle(systemImage == "heart.fill" ? Color.red : Color.blue)
                Spacer()
            }
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        )
        .shadow(radius: 5)
    }
}

// MARK: - Блок прогресса
private struct ProgressBlock: View {
    let streakText: String
    let progress: Double // 0...1
    let secondaryText: String

    @State private var animatedProgress: Double = 0

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                ProgressView(value: animatedProgress)
                    .progressViewStyle(.circular)
                    .tint(.green)
                    .scaleEffect(1.2)
                Text("\(Int(progress * 100))%")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").foregroundStyle(.orange)
                    Text(streakText)
                        .font(.headline)
                        .fontDesign(.rounded)
                }
                Text(secondaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        )
        .shadow(radius: 5)
        .onAppear {
            // Анимация заполнения кольца прогресса
            withAnimation(.easeInOut(duration: 0.6)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - Панель действий
private struct ActionsBar: View {
    var startAction: () -> Void
    var changePlanAction: () -> Void
    var skipAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Изменить план", action: changePlanAction)
                .buttonStyle(.bordered)
                .controlSize(.large)

            Button("Начать тренировку", action: startAction)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.large)

            Button("Пропустить день", action: skipAction)
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    MainDashboardView()
}
