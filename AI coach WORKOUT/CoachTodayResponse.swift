import Foundation

// MARK: - AnyCodable
public struct AnyCodable: Codable {
    public let value: Any
    public init(_ value: Any) { self.value = value }
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self.value = NSNull(); return }
        if let b = try? container.decode(Bool.self) { self.value = b; return }
        if let i = try? container.decode(Int.self) { self.value = i; return }
        if let d = try? container.decode(Double.self) { self.value = d; return }
        if let s = try? container.decode(String.self) { self.value = s; return }
        if let dict = try? container.decode([String: AnyCodable].self) { self.value = dict.mapValues { $0.value }; return }
        if let arr = try? container.decode([AnyCodable].self) { self.value = arr.map { $0.value }; return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported AnyCodable type")
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull: try container.encodeNil()
        case let b as Bool: try container.encode(b)
        case let i as Int: try container.encode(i)
        case let d as Double: try container.encode(d)
        case let s as String: try container.encode(s)
        case let dict as [String: Any]:
            let enc = dict.mapValues { v -> AnyCodable in AnyCodable(v) }
            try container.encode(enc)
        case let arr as [Any]:
            let enc = arr.map { AnyCodable($0) }
            try container.encode(enc)
        default:
            throw EncodingError.invalidValue(value, .init(codingPath: container.codingPath, debugDescription: "Unsupported AnyCodable type"))
        }
    }
}

// MARK: - CoachAction
public enum CoachAction: Codable, Equatable {
    case open_tab(name: String)
    case start_workout(workout_id: String)
    case schedule_reminder(kind: String, at_iso: String)
    case log_metric(type: String, value: Double, unit: String)

    private enum CodingKeys: String, CodingKey {
        case actionType = "type"
        case name
        case workout_id
        case kind
        case at_iso
        case value
        case unit
        case metric_type
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .actionType)
        switch type {
        case "open_tab": self = .open_tab(name: try c.decode(String.self, forKey: .name))
        case "start_workout": self = .start_workout(workout_id: try c.decode(String.self, forKey: .workout_id))
        case "schedule_reminder": self = .schedule_reminder(kind: try c.decode(String.self, forKey: .kind), at_iso: try c.decode(String.self, forKey: .at_iso))
        case "log_metric": self = .log_metric(type: try c.decode(String.self, forKey: .metric_type), value: try c.decode(Double.self, forKey: .value), unit: try c.decode(String.self, forKey: .unit))
        default:
            throw DecodingError.dataCorruptedError(forKey: .actionType, in: c, debugDescription: "Unknown CoachAction type: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .open_tab(let name):
            try c.encode("open_tab", forKey: .actionType)
            try c.encode(name, forKey: .name)
        case .start_workout(let id):
            try c.encode("start_workout", forKey: .actionType)
            try c.encode(id, forKey: .workout_id)
        case .schedule_reminder(let kind, let at):
            try c.encode("schedule_reminder", forKey: .actionType)
            try c.encode(kind, forKey: .kind)
            try c.encode(at, forKey: .at_iso)
        case .log_metric(let t, let v, let u):
            try c.encode("log_metric", forKey: .actionType)
            try c.encode(t, forKey: .metric_type)
            try c.encode(v, forKey: .value)
            try c.encode(u, forKey: .unit)
        }
    }
}

// MARK: - Widget
public enum Widget: Codable, Equatable, Identifiable {
    case buttons(id: String, title: String, options: [ButtonOption])
    case slider(id: String, title: String, min: Double, max: Double, step: Double, unit: String, `default`: Double?)
    case number(id: String, title: String, min: Double?, max: Double?, step: Double?, unit: String?)
    case date_time(id: String, title: String, mode: String)

    public struct ButtonOption: Codable, Equatable, Hashable, Identifiable {
        public var id: String { value }
        public let label: String
        public let value: String
    }

    public var id: String {
        switch self {
        case .buttons(let id, _, _): return id
        case .slider(let id, _, _, _, _, _, _): return id
        case .number(let id, _, _, _, _, _): return id
        case .date_time(let id, _, _): return id
        }
    }

    private enum CodingKeys: String, CodingKey { case type, id, title, options, min, max, step, unit, mode, `default` }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "buttons":
            let id = try c.decode(String.self, forKey: .id)
            let title = try c.decode(String.self, forKey: .title)
            let options = try c.decode([ButtonOption].self, forKey: .options)
            self = .buttons(id: id, title: title, options: options)
        case "slider":
            self = .slider(id: try c.decode(String.self, forKey: .id),
                           title: try c.decode(String.self, forKey: .title),
                           min: try c.decode(Double.self, forKey: .min),
                           max: try c.decode(Double.self, forKey: .max),
                           step: try c.decode(Double.self, forKey: .step),
                           unit: try c.decode(String.self, forKey: .unit),
                           default: try? c.decode(Double.self, forKey: .default))
        case "number":
            self = .number(id: try c.decode(String.self, forKey: .id),
                           title: try c.decode(String.self, forKey: .title),
                           min: try? c.decode(Double.self, forKey: .min),
                           max: try? c.decode(Double.self, forKey: .max),
                           step: try? c.decode(Double.self, forKey: .step),
                           unit: try? c.decode(String.self, forKey: .unit))
        case "date_time":
            self = .date_time(id: try c.decode(String.self, forKey: .id),
                              title: try c.decode(String.self, forKey: .title),
                              mode: try c.decode(String.self, forKey: .mode))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: c, debugDescription: "Unknown widget type: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .buttons(let id, let title, let options):
            try c.encode("buttons", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(title, forKey: .title)
            try c.encode(options, forKey: .options)
        case .slider(let id, let title, let min, let max, let step, let unit, let def):
            try c.encode("slider", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(title, forKey: .title)
            try c.encode(min, forKey: .min)
            try c.encode(max, forKey: .max)
            try c.encode(step, forKey: .step)
            try c.encode(unit, forKey: .unit)
            if let def { try c.encode(def, forKey: .default) }
        case .number(let id, let title, let min, let max, let step, let unit):
            try c.encode("number", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(title, forKey: .title)
            if let min { try c.encode(min, forKey: .min) }
            if let max { try c.encode(max, forKey: .max) }
            if let step { try c.encode(step, forKey: .step) }
            if let unit { try c.encode(unit, forKey: .unit) }
        case .date_time(let id, let title, let mode):
            try c.encode("date_time", forKey: .type)
            try c.encode(id, forKey: .id)
            try c.encode(title, forKey: .title)
            try c.encode(mode, forKey: .mode)
        }
    }
}

// MARK: - SafetyFlags
public struct SafetyFlags: Codable, Equatable {
    public let injury_risk: Bool
    public let needs_medical_caution: Bool
    public let contraindications: [String]
}

// MARK: - DebugInfo
public struct DebugInfo: Codable, Equatable { public let info: String? }

// MARK: - CoachTodayResponse
public struct CoachTodayResponse: Codable, Equatable {
    public let turn_id: String
    public let coach_message: String
    public let priority: String
    public let next_intent: String
    public let widgets: [Widget]
    public let actions: [CoachAction]
    public let safety: SafetyFlags
    public let debug: DebugInfo?
}

// MARK: - UserState
public struct UserState: Codable, Equatable {
    public var goals: [String]
    public var training_place: String
    public var equipment: [String]
    public var sex: String?
    public var age: Int?
    public var height_cm: Double?
    public var weight_kg: Double?
    public var injuries: [String]
    public var pregnant: Bool?
    public var lactating: Bool?
    public var cycle_phase: String?
    public var sleep_hours_last_night: Double?
    public var steps_today: Int?
    public var last_workout_summary: String?

    public init(
        goals: [String] = ["health"],
        training_place: String = "home",
        equipment: [String] = [],
        sex: String? = nil,
        age: Int? = nil,
        height_cm: Double? = nil,
        weight_kg: Double? = nil,
        injuries: [String] = [],
        pregnant: Bool? = nil,
        lactating: Bool? = nil,
        cycle_phase: String? = nil,
        sleep_hours_last_night: Double? = nil,
        steps_today: Int? = nil,
        last_workout_summary: String? = nil
    ) {
        self.goals = goals
        self.training_place = training_place
        self.equipment = equipment
        self.sex = sex
        self.age = age
        self.height_cm = height_cm
        self.weight_kg = weight_kg
        self.injuries = injuries
        self.pregnant = pregnant
        self.lactating = lactating
        self.cycle_phase = cycle_phase
        self.sleep_hours_last_night = sleep_hours_last_night
        self.steps_today = steps_today
        self.last_workout_summary = last_workout_summary
    }
}
