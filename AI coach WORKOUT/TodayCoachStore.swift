import Foundation
import SwiftUI
import HealthKit
import Combine

public enum CoachState: Equatable {
    case needsPermissions
    case loading
    case ready(plan: AIPlan)
    case noData
    case error(message: String)
}

public struct HealthSnapshot: Equatable {
    public var stepsToday: Int
    public var sleepHoursLastNight: Double?
    public var restingHeartRate: Double?
    public var energyLevel: EnergyLevel
    public enum EnergyLevel: String { case low, normal, high }
}

public struct AIPlan: Equatable, Codable {
    public var title: String
    public var priorities: [String]
    public var session: Session
    public var explanation: String
    public struct Session: Equatable, Codable { public var durationMin: Int; public var steps: Int }
}

@MainActor
public final class TodayCoachStore: ObservableObject {
    @Published public var state: CoachState = .loading
    @Published public var snapshot: HealthSnapshot? = nil
    @Published public var activeWidget: Widget? = nil

    private var cancellables: Set<AnyCancellable> = []

    public init() {}

    // MARK: - Lifecycle Hooks
    public func onAppear() {
        Task { await refreshIfNeeded() }
    }

    public func sceneBecameActive() {
        Task { await refreshIfNeeded() }
    }

    // MARK: - Widgets / Replies
    public func submitReply(widgetId: String, value: AnyCodable, userState: UserState) async {
        // Basic validation: ensure the reply matches the current widget id
        if let w = activeWidget, w.id == widgetId {
            // For now, clear the active widget after submission to hide the bar
            await MainActor.run { [weak self] in
                self?.activeWidget = nil
            }
        }
        // Optionally, you could forward this reply to backend on next refresh
        // Keeping minimal to satisfy compiler and UI expectations
    }

    // MARK: - Core Flow
    public func refreshIfNeeded() async {
        // Permissions
        do {
            try await HealthKitManager.shared.requestAuthorization()
        } catch {
            // If denied or unavailable, reflect in state
            self.state = .needsPermissions
            return
        }

        self.state = .loading

        // Fetch metrics
        async let steps = HealthKitManager.shared.fetchStepsToday()
        async let sleep = HealthKitManager.shared.fetchSleepHoursLastNight()
        let stepsVal = await steps
        let sleepVal = await sleep

        // Build snapshot
        let snap = HealthSnapshot(
            stepsToday: stepsVal,
            sleepHoursLastNight: sleepVal > 0 ? sleepVal : nil,
            restingHeartRate: nil,
            energyLevel: .normal
        )
        self.snapshot = snap

        // No data case: if both steps 0 and no sleep -> treat as noData (not an error)
        if stepsVal == 0 && (snap.sleepHoursLastNight == nil) {
            self.state = .noData
            return
        }

        // AI Plan
        do {
            let plan = try await generateAIPlan(from: snap)
            self.state = .ready(plan: plan)
        } catch {
            // Safe fallback
            let fallback = AIPlan(
                title: "Лёгкий день восстановления",
                priorities: ["10–15 минут прогулки", "Стакан воды перед каждым приёмом пищи", "Лёгкая растяжка вечером"],
                session: .init(durationMin: 8, steps: 600),
                explanation: "Недостаточно данных для точного плана, поэтому выбрали безопасный восстановительный день."
            )
            self.state = .ready(plan: fallback)
        }
    }

    // MARK: - AI Planner (ChatGPT-only, local prompt)
    private func generateAIPlan(from snap: HealthSnapshot) async throws -> AIPlan {
        // Local prompt string. In production, use a service layer.
        let systemPrompt = "Вы — персональный фитнес‑тренер. Верните ТОЛЬКО JSON со схемой: {title, priorities[3], session{durationMin, steps}, explanation}. Учитывайте: шаги сегодня, сон прошлой ночи, пульс в покое (если есть). Без диагноза. Коротко и реалистично."
        let userJson: [String: Any] = [
            "stepsToday": snap.stepsToday,
            "sleepHoursLastNight": snap.sleepHoursLastNight ?? NSNull(),
            "restingHeartRate": snap.restingHeartRate ?? NSNull()
        ]
        let userInput = try JSONSerialization.data(withJSONObject: userJson, options: [.withoutEscapingSlashes])
        let userString = String(data: userInput, encoding: .utf8) ?? "{}"

        // Stubbed call: replace with real ChatGPT API integration. For now, create a heuristic JSON.
        let planJSON = heuristicPlanJSON(snap: snap)

        // Decode JSON
        let plan = try decodePlan(from: planJSON)
        return plan
    }

    private func heuristicPlanJSON(snap: HealthSnapshot) -> String {
        let lowSleep = (snap.sleepHoursLastNight ?? 0) < 6.0
        let lowSteps = snap.stepsToday < 2000
        let title = lowSleep ? "День с пониженной нагрузкой" : "Сбалансированный день"
        let priorities: [String] = lowSleep ? [
            "Лёгкая прогулка 15 минут",
            "2–3 коротких перерыва на мобилити",
            "Лечь спать на 30–45 минут раньше"
        ] : [
            "Прогулка 30 минут (умеренный темп)",
            "Короткая силовая с собственным весом (10–12 минут)",
            "Вода и белок в каждом приёме пищи"
        ]
        let sessionDur = lowSleep ? 8 : 10
        let steps = lowSteps ? 1500 : 3000
        let explanation = lowSleep ? "Сон был ниже оптимального, поэтому предлагаем щадящую активность и фокус на восстановлении." : "Данных достаточно, чтобы держать умеренную активность и поддерживать прогресс."
        let dict: [String: Any] = [
            "title": title,
            "priorities": priorities,
            "session": ["durationMin": sessionDur, "steps": steps],
            "explanation": explanation
        ]
        let data = try? JSONSerialization.data(withJSONObject: dict, options: [.withoutEscapingSlashes])
        return String(data: data ?? Data(), encoding: .utf8) ?? "{}"
    }

    private func decodePlan(from json: String) throws -> AIPlan {
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        return try decoder.decode(AIPlan.self, from: data)
    }
}
