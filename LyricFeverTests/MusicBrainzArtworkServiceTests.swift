import XCTest
@testable import LyricFever

final class MusicBrainzArtworkServiceTests: XCTestCase {
    func testArtworkUrlBuilder() {
        let url = MusicBrainzArtworkService.artworkUrl("test-mbid")
        XCTAssertEqual(url?.absoluteString, "https://coverartarchive.org/release/test-mbid/front")
    }
}
