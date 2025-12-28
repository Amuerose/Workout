import Foundation
import Observation

@Observable
final class HealthState {
  var stepsToday: Double = 0
  var activeEnergyToday: Double = 0
  var lastNightSleepHours: Double = 0
  var restingHeartRate: Double? = nil
  var isAuthorized: Bool = false
  var isRefreshing: Bool = false

  func requestAuthorization() async {
    do {
      try await HealthKitManager.shared.requestAuthorization()
      isAuthorized = true
    } catch {
      isAuthorized = false
    }
  }

  func refresh() async {
    isRefreshing = true
    defer { isRefreshing = false }

    do {
      stepsToday = try await HealthKitManager.shared.stepsToday()
      activeEnergyToday = try await HealthKitManager.shared.activeEnergyToday()
      lastNightSleepHours = try await HealthKitManager.shared.lastNightSleepHours()
      restingHeartRate = try await HealthKitManager.shared.restingHeartRate()
    } catch {
      // Keep previous values if fetching fails
    }
  }
}
