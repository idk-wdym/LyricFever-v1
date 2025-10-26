import Foundation

/// Convenience checks for gating logic against specific macOS releases.
extension ProcessInfo {
    /// Indicates whether the current process is executing on macOS Sonoma (14.0) or a newer release.
    var isRunningOnSonomaOrNewer: Bool {
        let version = operatingSystemVersion
        return version.majorVersion > 14 || version.majorVersion == 14
    }
}
