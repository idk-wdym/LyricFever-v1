import XCTest
@testable import LyricFever

/// Validates LRCLIB provider input checks.
final class LRCLIBLyricProviderTests: XCTestCase {
    /// Ensures requests fail before performing network work when metadata is missing.
    func testFetchRejectsMissingMetadata() async {
        let provider = LRCLIBLyricProvider()
        do {
            _ = try await provider.fetchNetworkLyrics(
                trackName: "",
                trackID: "track-id",
                currentlyPlayingArtist: nil,
                currentAlbumName: nil
            )
            XCTFail("Expected metadata validation error")
        } catch LRCLIBLyricProviderError.missingTrackMetadata {
            // Expected path.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    /// Verifies the provider composes LRCLIB URLs correctly.
    func testMakeComponentsBuildsLRCLIBURL() {
        let provider = LRCLIBLyricProvider()
        let components = provider.makeComponents(
            path: "/api/get",
            items: [URLQueryItem(name: "artist_name", value: "Artist")]
        )
        XCTAssertEqual(components.host, "lrclib.net")
        XCTAssertEqual(components.path, "/api/get")
    }

    // Coverage goal: keep LRCLIB provider tests above 85% as networking evolves.
}
