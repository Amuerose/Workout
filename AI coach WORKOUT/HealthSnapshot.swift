// HealthSnapshot.swift
// Simple value type to carry today's health metrics used by the coach.

import Foundation

public struct HealthCoachSnapshot: Sendable, Codable, Equatable {
    public enum EnergyLevel: String, Codable, Sendable { case low, normal, high }

    public var stepsToday: Int
    public var sleepHoursLastNight: Double?
    public var restingHeartRate: Double?
    public var energyLevel: EnergyLevel

    public init(stepsToday: Int, sleepHoursLastNight: Double?, restingHeartRate: Double?, energyLevel: EnergyLevel) {
        self.stepsToday = stepsToday
        self.sleepHoursLastNight = sleepHoursLastNight
        self.restingHeartRate = restingHeartRate
        self.energyLevel = energyLevel
    }

    public static let empty = HealthCoachSnapshot(
        stepsToday: 0,
        sleepHoursLastNight: nil,
        restingHeartRate: nil,
        energyLevel: EnergyLevel.normal
    )
}

