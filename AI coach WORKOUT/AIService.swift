import Foundation

public struct OpenAIChatMessage {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public protocol OpenAIServiceProtocol {
    func completeChat(messages: [OpenAIChatMessage]) async throws -> String
}

public enum AIServiceError: Error {
    case invalidInput
}

public class OpenAIService: OpenAIServiceProtocol {
    public init() {}

    public func completeChat(messages: [OpenAIChatMessage]) async throws -> String {
        try await Task.sleep(nanoseconds: 300_000_000)
        guard let lastMessage = messages.last else {
            return "Hello! How can I assist you today?"
        }
        if lastMessage.role == "user" {
            return "You said: \(lastMessage.content)"
        } else {
            return "I'm here to help whenever you're ready."
        }
    }
}

public class MockOpenAIService: OpenAIServiceProtocol {
    public init() {}

    public func completeChat(messages: [OpenAIChatMessage]) async throws -> String {
        return "[Mock] Отличная идея! Давай начнем с разминки."
    }
}
