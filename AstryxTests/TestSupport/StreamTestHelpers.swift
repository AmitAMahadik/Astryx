import Foundation

enum StreamTestHelpers {
    /// Collects all elements from an `AsyncThrowingStream` into an array.
    static func collect<T>(
        _ stream: AsyncThrowingStream<T, Error>
    ) async throws -> [T] {
        var result: [T] = []
        for try await item in stream {
            result.append(item)
        }
        return result
    }

    /// A tiny polling helper to wait for an eventually-true condition.
    static func eventually(
        timeout: Duration = .seconds(1),
        pollInterval: Duration = .milliseconds(10),
        _ condition: @escaping @Sendable () async -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while clock.now < deadline {
            if await condition() { return true }
            await Task.yield()
            try? await clock.sleep(for: pollInterval)
        }
        return await condition()
    }

    /// MainActor-friendly variant for observing UI/ViewModel state.
    static func eventuallyMainActor(
        timeout: Duration = .seconds(1),
        pollInterval: Duration = .milliseconds(10),
        _ condition: @MainActor @escaping () -> Bool
    ) async -> Bool {
        await eventually(timeout: timeout, pollInterval: pollInterval) {
            await MainActor.run { condition() }
        }
    }
}

