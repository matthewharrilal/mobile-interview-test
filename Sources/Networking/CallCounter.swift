// CallCounter.swift
// Thread-safe call counter used by the `*.failingThenRecovers` test variants.
// Actor-based: eliminates the `@unchecked Sendable` escape hatch and the
// manual NSLock the previous `final class` implementation needed.

import Foundation

actor CallCounter {
    private var count: Int = 0

    func incrementAndGet() -> Int {
        count += 1
        return count
    }
}
