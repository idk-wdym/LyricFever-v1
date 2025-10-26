import XCTest
@testable import LyricFever

/// Exercises romanization success and failure paths.
final class RomanizerServiceTests: XCTestCase {
    /// Verifies that empty strings are rejected prior to conversion.
    func testGenerateRomanizedStringRejectsEmptyInput() async {
        do {
            _ = try await RomanizerService.generateRomanizedString("   ")
            XCTFail("Expected empty input error")
        } catch RomanizerServiceError.emptyInput {
            // Expected path.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Ensures latin script input is returned unchanged.
    func testGenerateRomanizedStringReturnsLatinScript() async throws {
        let input = "Hello World"
        let output = try await RomanizerService.generateRomanizedString(input)
        XCTAssertEqual(output, input)
    }

    /// Confirms that Chinese transliteration runs and yields output.
    func testChineseConversionProducesOutput() async throws {
        let lyric = LyricLine(startTime: 0, words: "繁體中文")
        let converted = try await RomanizerService.generateMainlandTransliteration(lyric)
        XCTAssertFalse(converted.isEmpty)
    }

    // Coverage goal: maintain romanizer helpers above 85% as new cases are added.
}
