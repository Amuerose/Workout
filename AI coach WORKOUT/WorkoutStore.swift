import Foundation
import SwiftUI
import Observation

@Observable
public final class WorkoutStore {
    // MARK: - Inputs
    public var context: WorkoutContext

    // MARK: - Plan & Readiness
    public private(set) var todayPlan: DailyWorkoutPlan?
    public private(set) var readiness: ReadinessSnapshot

    // MARK: - Session
    public var isSessionActive: Bool = false
    public var stage: WorkoutStage = .warmup
    public var currentIndex: Int = 0
    public var elapsedSec: Int = 0
    public var isPaused: Bool = false

    public init(context: WorkoutContext = .init()) {
        self.context = context
        self.readiness = .init(
            sleepHours: context.sleepHours,
            steps: context.steps,
            hrv: 55,
            fatigue: max(1, context.sorenessLevel),
            score: 72
        )
        self.todayPlan = generateTodaysWorkout(context: context)
    }

    // MARK: - Adaptation Logic
    public func generateTodaysWorkout(context: WorkoutContext) -> DailyWorkoutPlan {
        // Base defaults
        var intensity: WorkoutIntensity = .moderate
        var duration = 20
        var reason = "Нормальная сессия"
        var exercises: [WorkoutExerciseItem] = [
            .init(name: "Разминка: шаг на месте", sets: 1, reps: 1, durationSec: 180, muscleGroup: "Общее", type: "Разминка"),
            .init(name: "Отжимания", sets: 3, reps: 10, durationSec: nil, muscleGroup: "Грудь", type: "Сила"),
            .init(name: "Приседания", sets: 3, reps: 12, durationSec: nil, muscleGroup: "Ноги", type: "Сила"),
            .init(name: "Планка", sets: 3, reps: 1, durationSec: 40, muscleGroup: "Кор", type: "Изометрика")
        ]

        // Rules
        if context.sleepHours < 6 {
            intensity = .light
            duration = max(10, duration - 8)
            reason = "Недосып → снижаем объём и интенсивность"
            // make plan easier
            exercises = exercises.map { ex in
                var e = ex
                e.sets = max(1, Int(Double(ex.sets) * 0.7))
                e.reps = max(1, Int(Double(ex.reps) * 0.7))
                if let dur = ex.durationSec { e.durationSec = max(20, Int(Double(dur) * 0.7)) }
                return e
            }
        }
        if context.sorenessLevel >= 4 {
            intensity = .veryLight
            duration = max(8, duration - 6)
            reason = "Усталость/крепатура → делаем мобилити"
            exercises = [
                .init(name: "Мобилити плеч", sets: 2, reps: 10, durationSec: nil, muscleGroup: "Плечи", type: "Мобилити"),
                .init(name: "Растяжка бёдер", sets: 2, reps: 1, durationSec: 60, muscleGroup: "Ноги", type: "Растяжка"),
                .init(name: "Дыхательные упражнения", sets: 2, reps: 1, durationSec: 90, muscleGroup: "Общее", type: "Восстановление")
            ]
        }
        if context.missedWorkoutsCount > 2 {
            intensity = .veryLight
            duration = 12
            reason = "Рестарт после пропусков"
            exercises = [
                .init(name: "Лёгкая разминка", sets: 1, reps: 1, durationSec: 180, muscleGroup: "Общее", type: "Разминка"),
                .init(name: "Ягодичный мост", sets: 2, reps: 12, durationSec: nil, muscleGroup: "Ноги", type: "Сила"),
                .init(name: "Планка на коленях", sets: 2, reps: 1, durationSec: 30, muscleGroup: "Кор", type: "Изометрика")
            ]
        }
        // Progression for strength when good readiness
        if context.goal == .strength && readiness.score > 70 && context.sleepHours >= 6 && context.sorenessLevel <= 2 {
            reason = "Хорошая готовность → добавим прогрессию"
            exercises = exercises.map { ex in
                var e = ex
                e.sets += 1
                if e.reps > 0 { e.reps += 1 }
                if let d = e.durationSec { e.durationSec = d + 10 }
                return e
            }
            intensity = .hard
            duration += 5
        }

        return .init(title: titleFor(context: context),
                     durationMin: duration,
                     intensity: intensity,
                     goal: context.goal,
                     reason: reason,
                     exercises: exercises)
    }

    private func titleFor(context: WorkoutContext) -> String {
        switch context.goal {
        case .strength: return "Сила — верх тела"
        case .endurance: return "Кардио — базовая выносливость"
        case .weightloss: return "Сжигание калорий"
        case .mobility: return "Мобилити и гибкость"
        }
    }

    // MARK: - Session Controls
    public func startSession() {
        isSessionActive = true
        stage = .warmup
        currentIndex = 0
        elapsedSec = 0
        isPaused = false
    }

    public func pauseResume() {
        isPaused.toggle()
    }

    public func next() {
        currentIndex = min((todayPlan?.exercises.count ?? 1) - 1, currentIndex + 1)
        stage = .exercise
    }

    public func previous() {
        currentIndex = max(0, currentIndex - 1)
        stage = .exercise
    }

    public func endSession() {
        isSessionActive = false
        stage = .finished
    }

    public func adaptLighter() {
        guard var plan = todayPlan else { return }
        plan.intensity = .light
        plan.exercises = plan.exercises.map { ex in
            var e = ex
            e.sets = max(1, Int(Double(e.sets) * 0.8))
            e.reps = max(1, Int(Double(e.reps) * 0.85))
            if let d = e.durationSec { e.durationSec = max(20, Int(Double(d) * 0.85)) }
            return e
        }
        self.todayPlan = plan
    }

    public func adaptHarder() {
        guard var plan = todayPlan else { return }
        plan.intensity = .hard
        plan.exercises = plan.exercises.map { ex in
            var e = ex
            e.sets += 1
            if e.reps > 0 { e.reps += 2 }
            if let d = e.durationSec { e.durationSec = d + 15 }
            return e
        }
        self.todayPlan = plan
    }

    public func rescheduleSuggestion() -> String {
        "Перенесём на завтра и предложим 5 минут растяжки сегодня."
    }
}
