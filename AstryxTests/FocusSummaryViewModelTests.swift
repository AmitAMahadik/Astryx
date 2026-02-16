import Foundation
import Testing
@testable import Astryx

struct FocusSummaryViewModelTests {

    @Test @MainActor
    func streamSummary_success_updatesTextAndClearsLoading() async throws {
        let controller = ThrowingStreamController<String>()
        let service = FakeFocusSummaryService { _, _ in controller.stream }
        let vm = FocusSummaryViewModel(service: service)

        let area: FocusArea = .health
        let context = FocusSummaryContext(
            date: Date(timeIntervalSince1970: 0),
            timezoneIdentifier: "UTC",
            lunarSign: "Moon",
            solarSign: "Sun",
            chineseSign: "Dragon",
            profile: "Test Profile"
        )

        let task = Task { await vm.streamSummary(for: area, context: context) }

        controller.yield("Hello")
        controller.yield(" World")
        controller.finish()

        await task.value

        #expect(vm.backText(for: area) == "Hello World")
        #expect(vm.isLoading(for: area) == false)
        #expect(vm.errorMessage(for: area) == nil)
        #expect(vm.lastUpdatedByArea[area] != nil)
        #expect(service.calls.count == 1)
    }

    @Test @MainActor
    func streamSummary_error_preservesPartialOutputAndSetsErrorMessage() async throws {
        let controller = ThrowingStreamController<String>()
        let service = FakeFocusSummaryService { _, _ in controller.stream }
        let vm = FocusSummaryViewModel(service: service)

        let area: FocusArea = .career
        let context = FocusSummaryContext(
            date: Date(timeIntervalSince1970: 0),
            timezoneIdentifier: "UTC",
            lunarSign: "",
            solarSign: "",
            chineseSign: "",
            profile: ""
        )

        let task = Task { await vm.streamSummary(for: area, context: context) }

        controller.yield("Partial")
        controller.fail(NSError(domain: "AstryxTests", code: 123, userInfo: [NSLocalizedDescriptionKey: "boom"]))

        await task.value

        #expect(vm.backText(for: area) == "Partial")
        #expect(vm.isLoading(for: area) == false)
        #expect(vm.errorMessage(for: area) != nil)
        #expect(vm.lastUpdatedByArea[area] == nil)
        #expect(service.calls.count == 1)
    }

    @Test @MainActor
    func streamSummary_ignoresDuplicateRequestWhileLoading() async throws {
        let controller = ThrowingStreamController<String>()
        let service = FakeFocusSummaryService { _, _ in controller.stream }
        let vm = FocusSummaryViewModel(service: service)

        let area: FocusArea = .relationships
        let context = FocusSummaryContext(
            date: Date(timeIntervalSince1970: 0),
            timezoneIdentifier: "UTC",
            lunarSign: "L",
            solarSign: "S",
            chineseSign: "C",
            profile: "P"
        )

        let first = Task { await vm.streamSummary(for: area, context: context) }

        let didEnterLoading = await StreamTestHelpers.eventuallyMainActor {
            vm.isLoading(for: area)
        }
        #expect(didEnterLoading == true)

        // Second request should bail out early (no second call into the service).
        await vm.streamSummary(for: area, context: context)
        #expect(service.calls.count == 1)
        #expect(vm.isLoading(for: area) == true)

        controller.finish()
        await first.value
        #expect(vm.isLoading(for: area) == false)
    }
}

