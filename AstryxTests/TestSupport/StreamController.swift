import Foundation

/// A tiny helper for deterministic `AsyncThrowingStream` tests.
///
/// - Note: This is test-only infrastructure. It is intentionally simple and not intended
///   for production use.
final class ThrowingStreamController<Element> {
    private(set) var stream: AsyncThrowingStream<Element, Error>
    private var continuation: AsyncThrowingStream<Element, Error>.Continuation?

    init(bufferingPolicy: AsyncThrowingStream<Element, Error>.Continuation.BufferingPolicy = .unbounded) {
        var captured: AsyncThrowingStream<Element, Error>.Continuation?
        self.stream = AsyncThrowingStream(Element.self, bufferingPolicy: bufferingPolicy) { cont in
            captured = cont
        }
        self.continuation = captured
    }

    func yield(_ element: Element) {
        continuation?.yield(element)
    }

    func finish() {
        continuation?.finish()
    }

    func fail(_ error: Error) {
        continuation?.finish(throwing: error)
    }
}

