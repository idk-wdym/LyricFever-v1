import Translation
import XCTest
@testable import LyricFever

/// Validates translation service preconditions and fallbacks.
final class TranslationServiceTests: XCTestCase {
    private struct StubTranslationSession: TranslationSessioning {
        let handler: ([TranslationSession.Request]) async throws -> [TranslationSession.Response]

        func translations(from request: [TranslationSession.Request]) async throws -> [TranslationSession.Response] {
            try await handler(request)
        }
    }

    /// Ensures empty translation requests fail fast.
    func testTranslationFailsForEmptyRequest() async {
        let session = StubTranslationSession { _ in [] }
        let result = await TranslationService.translationTask(session, request: [])
        guard case .failure(let error) = result else {
            XCTFail("Expected failure for empty request")
            return
        }
        XCTAssertEqual(error, .emptyRequest)
    }

    /// Verifies we surface configuration update suggestions when language detection succeeds.
    func testTranslationNeedsConfigUpdate() async {
        let session = StubTranslationSession { _ in
            throw NSError(domain: NSCocoaErrorDomain, code: 1)
        }
        let lyric = LyricLine(startTime: 0, words: "こんにちは")
        let request = [TranslationSession.Request(lyric: lyric)]

        let result = await TranslationService.translationTask(session, request: request)
        guard case .needsConfigUpdate(let language) = result else {
            XCTFail("Expected configuration update suggestion")
            return
        }
        XCTAssertEqual(language.identifier, "ja")
    }

    // Coverage goal: maintain translation service utilities above 85% as logic grows.
}
