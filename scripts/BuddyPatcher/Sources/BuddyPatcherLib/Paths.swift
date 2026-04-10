import Foundation

// ── Home Directory Resolution ────────────────────────────────────────
//
// Production: uses FileManager.default.homeDirectoryForCurrentUser,
// which reads the user database (not the HOME env var).
//
// Tests/tooling: set `BUDDY_HOME=/path/to/test/home` to redirect every
// home-relative file the patcher touches (backups, metadata, soul). This
// is the only mechanism that isolates integration tests from the real
// ~/.claude directory on macOS.
//
// Evaluated once at startup — do not mutate BUDDY_HOME after process launch.
public let resolvedHome: URL = {
    if let override = ProcessInfo.processInfo.environment["BUDDY_HOME"],
       !override.isEmpty {
        return URL(fileURLWithPath: override)
    }
    return FileManager.default.homeDirectoryForCurrentUser
}()
