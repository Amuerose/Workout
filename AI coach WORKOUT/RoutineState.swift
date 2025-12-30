import Foundation
import Observation

// Assuming DayPart enum is defined elsewhere in the project:
// enum DayPart { case morning, afternoon, evening, night }

enum DayPart: String, Codable, CaseIterable {
    case morning
    case afternoon
    case evening
    case night
}

@Observable
final class RoutineState {
    var wakeTime: Date
    var sleepTime: Date
    var workStart: Date
    var workEnd: Date
    var preferredPart: DayPart
    var sleepGoalHours: Double

    init() {
        let calendar = Calendar.current
        wakeTime = calendar.date(bySettingHour: 7, minute: 30, second: 0, of: Date())!
        sleepTime = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: Date())!
        workStart = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        workEnd = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: Date())!
        preferredPart = .evening
        sleepGoalHours = 7.5
    }

    func isSleepInsufficient(lastNight: Double) -> Bool {
        let tolerance = 0.25
        return lastNight < (sleepGoalHours - tolerance)
    }
}
