import XCTest
@testable import LyricFever

final class SpotifyLyricProviderTests: XCTestCase {
    private struct MockSession: URLSessioning {
        let handler: (URLRequest) throws -> (Data, URLResponse)

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            try handler(request)
        }

        func data(from url: URL) async throws -> (Data, URLResponse) {
            try handler(URLRequest(url: url))
        }
    }

    func testRejectsInvalidTrackIdentifiers() async {
        let provider = SpotifyLyricProvider(userAgentSession: MockSession { _ in fatalError("Not expected") })
        do {
            _ = try await provider.fetchNetworkLyrics(trackName: "Test", trackID: "short", currentlyPlayingArtist: nil, currentAlbumName: nil)
            XCTFail("Expected localTrackUnsupported error")
        } catch {
            XCTAssertEqual(error as? SpotifyLyricProviderError, .localTrackUnsupported)
        }
    }

    func testTimeoutMapsToError() async {
        let timeoutSession = MockSession { _ in throw AsyncTimeoutError.timeoutExceeded }
        let provider = SpotifyLyricProvider(userAgentSession: timeoutSession)
        do {
            _ = try await provider.fetchNetworkLyrics(trackName: "Test", trackID: String(repeating: "a", count: 22), currentlyPlayingArtist: nil, currentAlbumName: nil)
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
