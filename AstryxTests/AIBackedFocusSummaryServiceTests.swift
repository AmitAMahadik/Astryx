import Foundation
import Testing
@testable import Astryx

struct AIBackedFocusSummaryServiceTests {

    @Test
    func streamSummary_forwardsDeltasFromInjectedAIService() async throws {
        let controller = ThrowingStreamController<String>()

        let fakeAI = FakeAIInsightService(
            mode: .streaming { _, _ in controller.stream }
        )

        let service = AIBackedFocusSummaryService(ai: fakeAI)

        let context = FocusSummaryContext(
            date: Date(timeIntervalSince1970: 0),
            timezoneIdentifier: "UTC",
            lunarSign: "Moon",
            solarSign: "Sun",
            chineseSign: "Dragon",
            profile: "Name: Test"
        )

        let stream = service.streamSummary(for: .health, context: context)

        let collector = Task { try await StreamTestHelpers.collect(stream) }

        // Ensure the prompt was actually sent (the inner task starts when the stream is consumed).
        let didCallAI = await StreamTestHelpers.eventually {
            !fakeAI.streamTextPrompts.isEmpty
        }
        #expect(didCallAI == true)

        controller.yield("A")
        controller.yield("B")
        controller.finish()

        let chunks = try await collector.value
        #expect(chunks == ["A", "B"])
    }

    @Test
    func streamSummary_buildsPromptUsingFocusSummaryPromptsAndContext() async throws {
        let controller = ThrowingStreamController<String>()

        let fakeAI = FakeAIInsightService(
            mode: .streaming { _, _ in controller.stream }
        )
        let service = AIBackedFocusSummaryService(ai: fakeAI)

        let context = FocusSummaryContext(
            date: Date(timeIntervalSince1970: 0),
            timezoneIdentifier: "UTC",
            lunarSign: "Pisces",
            solarSign: "Leo",
            chineseSign: "Metal Ox",
            profile: "Name: Alex"
        )

        let stream = service.streamSummary(for: .travel, context: context)
        let collector = Task { try await StreamTestHelpers.collect(stream) }

        let didCallAI = await StreamTestHelpers.eventually {
            !fakeAI.streamTextPrompts.isEmpty
        }
        #expect(didCallAI == true)

        controller.finish()
        _ = try await collector.value

        guard let prompt = fakeAI.streamTextPrompts.first?.prompt else {
            Issue.record("Expected AI to be called at least once.")
            return
        }

        // High-signal invariants: the service embeds both system + user blocks.
        #expect(prompt.contains("SYSTEM"))
        #expect(prompt.contains("USER"))

        // Should include the shared prompts.
        #expect(prompt.contains("You are Astryx — an astrologer assistant"))
        #expect(prompt.contains("Output MUST be exactly 4 sections"))

        // Should include the contextual user fields.
        #expect(prompt.contains("Focus area: travel"))
        #expect(prompt.contains("Lunar (Sidereal): Pisces"))
        #expect(prompt.contains("Sun (Western): Leo"))
        #expect(prompt.contains("Chinese: Metal Ox"))
        #expect(prompt.contains("Name: Alex"))
    }
}

