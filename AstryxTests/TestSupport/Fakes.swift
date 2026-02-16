import Foundation
@testable import Astryx

// MARK: - FocusSummaryServiceProtocol fake

final class FakeFocusSummaryService: FocusSummaryServiceProtocol {
    private let makeStreamImpl: @Sendable (FocusArea, FocusSummaryContext) -> AsyncThrowingStream<String, Error>

    private(set) var calls: [(area: FocusArea, context: FocusSummaryContext)] = []

    init(
        makeStream: @escaping @Sendable (FocusArea, FocusSummaryContext) -> AsyncThrowingStream<String, Error>
    ) {
        self.makeStreamImpl = makeStream
    }

    func streamSummary(
        for area: FocusArea,
        context: FocusSummaryContext
    ) -> AsyncThrowingStream<String, Error> {
        calls.append((area: area, context: context))
        return makeStreamImpl(area, context)
    }
}

// MARK: - AIInsightService fake

final class FakeAIInsightService: AIInsightService {
    enum Mode {
        case nonStreaming(result: Result<String, Error>)
        case streaming(makeStream: @Sendable (_ prompt: String, _ secondsToWait: UInt) -> AsyncThrowingStream<String, Error>)
    }

    private let mode: Mode

    private(set) var generateTextPrompts: [String] = []
    private(set) var streamTextPrompts: [(prompt: String, secondsToWait: UInt)] = []

    init(mode: Mode) {
        self.mode = mode
    }

    func generateText(prompt: String) async throws -> String {
        generateTextPrompts.append(prompt)

        switch mode {
        case .nonStreaming(let result):
            return try result.get()
        case .streaming:
            throw NSError(
                domain: "AstryxTests",
                code: 9001,
                userInfo: [NSLocalizedDescriptionKey: "FakeAIInsightService is configured for streaming only."]
            )
        }
    }

    func streamText(prompt: String, secondsToWait: UInt) async throws -> AsyncThrowingStream<String, Error> {
        streamTextPrompts.append((prompt: prompt, secondsToWait: secondsToWait))

        switch mode {
        case .streaming(let makeStream):
            return makeStream(prompt, secondsToWait)
        case .nonStreaming:
            return AsyncThrowingStream { continuation in
                continuation.finish(
                    throwing: NSError(
                        domain: "AstryxTests",
                        code: 9002,
                        userInfo: [NSLocalizedDescriptionKey: "FakeAIInsightService is configured for non-streaming only."]
                    )
                )
            }
        }
    }
}

