import Foundation

// MARK: - Health Data Interface (to be implemented later)
public protocol HealthDataProviding {
    func todaySleepHours() async throws -> Double
    func todaySteps() async throws -> Int
    func restingHeartRate() async throws -> Int
    func hrv() async throws -> Double
}

// MARK: - AI Service Interface (to be implemented later)
public protocol AIChatServing {
    func sendPrompt(_ text: String) async throws -> String
    func dailyMotivation() async throws -> String
}
