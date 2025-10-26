import Foundation
import OSLog

/// Provides utilities for running asynchronous work with a bounded execution time.
enum AsyncTimeout {
    private static let logger = Logger(subsystem: "com.aviwad.LyricFever", category: "AsyncTimeout")

    /// Executes the supplied asynchronous operation, cancelling it if the timeout expires first.
    /// - Parameters:
    ///   - seconds: The maximum number of seconds to wait for `operation` to complete. Must be positive.
    ///   - operation: The closure to execute.
    /// - Returns: The value returned by `operation` if it finishes before the timeout.
    /// - Throws: `CancellationError` if the surrounding task is cancelled, or any error thrown by `operation`.
    static func run<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        guard seconds > 0 else {
            logger.error("Refusing to run timeout wrapper because seconds is non-positive: \(seconds, privacy: .public)")
            throw AsyncTimeoutError.invalidTimeout
        }

        logger.debug("Executing timeout wrapper with \(seconds, privacy: .public)s budget.")

        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                AsyncTimeout.logger.error("Timeout of \(seconds, privacy: .public)s exceeded. Cancelling operation.")
                throw AsyncTimeoutError.timeoutExceeded
            }

            do {
                let value = try await group.next()!
                group.cancelAll()
                return value
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }
}

/// Errors produced by the timeout helper.
enum AsyncTimeoutError: LocalizedError {
    case invalidTimeout
    case timeoutExceeded

    var errorDescription: String? {
        switch self {
        case .invalidTimeout:
            return "The timeout must be greater than zero."
        case .timeoutExceeded:
            return "The operation exceeded the allotted timeout."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidTimeout:
            return "Provide a timeout value greater than zero seconds."
        case .timeoutExceeded:
            return "Retry the operation with a higher timeout or investigate performance bottlenecks."
        }
    }
}
