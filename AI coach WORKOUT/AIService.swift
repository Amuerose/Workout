import Foundation

// App-level AI Stub service (unique names to avoid conflicts)
public struct AppAIStubChatMessage {
    public let role: String
    public let content: String
    public init(role: String, content: String) { self.role = role; self.content = content }
}

public protocol AppAIStubServiceProtocol {
    func completeChat(messages: [AppAIStubChatMessage]) async throws -> String
}

public enum AIServiceError: Error { case invalidInput }

public final class AppAIStubService: AppAIStubServiceProtocol {
    public init() {}
    public func completeChat(messages: [AppAIStubChatMessage]) async throws -> String {
        try await Task.sleep(nanoseconds: 200_000_000)
        if let last = messages.last(where: { $0.role == "user" }) {
            return "[Коуч]: " + last.content + " — Отлично! Давай начнем!"
        } else {
            return "[Коуч]: Привет! Я помогу с тренировками."
        }
    }
}

public final class AppAIStubMockService: AppAIStubServiceProtocol {
    public init() {}
    public func completeChat(messages: [AppAIStubChatMessage]) async throws -> String {
        return "[Mock] Отличная идея! Давай начнем с разминки."
    }
}
