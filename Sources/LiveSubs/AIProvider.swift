import Foundation

// MARK: - Services

/// An OpenAI-compatible chat service for notes, translation and speaker names. Ling is the default
/// and comes with Ming (its voices, the user's cloned voice and one-call speak-back). A 自定义 server
/// that also serves Ming-3.0 TTS (oMLX, mlx-audio) gives the voices and cloning; otherwise the Mac's
/// voices speak, and speak-back is always on-device recognition plus text translation.
struct AIProvider: Identifiable, Equatable {
    /// How a service turns a model's thinking off. Some think by default, which adds seconds to every
    /// subtitle and bills the reasoning.
    enum Thinking: Equatable {
        case none
        /// `"thinking": {"type": "disabled"}` (Ling, GLM).
        case typeDisabled
        /// `"enable_thinking": false` (Qwen on DashScope).
        case enableFalse
        /// `"chat_template_kwargs": {"enable_thinking": false}`, the switch local servers (oMLX, vLLM,
        /// SGLang) hand to the model's chat template; without it a local Qwen thinks ~30 s per line.
        case templateKwargs
    }

    /// Stored in settings and names the key file.
    let id: String
    /// The OpenAI-compatible root; empty for 自定义, where the user gives it.
    let base: String
    /// Suggestions for the model menu; the first is the default.
    let models: [String]
    /// Where to create a key (or, for Ollama, get the app).
    let keyPage: String?
    let needsKey: Bool
    let thinking: Thinking
    /// Ming's voices, the cloned voice and the audio model come with the service.
    let ming: Bool
    /// Least time between request starts. Ling's account allows about 2 requests per second.
    let spacing: TimeInterval
    /// A cheaper model for the key check than the chosen one.
    var checkModel: String? = nil

    var name: String {
        switch id {
        case "ling": "Ling"
        case "deepseek": "DeepSeek"
        case "qwen": L("通义千问")
        case "kimi": "Kimi"
        case "glm": L("智谱 GLM")
        case "openai": "OpenAI"
        case "openrouter": "OpenRouter"
        case "ollama": "Ollama"
        default: L("自定义")
        }
    }

    var isCustom: Bool { id == "custom" }
    /// Runs on this Mac: no key, no account limit.
    var isLocal: Bool { id == "ollama" }

    static let ling = AIProvider(
        id: "ling", base: "https://api.ant-ling.com/v1/", models: ["Ling-3.1-flash", "Ling-3.0-flash"],
        keyPage: "https://chat.ant-ling.com/platform/api", needsKey: true, thinking: .typeDisabled, ming: true,
        spacing: 0.6, checkModel: "Ling-3.0-tiny")

    static let all: [AIProvider] = [
        ling,
        AIProvider(id: "deepseek", base: "https://api.deepseek.com/v1/", models: ["deepseek-chat"],
                   keyPage: "https://platform.deepseek.com/api_keys", needsKey: true, thinking: .none, ming: false, spacing: 0.2),
        AIProvider(id: "qwen", base: "https://dashscope.aliyuncs.com/compatible-mode/v1/",
                   models: ["qwen-plus", "qwen-flash", "qwen-max"],
                   keyPage: "https://bailian.console.aliyun.com/?tab=model#/api-key", needsKey: true, thinking: .enableFalse,
                   ming: false, spacing: 0.2),
        AIProvider(id: "kimi", base: "https://api.moonshot.cn/v1/", models: ["kimi-k2-turbo-preview", "moonshot-v1-auto"],
                   keyPage: "https://platform.moonshot.cn/console/api-keys", needsKey: true, thinking: .none, ming: false, spacing: 0.2),
        AIProvider(id: "glm", base: "https://open.bigmodel.cn/api/paas/v4/", models: ["glm-4.5-air", "glm-4.5-flash"],
                   keyPage: "https://bigmodel.cn/usercenter/proj-mgmt/apikeys", needsKey: true, thinking: .typeDisabled,
                   ming: false, spacing: 0.2),
        AIProvider(id: "openai", base: "https://api.openai.com/v1/", models: ["gpt-4.1-mini", "gpt-4.1-nano", "gpt-4o-mini"],
                   keyPage: "https://platform.openai.com/api-keys", needsKey: true, thinking: .none, ming: false, spacing: 0.2),
        AIProvider(id: "openrouter", base: "https://openrouter.ai/api/v1/",
                   models: ["openai/gpt-4.1-mini", "deepseek/deepseek-chat", "google/gemini-2.5-flash"],
                   keyPage: "https://openrouter.ai/keys", needsKey: true, thinking: .none, ming: false, spacing: 0.2),
        AIProvider(id: "ollama", base: "http://localhost:11434/v1/", models: ["qwen2.5:7b", "llama3.1:8b"],
                   keyPage: "https://ollama.com/download", needsKey: false, thinking: .none, ming: false, spacing: 0),
        AIProvider(id: "custom", base: "", models: [], keyPage: nil, needsKey: false, thinking: .templateKwargs, ming: false,
                   spacing: 0.2),
    ]

    static func named(_ id: String) -> AIProvider { all.first { $0.id == id } ?? ling }

    /// What the user typed as a service address, as a root to append `chat/completions` to:
    /// "api.example.com/v1" and a pasted ".../v1/chat/completions" both become "https://api.example.com/v1/".
    static func baseURL(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, !s.contains(where: \.isWhitespace) else { return nil }
        if !s.contains("://") { s = "https://" + s }
        for tail in ["/chat/completions", "/completions"] where s.lowercased().hasSuffix(tail) {
            s.removeLast(tail.count)
        }
        while s.hasSuffix("/") { s.removeLast() }
        guard let url = URL(string: s + "/"), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}

// MARK: - Requests

/// Chat requests and what comes back, kept pure so tests can pin each service's quirks.
enum AIRequest {
    /// Optional parameters a service refused for a model (HTTP 400 naming them); later calls to the
    /// same address and model leave them out. `maxTokens` means "say `max_completion_tokens`".
    struct Omit: OptionSet, Hashable, CustomStringConvertible {
        let rawValue: Int
        static let temperature = Omit(rawValue: 1)
        static let responseFormat = Omit(rawValue: 2)
        static let thinking = Omit(rawValue: 4)
        static let maxTokens = Omit(rawValue: 8)

        var description: String {
            [(Omit.temperature, "temperature"), (.responseFormat, "response_format"), (.thinking, "thinking"),
             (.maxTokens, "max_tokens")].filter { contains($0.0) }.map(\.1).joined(separator: ",")
        }
    }

    static func chatBody(model: String, messages: [[String: Any]], maxTokens: Int, json: Bool,
                         temperature: Double? = 0.2, thinking: AIProvider.Thinking, omit: Omit) -> [String: Any] {
        var body: [String: Any] = ["model": model, "messages": messages, "stream": false]
        body[omit.contains(.maxTokens) ? "max_completion_tokens" : "max_tokens"] = maxTokens
        if let temperature, !omit.contains(.temperature) { body["temperature"] = temperature }
        if json && !omit.contains(.responseFormat) { body["response_format"] = ["type": "json_object"] }
        if !omit.contains(.thinking) {
            switch thinking {
            case .none: break
            case .typeDisabled: body["thinking"] = ["type": "disabled"]
            case .enableFalse: body["enable_thinking"] = false
            case .templateKwargs: body["chat_template_kwargs"] = ["enable_thinking": false]
            }
        }
        return body
    }

    /// The parameter a 400 complains about, when `body` sent it and the call works without it.
    /// Matched loosely on the message, since every service words it differently ("Unsupported
    /// parameter: 'max_tokens'…", "Unrecognized request argument supplied: thinking", …).
    static func refused(_ message: String, in body: [String: Any]) -> Omit? {
        let m = message.lowercased()
        if body["max_tokens"] != nil, m.contains("max_tokens") { return .maxTokens }
        if body["temperature"] != nil, m.contains("temperature") { return .temperature }
        if body["response_format"] != nil, m.contains("response_format") || m.contains("json_object") { return .responseFormat }
        if body["thinking"] != nil || body["enable_thinking"] != nil, m.contains("thinking") { return .thinking }
        if body["chat_template_kwargs"] != nil, m.contains("chat_template_kwargs") || m.contains("thinking") { return .thinking }
        return nil
    }

    /// The human part of an error body: OpenAI's `{"error": {"message": …}}`, `{"error": "…"}`,
    /// `{"message": …}`, or the start of whatever came back.
    static func errorMessage(_ data: Data) -> String {
        if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let e = root["error"] as? [String: Any], let m = e["message"] as? String { return m }
            if let m = root["error"] as? String { return m }
            if let m = root["message"] as? String { return m }
            if let m = root["msg"] as? String { return m }
        }
        let text = String(decoding: data.prefix(300), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.hasPrefix("<") ? "" : text
    }

    /// The reply's text, without a `<think>…</think>` preamble (local reasoning models put it in the
    /// content) or, for JSON, a ```json fence (models without `response_format` like to add one).
    static func cleanReply(_ text: String, json: Bool) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("<think>") {
            t = t.range(of: "</think>").map { String(t[$0.upperBound...]) } ?? ""
            t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if json, t.hasPrefix("```") {
            t = String(t.drop(while: { $0 != "\n" }).dropFirst())
            if t.hasSuffix("```") { t.removeLast(3) }
            t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t
    }

    /// Model ids from `GET models` (`{"data": [{"id": …}]}`), sorted.
    static func modelIDs(_ root: [String: Any]) -> [String] {
        ((root["data"] as? [[String: Any]]) ?? []).compactMap { $0["id"] as? String }.sorted()
    }
}
