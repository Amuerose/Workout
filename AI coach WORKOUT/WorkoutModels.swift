import Foundation
import SwiftUI

public enum WorkoutGoal: String, Codable, CaseIterable, Identifiable {
    case strength = "Сила"
    case endurance = "Выносливость"
    case weightloss = "Похудение"
    case mobility = "Мобилити"
    public var id: String { rawValue }
}

public enum Equipment: String, Codable, CaseIterable, Identifiable {
    case home = "Дом"
    case gym = "Зал"
    public var id: String { rawValue }
}

public struct WorkoutContext: Codable, Equatable {
    public var sleepHours: Double
    public var steps: Int
    public var sorenessLevel: Int // 1–5
    public var missedWorkoutsCount: Int
    public var goal: WorkoutGoal
    public var equipmentAvailable: Equipment
    public init(
        sleepHours: Double = 7.0,
        steps: Int = 5000,
        sorenessLevel: Int = 2,
        missedWorkoutsCount: Int = 0,
        goal: WorkoutGoal = .strength,
        equipmentAvailable: Equipment = .home
    ) {
        self.sleepHours = sleepHours
        self.steps = steps
        self.sorenessLevel = sorenessLevel
        self.missedWorkoutsCount = missedWorkoutsCount
        self.goal = goal
        self.equipmentAvailable = equipmentAvailable
    }
}

public enum WorkoutIntensity: String, Codable, CaseIterable, Identifiable {
    case veryLight = "Очень лёгкая"
    case light = "Лёгкая"
    case moderate = "Средняя"
    case hard = "Высокая"
    public var id: String { rawValue }
}

public struct WorkoutExerciseDetail: Codable, Hashable {
    public var technique: String
    public var tips: [String]
    public var videoURL: URL? // placeholder for future
    public init(
        technique: String = "Держите корпус ровно.",
        tips: [String] = ["Следите за дыханием"],
        videoURL: URL? = nil
    ) {
        self.technique = technique
        self.tips = tips
        self.videoURL = videoURL
    }
}

public struct WorkoutExerciseItem: Identifiable, Hashable, Codable {
    public let id: UUID
    public var name: String
    public var sets: Int
    public var reps: Int
    public var durationSec: Int?
    public var muscleGroup: String
    public var type: String
    public var detail: WorkoutExerciseDetail
    public init(
        id: UUID = UUID(),
        name: String,
        sets: Int,
        reps: Int,
        durationSec: Int? = nil,
        muscleGroup: String = "Общее",
        type: String = "Силовое",
        detail: WorkoutExerciseDetail = .init()
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.durationSec = durationSec
        self.muscleGroup = muscleGroup
        self.type = type
        self.detail = detail
    }
}

public struct DailyWorkoutPlan: Identifiable, Codable, Hashable {
    public let id: UUID
    public var title: String
    public var durationMin: Int
    public var intensity: WorkoutIntensity
    public var goal: WorkoutGoal
    public var reason: String // short AI explanation
    public var exercises: [WorkoutExerciseItem]
    public init(
        id: UUID = UUID(),
        title: String,
        durationMin: Int,
        intensity: WorkoutIntensity,
        goal: WorkoutGoal,
        reason: String,
        exercises: [WorkoutExerciseItem]
    ) {
        self.id = id
        self.title = title
        self.durationMin = durationMin
        self.intensity = intensity
        self.goal = goal
        self.reason = reason
        self.exercises = exercises
    }
}

public struct ReadinessSnapshot: Codable, Hashable {
    public var sleepHours: Double
    public var steps: Int
    public var hrv: Int // mock ms
    public var fatigue: Int // 1-5
    public var score: Int // 0-100
}

public enum WorkoutStage: String, Codable {
    case warmup
    case exercise
    case rest
    case finished
}

public struct Coach: Identifiable, Hashable {
    public let id = UUID()
    public var name: String
    public var rating: Double
    public var specialty: WorkoutGoal
}

public struct Program: Identifiable, Hashable {
    public let id = UUID()
    public var title: String
    public var goal: WorkoutGoal
    public var durationWeeks: Int
}

public struct WorkoutVideo: Identifiable, Hashable {
    public let id = UUID()
    public var title: String
    public var category: String
}
