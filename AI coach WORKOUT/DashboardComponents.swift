import SwiftUI

// MARK: - Recommended Workout Card
public struct RecommendedWorkoutCard: View {
    public let title: String
    public let duration: String
    public let intensity: String
    public let quote: String
    public init(title: String, duration: String, intensity: String, quote: String) {
        self.title = title; self.duration = duration; self.intensity = intensity; self.quote = quote
    }
    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Color.orange.opacity(0.85), Color.pink.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial).blendMode(.overlay))
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.title.bold()).fontDesign(.rounded).foregroundStyle(.white)
                HStack(spacing: 12) {
                    Label(duration, systemImage: "clock").font(.body).foregroundStyle(.white.opacity(0.95))
                    Label(intensity, systemImage: "bolt.fill").font(.body).foregroundStyle(.white.opacity(0.95))
                }
                Text("\"\(quote)\"").italic().font(.callout).foregroundStyle(.white.opacity(0.90)).padding(.top, 6)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 3)
    }
}

// MARK: - AI Tip Bubble
public struct AITipBubble: View {
    public let text: String
    public var askAction: () -> Void
    public init(text: String, askAction: @escaping () -> Void) { self.text = text; self.askAction = askAction }
    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "message.circle.fill").font(.system(size: 28)).foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 8) {
                Text(text).font(.body).foregroundStyle(.primary)
                Button { askAction() } label: { Label("Задать вопрос ИИ", systemImage: "questionmark.circle").font(.callout) }
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

// MARK: - Health Metric View
public struct HealthMetricView: View {
    public let systemImage: String
    public let value: String
    public let label: String
    public init(systemImage: String, value: String, label: String) { self.systemImage = systemImage; self.value = value; self.label = label }
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Image(systemName: systemImage).foregroundStyle(systemImage == "heart.fill" ? Color.red : Color.blue); Spacer() }
            Text(value).font(.system(.title2, design: .rounded).weight(.semibold)).foregroundStyle(.primary)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.regularMaterial))
        .shadow(radius: 5)
    }
}

// MARK: - Progress Block
public struct ProgressBlock: View {
    public let streakText: String
    public let progress: Double // 0...1
    public let secondaryText: String
    @State private var animatedProgress: Double = 0
    public init(streakText: String, progress: Double, secondaryText: String) { self.streakText = streakText; self.progress = progress; self.secondaryText = secondaryText }
    public var body: some View {
        HStack(spacing: 16) {
            ZStack {
                ProgressView(value: animatedProgress).progressViewStyle(.circular).tint(.green).scaleEffect(1.2)
                Text("\(Int(progress * 100))%").font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
            }
            .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) { Image(systemName: "flame.fill").foregroundStyle(.orange); Text(streakText).font(.headline).fontDesign(.rounded) }
                Text(secondaryText).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.regularMaterial))
        .shadow(radius: 5)
        .onAppear { withAnimation(.easeInOut(duration: 0.6)) { animatedProgress = progress } }
    }
}

// MARK: - Actions Bar
public struct ActionsBar: View {
    public var startAction: () -> Void
    public var changePlanAction: () -> Void
    public var skipAction: () -> Void
    public init(startAction: @escaping () -> Void, changePlanAction: @escaping () -> Void, skipAction: @escaping () -> Void) { self.startAction = startAction; self.changePlanAction = changePlanAction; self.skipAction = skipAction }
    public var body: some View {
        HStack(spacing: 12) {
            Button("Изменить план", action: changePlanAction).buttonStyle(.bordered).controlSize(.large)
            Button("Начать тренировку", action: startAction).buttonStyle(.borderedProminent).tint(.orange).controlSize(.large)
            Button("Пропустить день", action: skipAction).buttonStyle(.bordered).controlSize(.large)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Dashboard Components Demo") {
    ScrollView {
        VStack(spacing: 20) {
            RecommendedWorkoutCard(title: "Тренировка дня: Ноги и корпус", duration: "45 мин", intensity: "Средняя нагрузка", quote: "Держим темп и технику — результат не заставит себя ждать!")
            AITipBubble(text: "Сегодня сфокусируемся на технике 👍", askAction: {})
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    HealthMetricView(systemImage: "bed.double.fill", value: "7ч 15м", label: "Сон")
                    HealthMetricView(systemImage: "figure.walk", value: "4 500", label: "Шагов")
                    HealthMetricView(systemImage: "heart.fill", value: "78 bpm", label: "Пульс")
                }.padding(.horizontal)
            }
            ProgressBlock(streakText: "🔥 5 дней подряд", progress: 5.0/7.0, secondaryText: "Сила: +5%")
            ActionsBar(startAction: {}, changePlanAction: {}, skipAction: {})
        }
        .padding()
    }
}
