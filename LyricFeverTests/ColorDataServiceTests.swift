import CoreData
import OSLog
import XCTest
@testable import LyricFever

/// Exercises the Colour Data Service persistence pipeline.
final class ColorDataServiceTests: XCTestCase {
    private var container: NSPersistentContainer!
    private var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()

        container = NSPersistentContainer(name: "Lyrics")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        let expectation = expectation(description: "Persistent stores loaded")
        container.loadPersistentStores { _, error in
            XCTAssertNil(error)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        context = container.viewContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
        try super.tearDownWithError()
    }

    /// Ensures the happy path completes within the default timeout and records a colour mapping.
    func testSaveColorSucceedsWithinDefaultTimeout() async throws {
        try await ColorDataService.saveColorToCoreData(
            trackID: "test-track-id",
            songColor: 123456,
            context: context
        )

        let fetchRequest: NSFetchRequest<IDToColor> = IDToColor.fetchRequest()
        let results = try context.fetch(fetchRequest)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, "test-track-id")
    }

    /// Template verifying that invalid timeout values are rejected before work begins.
    func testSaveColorRejectsInvalidTimeout() async {
        guard let context else {
            XCTFail("Missing context")
            return
        }

        do {
            try await ColorDataService.saveColorToCoreData(
                trackID: "test-track-id",
                songColor: 123456,
                context: context,
                timeout: 0
            )
            XCTFail("Expected invalid timeout error")
        } catch ColorDataServiceError.invalidTimeout {
            Logger(subsystem: "com.aviwad.LyricFever", category: "ColorDataServiceTests").info("Invalid timeout rejected as expected.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // Coverage goal: keep colour persistence helpers above 85% as we add new cases.
}
