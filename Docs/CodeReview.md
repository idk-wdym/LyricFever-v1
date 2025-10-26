# Code Review Findings

## 1. Timeout helper crashes when parent task is cancelled
- **Location:** `LyricFever/Support Files/AsyncTimeout.swift`, lines 14-39.
- **Issue:** `withThrowingTaskGroup` unwraps `group.next()` directly. When the parent task is cancelled before any child completes, `next()` returns `nil`, so the force unwrap will crash the app instead of surfacing a cancellation error.
- **Recommendation:** Replace the force unwrap with a safe `guard let` and propagate a `CancellationError` when no result is available. This keeps timeout handling resilient during cooperative cancellations.
- **Resolution:** The helper now guards the optional result, logs the cancellation, and throws `CancellationError` when no value is produced.

## 2. MusicBrainz lookup builds malformed URLs for names with spaces or punctuation
- **Location:** `LyricFever/Services/MusicBrainzArtworkService/MusicBrainzArtworkService.swift`, lines 62-81.
- **Issue:** The MBID search path concatenates `artistName` and `albumName` directly into the query string. Any spaces, ampersands, or non-ASCII characters lead to invalid URLs or unintended query semantics.
- **Recommendation:** Construct the request with `URLComponents` and `URLQueryItem` so values are percent-encoded correctly before hitting the MusicBrainz API.
- **Resolution:** The service now builds the request via `URLComponents`, escaping embedded quotes before percent-encoding.

## 3. Colour persistence violates the Core Data uniqueness constraint
- **Location:** `LyricFever/Services/ColorDataService/ColorDataService.swift`, lines 129-145 and `LyricFever/Models/CoreData/Lyrics.xcdatamodeld/Lyrics.xcdatamodel/contents`, lines 4-11.
- **Issue:** Every save creates a fresh `IDToColor` object without checking for an existing row. Because the data model enforces a uniqueness constraint on `id`, saving twice for the same track will raise an `NSValidationErrorKey` and surface a `.saveFailed` error instead of updating the stored colour.
- **Recommendation:** Fetch (or `NSManagedObjectContext.existingObject`) for the current `trackID` and update it in place, or use `NSBatchDeleteRequest` before insert. This keeps repeated saves idempotent and honours the unique constraint.
- **Resolution:** Persistence now fetches any existing mapping before insert, updating it in place to honour the unique constraint.
