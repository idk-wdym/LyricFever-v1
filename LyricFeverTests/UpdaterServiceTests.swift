import XCTest
@testable import LyricFever

final class UpdaterServiceTests: XCTestCase {
    func testUrgentUpdateExistsRejectsNegativeTimeout() async {
        let service = UpdaterService()
        do {
            _ = try await service.urgentUpdateExists(timeout: -1)
            XCTFail("Expected invalidTimeout error")
        } catch {
            XCTAssertEqual(error as? UpdaterServiceError, .invalidTimeout)
        }
    }
}
