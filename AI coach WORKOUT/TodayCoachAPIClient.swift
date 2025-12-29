import Foundation

public struct TodayCoachAPIClient {
    public struct Request: Codable {
        public let app_version: String
        public let device_locale: String
        public let timezone: String
        public let now_iso: String
        public let user_state: UserState
        public let last_turn_id: String?
        public let user_reply: [String: AnyCodable]?
    }

    // IMPORTANT SECURITY NOTE:
    // Never store or ship OpenAI (or any LLM) API keys in the iOS app bundle or Info.plist.
    // Keys must live only on your server. This client calls your proxy endpoint.

    public init() {}

    public func sendToday(
        to baseURL: URL = URL(string: "https://YOUR_PROXY_DOMAIN/api/coach/today")!,
        userState: UserState,
        lastTurnId: String? = nil,
        userReply: [String: AnyCodable]? = nil
    ) async throws -> CoachTodayResponse {
        var req = URLRequest(url: baseURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let now = ISO8601DateFormatter().string(from: Date())
        let body = Request(
            app_version: "1.0",
            device_locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
            now_iso: now,
            user_state: userState,
            last_turn_id: lastTurnId,
            user_reply: userReply
        )
        req.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let decoded = try JSONDecoder().decode(CoachTodayResponse.self, from: data)
            return decoded
        } catch {
            // Mock fallback in case of network errors
            let mock = CoachTodayResponse(
                turn_id: UUID().uuidString,
                coach_message: "Привет! Пока нет связи с сервером — работаю в офлайн‑режиме. Готов к лёгкой разминке 10 минут?",
                priority: "normal",
                next_intent: "warmup_suggestion",
                widgets: [
                    .buttons(id: "warmup_choice", title: "Выбери действие", options: [
                        .init(label: "Старт 10 мин", value: "start_10"),
                        .init(label: "Позже", value: "later")
                    ])
                ],
                actions: [],
                safety: SafetyFlags(injury_risk: false, needs_medical_caution: false, contraindications: []),
                debug: DebugInfo(info: "offline-mock")
            )
            return mock
        }
    }
}
