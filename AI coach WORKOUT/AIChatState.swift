import Foundation
import Observation

@Observable
public final class AIChatState {
    public struct Message: Identifiable, Hashable {
        public let id = UUID()
        public let isUser: Bool
        public var text: String
        public init(isUser: Bool, text: String) { self.isUser = isUser; self.text = text }
    }

    public var messages: [Message] = [ .init(isUser: false, text: "Привет! Я твой ИИ‑коуч. Чем могу помочь сегодня?") ]
    public var draft: String = ""
    public var isSending: Bool = false

    private let service: AppAIStubServiceProtocol
    public init(service: AppAIStubServiceProtocol = AppAIStubService()) { self.service = service }

    public func send() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messages.append(.init(isUser: true, text: trimmed))
        draft = ""
        Task { await requestAIResponse() }
    }

    @MainActor
    private func requestAIResponse() async {
        isSending = true
        defer { isSending = false }
        do {
            let reply = try await service.completeChat(messages: messages.map { AppAIStubChatMessage(role: $0.isUser ? "user" : "assistant", content: $0.text) })
            messages.append(.init(isUser: false, text: reply))
        } catch {
            messages.append(.init(isUser: false, text: "Ошибка запроса к ИИ: \(error.localizedDescription)"))
        }
    }
}
