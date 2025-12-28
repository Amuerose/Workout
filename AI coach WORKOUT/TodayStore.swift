import Foundation
import SwiftUI

// MARK: - Models
public enum TimeOfDay: String, CaseIterable { case morning, afternoon, evening }

public struct UserContext: Equatable {
    public var sleepHours: Double
    public var steps: Int
    public var sorenessLevel: Int // 1..5
    public var missedWorkoutsCount: Int
    public var timeOfDay: TimeOfDay
    public init(sleepHours: Double = 6.5, steps: Int = 4200, sorenessLevel: Int = 2, missedWorkoutsCount: Int = 0, timeOfDay: TimeOfDay = .morning) {
        self.sleepHours = sleepHours
        self.steps = steps
        self.sorenessLevel = sorenessLevel
        self.missedWorkoutsCount = missedWorkoutsCount
        self.timeOfDay = timeOfDay
    }
}

public struct TodayRecommendation: Equatable {
    public var title: String
    public var subtitle: String
    public var stepsToday: Int
    public var sleepHours: Double
    public var explanation: String
    public var suggestedDurationMin: Int
    public var intensity: String
}

public enum PainArea: String, CaseIterable { case knees = "Колени", back = "Спина", shoulders = "Плечи", neck = "Шея" }

public enum DayState: Equatable { case normal, completed, skipped, lateEvening }

// MARK: - Store
@Observable
public final class TodayStore {
    // Input/context
    public var userContext: UserContext

    // Derived/UI
    public var dayState: DayState = .normal
    public var aiMessage: String = "Сегодня сфокусируемся на технике 👍"
    public var aiLastResponse: String? = nil

    // Progress mocks
    public var workoutsIn7Days: Int = 5
    public var trend: String = "Сила"
    public var trendUp: Bool = true

    // Readiness quick choice (1..5)
    public var selfFeeling: Int = 3

    // Today recommendation
    public var recommendation: TodayRecommendation

    public init(userContext: UserContext = UserContext()) {
        self.userContext = userContext
        self.recommendation = Self.generateTodayRecommendation(from: userContext)
        // Auto adjust late evening state
        if userContext.timeOfDay == .evening { dayState = .lateEvening }
    }

    // MARK: - Logic
    public func readinessScore() -> Int {
        // Простая формула mock: сон 8ч => +50, шаги 10k => +30, soreness обратная => +20
        let sleepScore = min(max(userContext.sleepHours / 8.0, 0), 1) * 50
        let stepsScore = min(max(Double(userContext.steps) / 10000.0, 0), 1) * 30
        let sorenessScore = (1 - min(max(Double(userContext.sorenessLevel - 1) / 4.0, 0), 1)) * 20
        return Int((sleepScore + stepsScore + sorenessScore).rounded())
    }

    public static func generateTodayRecommendation(from context: UserContext) -> TodayRecommendation {
        let readiness = {
            let sleepScore = min(max(context.sleepHours / 8.0, 0), 1) * 50
            let stepsScore = min(max(Double(context.steps) / 10000.0, 0), 1) * 30
            let sorenessScore = (1 - min(max(Double(context.sorenessLevel - 1) / 4.0, 0), 1)) * 20
            return Int((sleepScore + stepsScore + sorenessScore).rounded())
        }()
        let energy: String = readiness < 40 ? "низкая" : (readiness < 70 ? "средняя" : "высокая")
        let (title, intensity, duration, explanation): (String, String, Int, String)
        if readiness < 40 {
            title = "Лучше легко"; intensity = "лёгкая"; duration = 10; explanation = "Недосып — сделаем щадящую сессию."
        } else if readiness < 70 {
            title = "Умеренно"; intensity = "средняя"; duration = 25; explanation = "Стабильно двигаемся вперёд."
        } else {
            title = "Можно нагрузиться"; intensity = "интенсивная"; duration = 35; explanation = "Готовность высокая — работаем!"
        }
        return TodayRecommendation(
            title: title,
            subtitle: "\(duration) мин • \(intensity) • цель: \(readiness < 40 ? "восстановление" : "прогресс")",
            stepsToday: context.steps,
            sleepHours: context.sleepHours,
            explanation: explanation,
            suggestedDurationMin: duration,
            intensity: intensity
        )
    }

    public func refreshRecommendation() {
        recommendation = Self.generateTodayRecommendation(from: userContext)
    }

    // Actions
    public func applyEasierPlan() {
        // Уменьшаем объем/интенсивность
        userContext.sorenessLevel = min(5, userContext.sorenessLevel + 1)
        recommendation.suggestedDurationMin = max(5, recommendation.suggestedDurationMin - 5)
        recommendation.intensity = "лёгкая"
        recommendation.title = "Лучше легко"
        recommendation.subtitle = "\(recommendation.suggestedDurationMin) мин • лёгкая • цель: восстановление"
        recommendation.explanation = "Адаптировали под самочувствие."
    }

    public func applyHarderPlan() {
        userContext.sorenessLevel = max(1, userContext.sorenessLevel - 1)
        recommendation.suggestedDurationMin = min(45, recommendation.suggestedDurationMin + 5)
        recommendation.intensity = "интенсивная"
        recommendation.title = "Можно нагрузиться"
        recommendation.subtitle = "\(recommendation.suggestedDurationMin) мин • интенсивная • цель: прогресс"
        recommendation.explanation = "Добавили нагрузку — держим технику."
    }

    public func rescheduleWorkout(to time: TimeOfDay? = nil) {
        let newTime = time ?? nextTimeSlot(after: userContext.timeOfDay)
        userContext.timeOfDay = newTime
    }

    public func miniWorkout() {
        // Точка подключения под реальный запуск мини-сессии
        recommendation.title = "Мини-сессия"
        recommendation.subtitle = "5 мин • лёгкая • цель: разогрев"
        recommendation.suggestedDurationMin = 5
        recommendation.intensity = "лёгкая"
        aiLastResponse = "Запустил мини-сессию на 5 минут."
    }

    public func recoveryWorkout() {
        recommendation.title = "Восстановление"
        recommendation.subtitle = "8 мин • лёгкая • цель: релиз"
        recommendation.suggestedDurationMin = 8
        recommendation.intensity = "лёгкая"
        aiLastResponse = "Сделаем мягкое восстановление."
    }

    public func painAdaptation(area: PainArea) {
        recommendation.title = "Щадящая тренировка"
        recommendation.subtitle = "10 мин • лёгкая • цель: \(area.rawValue.lowercased())"
        recommendation.explanation = "Адаптировали под зону: \(area.rawValue)."
        aiLastResponse = "Подобрал упражнения с учётом зоны: \(area.rawValue)."
    }

    public func markWorkoutCompleted() {
        dayState = .completed
        workoutsIn7Days = min(7, workoutsIn7Days + 1)
    }

    public func markSkipped() {
        dayState = .skipped
    }

    public func increaseIntensityIfReady() {
        if readinessScore() >= 70 { applyHarderPlan() }
    }

    // AI interactions (mock)
    public func submitAIQuery(_ text: String) {
        // Здесь будет подключение LLM; пока — мок-ответы
        switch text {
        case _ where text.contains("10 минут"): aiLastResponse = "Собрал 10-минутную сессию на технику и мобилити."
        case _ where text.contains("колени"): aiLastResponse = "Рекомендую щадящие упражнения: ягодичный мост, шаги на месте, легкая растяжка."
        case _ where text.contains("пропустил 3 дня"): aiLastResponse = "Начнём с лёгкого входа: 10 минут сегодня, 15 завтра." 
        default: aiLastResponse = "Принял, подберу оптимальный план."
        }
    }

    public func refreshAIMessage() {
        let phrases = [
            "Сегодня сфокусируемся на технике 👍",
            "Маленькие шаги — большой прогресс",
            "Дыши ровно и держи темп",
            "Сегодня главное — стабильность"
        ]
        aiMessage = phrases.randomElement() ?? aiMessage
    }

    // Helpers
    private func nextTimeSlot(after t: TimeOfDay) -> TimeOfDay {
        switch t { case .morning: return .afternoon; case .afternoon: return .evening; case .evening: return .morning }
    }
}
