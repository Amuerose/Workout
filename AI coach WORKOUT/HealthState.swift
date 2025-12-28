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
      isAuthorized = try await HealthKitManager.shared.requestAuthorization()
    } catch {
      isAuthorized = false
    }
  }

  func refresh() async {
    isRefreshing = true
    defer { isRefreshing = false }

    do {
      stepsToday = try await HealthKitManager.shared.fetchStepsToday()
      activeEnergyToday = try await HealthKitManager.shared.fetchActiveEnergyToday()
      lastNightSleepHours = try await HealthKitManager.shared.fetchLastNightSleepHours()
      restingHeartRate = try await HealthKitManager.shared.fetchRestingHeartRate()
    } catch {
      // Keep previous values if fetching fails
    }
  }
}
