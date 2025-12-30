import Foundation

public final class MockCoachEngine {
    public enum Stage: String { case welcome, checkin, recommendation }

    public private(set) var stage: Stage = .welcome
    public private(set) var lastTurnId: String? = nil

    public init() {}

    public func reset() { stage = .welcome; lastTurnId = nil }

    public func next(userReply: [String: Any]? = nil, health: HealthSnapshot? = nil) -> CoachTodayResponse {
        switch stage {
        case .welcome:
            stage = .checkin
            let coach_message: String
            if let h = health, let sleep = h.sleepHoursLastNight, sleep < 6 {
                coach_message = "Привет! Похоже, сон был коротким (≈ \(String(format: "%.1f", sleep)) ч). Предлагаю лёгкую сессию. Как самочувствие?"
            } else if let h = health, h.stepsToday == 0 {
                coach_message = "Привет! Сегодня ещё не было шагов — начнём с короткой прогулки? Как самочувствие?"
            } else if let h = health, let hr = h.restingHeartRate, hr > 95 {
                coach_message = "Привет! Пульс сейчас повышен. Сделаем спокойную разминку?"
            } else {
                coach_message = "Привет! Я твой ИИ‑тренер. Как самочувствие сегодня?"
            }
            return CoachTodayResponse(
                turn_id: UUID().uuidString,
                coach_message: coach_message,
                priority: "normal",
                next_intent: "daily_checkin",
                widgets: [
                    .buttons(id: "mood", title: "Выбери состояние", options: [
                        .init(label: "Отлично", value: "great"),
                        .init(label: "Нормально", value: "ok"),
                        .init(label: "Устал", value: "tired")
                    ])
                ],
                actions: [],
                safety: SafetyFlags(injury_risk: false, needs_medical_caution: false, contraindications: []),
                debug: DebugInfo(info: "mock-welcome")
            )
        case .checkin:
            stage = .recommendation
            let mood = (userReply?["value"] as? String) ?? "ok"
            var msg: String
            switch mood {
            case "great": msg = "Супер! Предлагаю быструю разминку и 10 минут активной работы. Готов?"
            case "tired": msg = "Понимаю. Сделаем лёгкую мобилити‑сессию на 8–10 минут. Поехали?"
            default: msg = "Отлично. Давай сделаем 10 минут умеренной активности. Стартуем?"
            }
            if (health?.sleepHoursLastNight ?? 7) < 6 {
                msg = "Сделаем лёгкую мобилити‑сессию на 8–10 минут. Поехали?"
            }
            return CoachTodayResponse(
                turn_id: UUID().uuidString,
                coach_message: msg,
                priority: "normal",
                next_intent: "offer_session",
                widgets: [
                    .buttons(id: "start_choice", title: "Начинаем?", options: [
                        .init(label: "Старт", value: "start"),
                        .init(label: "Позже", value: "later")
                    ])
                ],
                actions: [],
                safety: SafetyFlags(injury_risk: false, needs_medical_caution: false, contraindications: []),
                debug: DebugInfo(info: "mock-checkin")
            )
        case .recommendation:
            let msg: String
            if let hr = health?.restingHeartRate, hr > 95 {
                msg = "Пульс повышен — лучше восстановление. Сколько минут готов уделить сегодня?"
            } else {
                msg = "Сколько минут готов уделить сегодня?"
            }
            return CoachTodayResponse(
                turn_id: UUID().uuidString,
                coach_message: msg,
                priority: "normal",
                next_intent: "ask_length",
                widgets: [
                    .slider(id: "length", title: "Длительность", min: 5, max: 30, step: 5, unit: "мин", default: 10)
                ],
                actions: [],
                safety: SafetyFlags(injury_risk: false, needs_medical_caution: false, contraindications: []),
                debug: DebugInfo(info: "mock-recommendation")
            )
        }
    }
}

