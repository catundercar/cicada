import Foundation
import Testing
@testable import LiveSubs

@Suite struct AIProviderTests {
    @Test func servicesAreDistinctAndLingIsTheDefault() {
        let ids = AIProvider.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(AIProvider.named("nope") == AIProvider.ling)
        #expect(AIProvider.named("deepseek").base == "https://api.deepseek.com/v1/")
        // Only Ling brings Ming; everything but 自定义 knows where it lives and what to call.
        #expect(AIProvider.all.filter(\.ming).map(\.id) == ["ling"])
        for p in AIProvider.all where !p.isCustom {
            #expect(AIProvider.baseURL(p.base) != nil, "\(p.id)")
            #expect(!p.models.isEmpty, "\(p.id)")
        }
    }

    @Test func addressesAreNormalised() {
        #expect(AIProvider.baseURL("api.example.com/v1")?.absoluteString == "https://api.example.com/v1/")
        #expect(AIProvider.baseURL(" https://api.example.com/v1/chat/completions ")?.absoluteString == "https://api.example.com/v1/")
        #expect(AIProvider.baseURL("http://localhost:1234/v1//")?.absoluteString == "http://localhost:1234/v1/")
        #expect(AIProvider.baseURL("") == nil)
        #expect(AIProvider.baseURL("ftp://example.com") == nil)
        #expect(AIProvider.baseURL("not a url") == nil)
        let root = AIProvider.baseURL("https://api.example.com/v1")!
        #expect(root.appendingPathComponent("chat/completions").absoluteString == "https://api.example.com/v1/chat/completions")
    }

    @Test func bodyTurnsThinkingOffTheServicesWay() {
        let messages: [[String: Any]] = [["role": "user", "content": "hi"]]
        let ling = AIRequest.chatBody(model: "m", messages: messages, maxTokens: 10, json: true, thinking: .typeDisabled, omit: [])
        #expect((ling["thinking"] as? [String: String]) == ["type": "disabled"])
        #expect(ling["max_tokens"] as? Int == 10)
        #expect(ling["temperature"] as? Double == 0.2)
        #expect((ling["response_format"] as? [String: String]) == ["type": "json_object"])

        let qwen = AIRequest.chatBody(model: "m", messages: messages, maxTokens: 10, json: false, thinking: .enableFalse, omit: [])
        #expect(qwen["enable_thinking"] as? Bool == false)
        #expect(qwen["thinking"] == nil && qwen["response_format"] == nil)

        let plain = AIRequest.chatBody(model: "m", messages: messages, maxTokens: 10, json: false, thinking: .none, omit: [])
        #expect(plain["thinking"] == nil && plain["enable_thinking"] == nil)
    }

    @Test func refusedParametersAreLeftOut() {
        let messages: [[String: Any]] = [["role": "user", "content": "hi"]]
        let full = AIRequest.chatBody(model: "m", messages: messages, maxTokens: 10, json: true, thinking: .typeDisabled, omit: [])
        #expect(AIRequest.refused("Unsupported parameter: 'max_tokens' is not supported with this model. Use 'max_completion_tokens' instead.", in: full) == .maxTokens)
        #expect(AIRequest.refused("Unsupported value: 'temperature' does not support 0.2 with this model.", in: full) == .temperature)
        #expect(AIRequest.refused("Unrecognized request argument supplied: thinking", in: full) == .thinking)
        #expect(AIRequest.refused("response_format json_object is not supported", in: full) == .responseFormat)
        #expect(AIRequest.refused("Model Not Exist", in: full) == nil)

        let omit: AIRequest.Omit = [.maxTokens, .temperature, .thinking, .responseFormat]
        let lean = AIRequest.chatBody(model: "m", messages: messages, maxTokens: 10, json: true, thinking: .typeDisabled, omit: omit)
        #expect(lean["max_tokens"] == nil && lean["max_completion_tokens"] as? Int == 10)
        #expect(lean["temperature"] == nil && lean["thinking"] == nil && lean["response_format"] == nil)
        // Nothing left to drop: the same message can't loop.
        #expect(AIRequest.refused("Unsupported parameter: 'max_tokens'", in: lean) == nil)
        #expect(AIRequest.refused("thinking is not supported", in: lean) == nil)
    }

    @Test func errorMessagesAreRead() {
        #expect(AIRequest.errorMessage(Data(#"{"error":{"message":"Model Not Exist","type":"invalid_request_error"}}"#.utf8)) == "Model Not Exist")
        #expect(AIRequest.errorMessage(Data(#"{"error":"model 'x' not found"}"#.utf8)) == "model 'x' not found")
        #expect(AIRequest.errorMessage(Data(#"{"message":"bad"}"#.utf8)) == "bad")
        #expect(AIRequest.errorMessage(Data("<html><body>502</body></html>".utf8)) == "")
        #expect(AIRequest.errorMessage(Data("plain failure".utf8)) == "plain failure")
    }

    @Test func repliesLoseThinkingAndFences() {
        #expect(AIRequest.cleanReply("<think>\nhmm\n</think>\n\nHello", json: false) == "Hello")
        #expect(AIRequest.cleanReply("```json\n{\"a\": 1}\n```", json: true) == "{\"a\": 1}")
        #expect(AIRequest.cleanReply("```json\n{\"a\": 1}\n```", json: false) == "```json\n{\"a\": 1}\n```")
        #expect(AIRequest.cleanReply("  Bonjour  ", json: false) == "Bonjour")
    }

    @Test func modelListIsSorted() {
        let root: [String: Any] = ["object": "list", "data": [["id": "b"], ["id": "a"], ["object": "model"]]]
        #expect(AIRequest.modelIDs(root) == ["a", "b"])
        #expect(AIRequest.modelIDs([:]).isEmpty)
    }
}
