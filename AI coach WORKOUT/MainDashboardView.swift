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

#Preview {
    MainDashboardView()
}
