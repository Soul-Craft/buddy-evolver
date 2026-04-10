import XCTest
import CryptoKit
@testable import BuddyPatcherLib

final class BackupRestoreTests: XCTestCase {

    var tempDir: URL!
    var backupDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BuddyPatcherTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        backupDir = tempDir.appendingPathComponent("backups")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // Helper: write a fake binary with arbitrary bytes
    private func writeBinary(_ name: String, bytes: [UInt8] = Array("fake binary content".utf8)) -> URL {
        let url = tempDir.appendingPathComponent(name)
        try! Data(bytes).write(to: url)
        return url
    }

    // Helper: expected backup file for a binary path
    private func backupFile(for binary: URL) -> URL {
        return binary.deletingLastPathComponent()
            .appendingPathComponent("\(binary.lastPathComponent).original-backup")
    }

    // MARK: - sha256Hex

    func testSha256HexKnownValue() {
        let url = tempDir.appendingPathComponent("hello")
        try! "hello".data(using: .utf8)!.write(to: url)
        // SHA-256 of "hello" = 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
        XCTAssertEqual(sha256Hex(url), "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    func testSha256HexMissingFile() {
        let url = tempDir.appendingPathComponent("does-not-exist")
        XCTAssertNil(sha256Hex(url))
    }

    func testSha256HexDeterministic() {
        let url = writeBinary("test-binary")
        let first = sha256Hex(url)
        let second = sha256Hex(url)
        XCTAssertNotNil(first)
        XCTAssertEqual(first, second)
    }

    // MARK: - ensureBackup

    func testEnsureBackupCreatesBackup() {
        let binary = writeBinary("claude")
        ensureBackup(binary, backupDir: backupDir, soulPath: tempDir.appendingPathComponent("no-soul.json"))

        let backup = backupFile(for: binary)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path))
    }

    func testEnsureBackupIdempotent() {
        let binary = writeBinary("claude")
        let noSoul = tempDir.appendingPathComponent("no-soul.json")

        ensureBackup(binary, backupDir: backupDir, soulPath: noSoul)
        let backup = backupFile(for: binary)
        let firstMtime = (try? FileManager.default.attributesOfItem(atPath: backup.path)[.modificationDate]) as? Date

        // Sleep briefly to ensure any new write would have a different mtime
        Thread.sleep(forTimeInterval: 0.05)

        ensureBackup(binary, backupDir: backupDir, soulPath: noSoul)
        let secondMtime = (try? FileManager.default.attributesOfItem(atPath: backup.path)[.modificationDate]) as? Date

        XCTAssertEqual(firstMtime, secondMtime, "Backup should not be overwritten on second call")
    }

    func testEnsureBackupCreatesHashFile() {
        let binary = writeBinary("claude", bytes: Array("deterministic".utf8))
        ensureBackup(binary, backupDir: backupDir, soulPath: tempDir.appendingPathComponent("no-soul.json"))

        let hashFile = backupDir.appendingPathComponent("binary-sha256.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: hashFile.path))

        let storedHash = try? String(contentsOf: hashFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(storedHash, sha256Hex(binary))
    }

    func testEnsureBackupSetsPermissions() {
        let binary = writeBinary("claude")
        ensureBackup(binary, backupDir: backupDir, soulPath: tempDir.appendingPathComponent("no-soul.json"))

        // Backup dir should be 0o700
        let dirAttrs = try? FileManager.default.attributesOfItem(atPath: backupDir.path)
        let dirPerms = (dirAttrs?[.posixPermissions] as? NSNumber)?.uint16Value
        XCTAssertEqual(dirPerms, 0o700)

        // Backup file should be 0o600
        let backup = backupFile(for: binary)
        let fileAttrs = try? FileManager.default.attributesOfItem(atPath: backup.path)
        let filePerms = (fileAttrs?[.posixPermissions] as? NSNumber)?.uint16Value
        XCTAssertEqual(filePerms, 0o600)
    }

    func testEnsureBackupCopiesSoul() {
        let binary = writeBinary("claude")
        let soul = tempDir.appendingPathComponent("soul.json")
        try! "{\"companion\":{\"name\":\"Test\"}}".data(using: .utf8)!.write(to: soul)

        ensureBackup(binary, backupDir: backupDir, soulPath: soul)

        let soulBackup = backupDir.appendingPathComponent(".claude.json.pre-customize")
        XCTAssertTrue(FileManager.default.fileExists(atPath: soulBackup.path))

        let data = try? Data(contentsOf: soulBackup)
        XCTAssertEqual(String(data: data!, encoding: .utf8), "{\"companion\":{\"name\":\"Test\"}}")
    }

    // MARK: - verifyBinary

    func testVerifyBinaryWithWorkingBinary() {
        // /usr/bin/true always exits 0 regardless of arguments
        let url = URL(fileURLWithPath: "/usr/bin/true")
        XCTAssertTrue(verifyBinary(url))
    }

    func testVerifyBinaryWithNonexistent() {
        let url = tempDir.appendingPathComponent("does-not-exist-xyz")
        XCTAssertFalse(verifyBinary(url))
    }

    func testVerifyBinaryWithNonExecutable() {
        // A regular text file is not executable → Process.run() throws → returns false
        let url = writeBinary("not-executable")
        XCTAssertFalse(verifyBinary(url))
    }

    // MARK: - restoreBackup

    func testRestoreBackupSucceeds() {
        let originalBytes: [UInt8] = Array("original content".utf8)
        let binary = writeBinary("claude", bytes: originalBytes)
        let noSoul = tempDir.appendingPathComponent("no-soul.json")

        ensureBackup(binary, backupDir: backupDir, soulPath: noSoul)

        // Modify the binary
        try! Data("modified content".utf8).write(to: binary)

        // Restore (skip resign since our fake binary isn't a real Mach-O)
        let success = restoreBackup(binary, backupDir: backupDir, soulPath: noSoul, skipResign: true)
        XCTAssertTrue(success)

        let restored = try? Data(contentsOf: binary)
        XCTAssertEqual(restored, Data(originalBytes))
    }

    func testRestoreBackupFailsWithoutBackup() {
        let binary = writeBinary("claude")
        // No backup created
        let success = restoreBackup(binary, backupDir: backupDir,
                                     soulPath: tempDir.appendingPathComponent("no-soul.json"),
                                     skipResign: true)
        XCTAssertFalse(success)
    }

    func testRestoreBackupFailsOnHashMismatch() {
        let binary = writeBinary("claude", bytes: Array("original".utf8))
        let noSoul = tempDir.appendingPathComponent("no-soul.json")

        ensureBackup(binary, backupDir: backupDir, soulPath: noSoul)

        // Tamper with the backup file
        let backup = backupFile(for: binary)
        try! Data("tampered!".utf8).write(to: backup)

        let success = restoreBackup(binary, backupDir: backupDir, soulPath: noSoul, skipResign: true)
        XCTAssertFalse(success, "Restore should refuse when backup hash doesn't match stored hash")
    }

    func testRestoreBackupSkipsIntegrityCheckWithoutHash() {
        let originalBytes: [UInt8] = Array("original content".utf8)
        let binary = writeBinary("claude", bytes: originalBytes)
        let noSoul = tempDir.appendingPathComponent("no-soul.json")

        ensureBackup(binary, backupDir: backupDir, soulPath: noSoul)

        // Remove the hash file (simulate pre-security backup)
        let hashFile = backupDir.appendingPathComponent("binary-sha256.txt")
        try! FileManager.default.removeItem(at: hashFile)

        // Modify the binary
        try! Data("modified".utf8).write(to: binary)

        let success = restoreBackup(binary, backupDir: backupDir, soulPath: noSoul, skipResign: true)
        XCTAssertTrue(success, "Restore should still work when hash file is missing")

        let restored = try? Data(contentsOf: binary)
        XCTAssertEqual(restored, Data(originalBytes))
    }

    func testRestoreBackupRestoresSoul() {
        let binary = writeBinary("claude")
        let soul = tempDir.appendingPathComponent("soul.json")
        let originalSoul = "{\"companion\":{\"name\":\"Original\"}}"
        try! originalSoul.data(using: .utf8)!.write(to: soul)

        ensureBackup(binary, backupDir: backupDir, soulPath: soul)

        // Modify the soul
        try! "{\"companion\":{\"name\":\"Modified\"}}".data(using: .utf8)!.write(to: soul)

        let success = restoreBackup(binary, backupDir: backupDir, soulPath: soul, skipResign: true)
        XCTAssertTrue(success)

        let restored = try? String(contentsOf: soul, encoding: .utf8)
        XCTAssertEqual(restored, originalSoul)
    }

    // MARK: - resignBinary

    func testResignBinaryFailsOnNonexistent() {
        let missing = tempDir.appendingPathComponent("nonexistent")
        XCTAssertFalse(resignBinary(missing))
    }

    func testResignBinarySucceedsOnExistingFile() {
        // codesign --force --sign - will ad-hoc sign any existing file, including non-binaries
        let textFile = writeBinary("plain-text", bytes: Array("not a binary".utf8))
        XCTAssertTrue(resignBinary(textFile))
    }
}
