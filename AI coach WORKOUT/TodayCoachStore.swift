import Foundation
import SwiftUI
import Combine

public enum TodayAPIError: Error {
    case http(status: Int, body: String)
}

public struct CoachCard: Identifiable, Equatable {
    public let id = UUID()
    public var role: String // "coach" | "system"
    public var text: String
    public var timestamp: Date
    public var intent: String?
    public var priority: String?
}

@MainActor
public final class TodayCoachStore: ObservableObject {
    @Published public var cards: [CoachCard] = []
    @Published public var activeWidget: Widget? = nil
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var aiNoticeBanner: String? = nil

    @AppStorage("ai_mode") public var aiMode: String = "mock" {
        didSet {
            Task { await self.refreshToday(force: true) }
        }
    }
    private var sessionFallbackToMock: Bool = false

    private let api: TodayCoachAPIClient
    private var lastTurnId: String? = nil

    public init(api: TodayCoachAPIClient = TodayCoachAPIClient()) {
        self.api = api
    }

    public func loadToday(userState: UserState) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await api.sendToday(userState: userState, lastTurnId: nil, userReply: nil)
            handle(response: response)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func submitReply(widgetId: String, value: AnyCodable, userState: UserState) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await api.sendToday(userState: userState, lastTurnId: lastTurnId, userReply: ["widget_id": AnyCodable(widgetId), "value": value])
            handle(response: response)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handle(response: CoachTodayResponse) {
        lastTurnId = response.turn_id
        let card = CoachCard(role: "coach", text: response.coach_message, timestamp: Date(), intent: response.next_intent, priority: response.priority)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            cards.append(card)
            activeWidget = response.widgets.first
        }
        // Actions and safety could be handled here if needed (open tabs, schedule reminders, etc.)
    }

    public func bindAIModeBanner(_ external: Binding<String?>) {
        // Keep external banner in sync with store's banner
        _ = $aiNoticeBanner.sink { value in
            external.wrappedValue = value
        }
    }

    public func refreshToday(force: Bool) async {
        isLoading = true
        defer { isLoading = false }
        if sessionFallbackToMock || aiMode == "mock" {
            await useMock()
            return
        }
        do {
            let response = try await api.sendToday(userState: UserState(), lastTurnId: nil, userReply: nil)
            handle(response: response)
            sessionFallbackToMock = false
            await setBanner(nil)
        } catch {
            var banner: String = "Сервер недоступен. Включён Mock."
            switch error {
            case TodayAPIError.http(let status, let body):
                if status == 402 || body.localizedCaseInsensitiveContains("insufficient_quota") {
                    banner = "Live недоступен (billing). Включён Mock."
                } else if status == 429 {
                    banner = "Слишком много запросов. Включён Mock."
                } else if (500...599).contains(status) {
                    banner = "Сервер недоступен. Включён Mock."
                }
            case is URLError:
                banner = "Сервер недоступен. Включён Mock."
            case is DecodingError:
                banner = "Ошибка формата ответа. Включён Mock."
            default:
                banner = "Сервер недоступен. Включён Mock."
            }
            sessionFallbackToMock = true
            await setBanner(banner)
            await useMock()
        }
    }

    private func setBanner(_ message: String?) async {
        await MainActor.run { self.aiNoticeBanner = message }
        guard let message = message else { return }
        let current = message
        do {
            try await Task.sleep(nanoseconds: 5_000_000_000)
        } catch { }
        await MainActor.run {
            if self.aiNoticeBanner == current { self.aiNoticeBanner = nil }
        }
    }

    private func useMock() async {
        // Simple mock: append a coach card with default text
        let card = CoachCard(role: "coach", text: "[Mock] Советы на сегодня готовы.", timestamp: Date(), intent: nil, priority: nil)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { self.cards.append(card) }
    }
}
