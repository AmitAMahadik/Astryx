//
//  AIServices.swift
//  Astryx
//
//  Centralized AI service abstractions and implementations.
//

import Foundation
import SwiftUI
import AIProxy

// MARK: - AI Services

/// Keep Views and ViewModels decoupled from third-party SDKs.
protocol AIInsightService {
    /// Returns a short, user-facing text response for the given prompt.
    func generateText(prompt: String) async throws -> String

    /// Streams a text response for the given prompt as it is generated.
    ///
    /// Each yielded element is a partial delta (may be empty). The caller should append deltas to build the full response.
    func streamText(prompt: String, secondsToWait: UInt) async throws -> AsyncThrowingStream<String, Error>
}

/// Fallback implementation when AIProxy is not available or not configured.
struct NoopAIInsightService: AIInsightService {
    func generateText(prompt: String) async throws -> String {
        throw NSError(
            domain: "Astryx",
            code: 1001,
            userInfo: [NSLocalizedDescriptionKey: "AI is not configured for this build."]
        )
    }
    func streamText(prompt: String, secondsToWait: UInt = 60) async throws -> AsyncThrowingStream<String, Error> {
        throw NSError(
            domain: "Astryx",
            code: 1001,
            userInfo: [NSLocalizedDescriptionKey: "AI is not configured for this build."]
        )
    }
}

//## OpenAI

//### Get a non-streaming chat completion from OpenAI:
/*
```swift
    import AIProxy

    /* Uncomment for BYOK use cases */
    // let openAIService = AIProxy.openAIDirectService(
    //     unprotectedAPIKey: "your-openai-key"
    // )

    /* Uncomment for all other production use cases */
    // let openAIService = AIProxy.openAIService(
    //     partialKey: "partial-key-from-your-developer-dashboard",
    //     serviceURL: "service-url-from-your-developer-dashboard"
    // )

    let requestBody = OpenAIChatCompletionRequestBody(
        model: "gpt-5.2",
        messages: [
            .system(content: .text("You are a friendly assistant")),
            .user(content: .text("hello world"))
        ],
        reasoningEffort: .noReasoning
    )

    do {
        let response = try await openAIService.chatCompletionRequest(
            body: requestBody,
            secondsToWait: 120
        )
        print(response.choices.first?.message.content ?? "")
    } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
        print("Received \(statusCode) status code with response body: \(responseBody)")
    } catch {
        print("Could not create OpenAI chat completion: \(error)")
    }
```
 */

/// AIProxy-backed implementation.
final class AIProxyInsightService: AIInsightService {
    private let openAI: OpenAIService

    init(partialKey: String, serviceURL: String) {
        self.openAI = AIProxy.openAIService(
            partialKey: partialKey,
            serviceURL: serviceURL
        )
    }

    /// Simple non-streaming request to validate OpenAI connectivity.
    func generateText(prompt: String) async throws -> String {
        let requestBody = OpenAIChatCompletionRequestBody(
            model: defaultModel(),
            messages: [
                .system(content: .text("You are a concise assistant.")),
                .user(content: .text(prompt))
            ]
        )

        let response: OpenAIChatCompletionResponseBody
        do {
            response = try await openAI.chatCompletionRequest(
                body: requestBody,
                secondsToWait: 120
            )
        } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
            throw NSError(
                domain: "Astryx",
                code: 1400,
                userInfo: [NSLocalizedDescriptionKey: "AIProxy/OpenAI returned HTTP \(statusCode): \(responseBody)"]
            )
        }

        let text = response.choices.first?.message.content ?? ""
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw NSError(
                domain: "Astryx",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "OpenAI returned an empty response."]
            )
        }
        return text
    }

    func streamText(prompt: String, secondsToWait: UInt = 60) async throws -> AsyncThrowingStream<String, Error> {
        // Streaming chat completion request.
        // Each yielded string is a delta chunk; callers should append to build the full response.
        let requestBody = OpenAIChatCompletionRequestBody(
            model: defaultModel(),
            messages: [
                .system(content: .text("You are a concise assistant.")),
                .user(content: .text(prompt))
            ]
        )

        do {
            let stream = try await openAI.streamingChatCompletionRequest(
                body: requestBody,
                secondsToWait: secondsToWait
            )

            return AsyncThrowingStream { continuation in
                Task {
                    do {
                        for try await chunk in stream {
                            let delta = chunk.choices.first?.delta.content ?? ""
                            // Yield deltas as they arrive; may be empty.
                            continuation.yield(delta)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
            throw NSError(
                domain: "Astryx",
                code: 1402,
                userInfo: [NSLocalizedDescriptionKey: "AIProxy/OpenAI streaming request failed (HTTP \(statusCode)): \(responseBody)"]
            )
        }
    }

    /// Smoke test that validates AIProxy can reach OpenAI and return a completion.
    func testConnection(secondsToWait: UInt = 60) async throws -> String {
        let requestBody = OpenAIChatCompletionRequestBody(
            model: defaultModel(),
            messages: [
                .system(content: .text("You are a test endpoint. Reply with exactly: AIProxy OK")),
                .user(content: .text("ping"))
            ]
        )

        let response: OpenAIChatCompletionResponseBody
        do {
            response = try await openAI.chatCompletionRequest(
                body: requestBody,
                secondsToWait: secondsToWait
            )
        } catch AIProxyError.unsuccessfulRequest(let statusCode, let responseBody) {
            throw NSError(
                domain: "Astryx",
                code: 1401,
                userInfo: [NSLocalizedDescriptionKey: "AIProxy/OpenAI returned HTTP \(statusCode): \(responseBody)"]
            )
        }

        let text = response.choices.first?.message.content ?? ""
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw NSError(
                domain: "Astryx",
                code: 1003,
                userInfo: [NSLocalizedDescriptionKey: "AIProxy test completed but returned empty content."]
            )
        }
        return text
    }

    private func defaultModel() -> String {
        if let override = Bundle.main.object(forInfoDictionaryKey: "AIPROXY_OPENAI_MODEL") as? String,
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return override
        }
        return "gpt-4o-mini"
    }
}

// MARK: - Factory

enum AIInsightServiceFactory {
    static func make() -> any AIInsightService {
        // TEMPORARY: hard-coded partial key
        let partialKey = "v2|1bb98c48|gO7CG1rPMen7sVxe"
        let serviceURL = "https://api.aiproxy.com/07603b96/2bbe7ff6"
        
            return AIProxyInsightService(
                partialKey: partialKey,
                serviceURL: serviceURL
            )
    }
}

// MARK: - SwiftUI Environment

private struct AIInsightServiceKey: EnvironmentKey {
    static let defaultValue: any AIInsightService = NoopAIInsightService()
}

extension EnvironmentValues {
    var aiInsightService: any AIInsightService {
        get { self[AIInsightServiceKey.self] }
        set { self[AIInsightServiceKey.self] = newValue }
    }
}
