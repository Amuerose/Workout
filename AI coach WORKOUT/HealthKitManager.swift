import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

#if canImport(HealthKit)
enum HealthKitAuthError: Error {
    case denied
    case typesUnavailable
}
#endif

public final class HealthKitManager {
    public static let shared = HealthKitManager()

    #if canImport(HealthKit)
    private let healthStore = HKHealthStore()
    #endif

    private init() {}

    public func requestAuthorization() async throws {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let maybeTypes: [HKObjectType?] = [
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)
        ]
        let readTypes = Set(maybeTypes.compactMap { $0 })
        if readTypes.isEmpty { throw HealthKitAuthError.typesUnavailable }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else if success == false {
                    cont.resume(throwing: HealthKitAuthError.denied)
                } else {
                    cont.resume()
                }
            }
        }
        #else
        // No-op when HealthKit is unavailable
        return
        #endif
    }

    public func fetchStepsToday() async -> Int {
        #if canImport(HealthKit)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }

        return await withCheckedContinuation { cont in
            let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error = error {
                    // Minimal diagnostics: consider routing to a logger in production
                    print("HealthKit steps query error: \(error)")
                }
                let value = stats?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                cont.resume(returning: Int(value))
            }
            healthStore.execute(query)
        }
        #else
        return 0
        #endif
    }

    public func fetchSleepHoursLastNight() async -> Double {
        #if canImport(HealthKit)
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: startOfToday, options: .strictStartDate)
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        return await withCheckedContinuation { cont in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    // Minimal diagnostics: consider routing to a logger in production
                    print("HealthKit sleep query error: \(error)")
                }
                let total = (samples as? [HKCategorySample])?.reduce(0.0) { acc, sample in
                    let dur = sample.endDate.timeIntervalSince(sample.startDate)
                    return acc + dur
                } ?? 0.0
                cont.resume(returning: total / 3600.0)
            }
            healthStore.execute(query)
        }
        #else
        return 0
        #endif
    }

    public func fetchLatestRestingHeartRate() async -> Double? {
        #if canImport(HealthKit)
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now.addingTimeInterval(-14*24*3600)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: hrType, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                if let s = samples?.first as? HKQuantitySample {
                    let unit = HKUnit.count().unitDivided(by: .minute())
                    cont.resume(returning: s.quantity.doubleValue(for: unit))
                } else {
                    cont.resume(returning: nil)
                }
            }
            self.healthStore.execute(q)
        }
        #else
        return nil
        #endif
    }

    public struct HealthDebugSnapshot {
        public let stepsToday: Int
        public let sleepHoursLastNight: Double?
        public let restingHeartRate: Double?
        public let authorization: [String: Int]
        public let lastUpdated: Date
        public let error: String?
        public init(stepsToday: Int, sleepHoursLastNight: Double?, restingHeartRate: Double?, authorization: [String: Int], lastUpdated: Date, error: String?) {
            self.stepsToday = stepsToday
            self.sleepHoursLastNight = sleepHoursLastNight
            self.restingHeartRate = restingHeartRate
            self.authorization = authorization
            self.lastUpdated = lastUpdated
            self.error = error
        }
    }
    public func authorizationStatusSnapshot() -> [String: Int] {
        #if canImport(HealthKit)
        var result: [String: Int] = [:]
        let items: [(String, HKObjectType?)] = [
            ("stepCount", HKObjectType.quantityType(forIdentifier: .stepCount)),
            ("sleepAnalysis", HKObjectType.categoryType(forIdentifier: .sleepAnalysis)),
            ("restingHeartRate", HKObjectType.quantityType(forIdentifier: .restingHeartRate))
        ]
        for (name, maybeType) in items {
            if let t = maybeType { result[name] = healthStore.authorizationStatus(for: t).rawValue }
        }
        return result
        #else
        return [:]
        #endif
    }

    public func debugSnapshot() async -> HealthDebugSnapshot {
        var errorMsg: String? = nil
        let auth = authorizationStatusSnapshot()
        let steps = await fetchStepsToday()
        let sleepVal = await fetchSleepHoursLastNight()
        var sleepOpt: Double? = sleepVal
        // Treat 0 hours sleep as no data for debug visibility
        if sleepVal <= 0 { sleepOpt = nil }

        var hr: Double? = nil
        #if canImport(HealthKit)
        if let hrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            let now = Date()
            let start = Calendar.current.date(byAdding: .day, value: -14, to: now) ?? now.addingTimeInterval(-14*24*3600)
            let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            do {
                hr = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Double?, Error>) in
                    let q = HKSampleQuery(sampleType: hrType, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, err in
                        if let err = err { cont.resume(throwing: err); return }
                        if let s = samples?.first as? HKQuantitySample {
                            let unit = HKUnit.count().unitDivided(by: .minute())
                            cont.resume(returning: s.quantity.doubleValue(for: unit))
                        } else {
                            cont.resume(returning: nil)
                        }
                    }
                    self.healthStore.execute(q)
                }
            } catch {
                errorMsg = error.localizedDescription
            }
        }
        #endif

        return HealthDebugSnapshot(
            stepsToday: steps,
            sleepHoursLastNight: sleepOpt,
            restingHeartRate: hr,
            authorization: auth,
            lastUpdated: Date(),
            error: errorMsg
        )
    }
}

