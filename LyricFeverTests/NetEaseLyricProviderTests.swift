import XCTest
@testable import LyricFever

final class NetEaseLyricProviderTests: XCTestCase {
    private struct MockSession: URLSessioning {
        let handler: (URLRequest) throws -> (Data, URLResponse)

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            try handler(request)
        }

        func data(from url: URL) async throws -> (Data, URLResponse) {
            try handler(URLRequest(url: url))
        }
    }

    func testInvalidQueryThrows() async {
        let provider = NetEaseLyricProvider(session: MockSession { _ in fatalError("No request expected") })
        do {
            _ = try await provider.fetchNetworkLyrics(trackName: " ", trackID: "id", currentlyPlayingArtist: "Artist", currentAlbumName: "Album")
            XCTFail("Expected invalidQuery error")
        } catch {
            XCTAssertEqual(error as? NetEaseLyricProviderError, .invalidQuery)
        }
    }
}
