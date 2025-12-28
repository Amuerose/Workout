import Foundation

struct OpenAIChatMessage: Codable {
    let role: String // "system" | "user" | "assistant"
    let content: String
}

struct OpenAIChatRequest: Codable {
    let model: String
    let messages: [OpenAIChatMessage]
    let temperature: Double?
}

struct OpenAIChatChoice: Codable { let index: Int; let message: OpenAIChatMessage }
struct OpenAIChatResponse: Codable { let choices: [OpenAIChatChoice] }

enum OpenAIServiceError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Не задан API ключ OpenAI. Установите переменную окружения OPENAI_API_KEY или пропишите ключ в коде."
        case .invalidResponse: return "Некорректный ответ от OpenAI"
        }
    }
}

final class OpenAIService {
    // Insert your API key here or provide via environment variable OPENAI_API_KEY at runtime.
    private let apiKey: String
    private let session: URLSession
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let defaultModel = "gpt-3.5-turbo"

    init(apiKey: String? = nil, session: URLSession = .shared) {
        if let key = apiKey, !key.isEmpty {
            self.apiKey = key
        } else if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !env.isEmpty {
            self.apiKey = env
        } else {
            self.apiKey = "" // will error at call time
        }
        self.session = session
    }

    func completeChat(messages: [OpenAIChatMessage], model: String? = nil, temperature: Double = 0.7) async throws -> String {
        guard !apiKey.isEmpty else { throw OpenAIServiceError.missingAPIKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = OpenAIChatRequest(model: model ?? defaultModel, messages: messages, temperature: temperature)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "OpenAI", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: text])
        }
        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let first = decoded.choices.first?.message.content else { throw OpenAIServiceError.invalidResponse }
        return first.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
