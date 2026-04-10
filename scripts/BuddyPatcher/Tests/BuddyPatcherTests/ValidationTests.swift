import XCTest
@testable import BuddyPatcherLib

final class ValidationTests: XCTestCase {

    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BuddyPatcherTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - validateEmoji

    func testValidateEmojiAcceptsSingleEmoji() {
        XCTAssertNotNil(validateEmoji("🔥"))
    }

    func testValidateEmojiAcceptsFlagEmoji() {
        // Flag emojis are 2 regional indicator scalars but 1 grapheme cluster
        XCTAssertNotNil(validateEmoji("🇺🇸"))
    }

    func testValidateEmojiReturnsSameValue() {
        XCTAssertEqual(validateEmoji("🐧"), "🐧")
    }

    func testValidateEmojiRejectsZWJSequence() {
        // ZWJ (U+200D) scalars have isEmoji=false, so ZWJ sequences are rejected
        XCTAssertNil(validateEmoji("👨‍👩‍👧‍👦"))
    }

    func testValidateEmojiRejectsMultiChar() {
        XCTAssertNil(validateEmoji("AB"))
    }

    func testValidateEmojiRejectsASCIILetter() {
        XCTAssertNil(validateEmoji("X"))
    }

    func testValidateEmojiRejectsEmptyString() {
        XCTAssertNil(validateEmoji(""))
    }

    func testValidateEmojiRejectsLongString() {
        XCTAssertNil(validateEmoji("hello world"))
    }

    // MARK: - validateName

    func testValidateNameAcceptsNormal() {
        XCTAssertEqual(validateName("Aethos"), "Aethos")
    }

    func testValidateNameTrimsWhitespace() {
        XCTAssertEqual(validateName("  Buddy  "), "Buddy")
    }

    func testValidateNameRejectsEmpty() {
        XCTAssertNil(validateName(""))
    }

    func testValidateNameRejectsWhitespaceOnly() {
        XCTAssertNil(validateName("   "))
    }

    func testValidateNameAccepts100Chars() {
        let name = String(repeating: "A", count: 100)
        XCTAssertNotNil(validateName(name))
    }

    func testValidateNameRejects101Chars() {
        let name = String(repeating: "A", count: 101)
        XCTAssertNil(validateName(name))
    }

    func testValidateNameRejectsControlChar() {
        XCTAssertNil(validateName("test\u{01}name"))
    }

    func testValidateNameAllowsTab() {
        // U+0009 (tab) is explicitly allowed
        XCTAssertNotNil(validateName("test\tname"))
    }

    // MARK: - validatePersonality

    func testValidatePersonalityAcceptsNormal() {
        XCTAssertEqual(validatePersonality("A fiery friend"), "A fiery friend")
    }

    func testValidatePersonalityTrimsWhitespace() {
        XCTAssertEqual(validatePersonality("  wise  "), "wise")
    }

    func testValidatePersonalityRejectsEmpty() {
        XCTAssertNil(validatePersonality(""))
    }

    func testValidatePersonalityAccepts500Chars() {
        let text = String(repeating: "B", count: 500)
        XCTAssertNotNil(validatePersonality(text))
    }

    func testValidatePersonalityRejects501Chars() {
        let text = String(repeating: "B", count: 501)
        XCTAssertNil(validatePersonality(text))
    }

    func testValidatePersonalityAllowsTab() {
        XCTAssertNotNil(validatePersonality("line\ttab"))
    }

    func testValidatePersonalityRejectsControlChar() {
        XCTAssertNil(validatePersonality("test\u{02}text"))
    }

    // MARK: - validateStats

    func testValidateStatsAcceptsValid() {
        let result = validateStats("{\"debugging\":80,\"chaos\":50}")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?["debugging"] as? Int, 80)
        XCTAssertEqual(result?["chaos"] as? Int, 50)
    }

    func testValidateStatsRejectsInvalidJSON() {
        XCTAssertNil(validateStats("not json"))
    }

    func testValidateStatsRejectsUnknownKey() {
        XCTAssertNil(validateStats("{\"hacking\":99}"))
    }

    func testValidateStatsRejectsOver100() {
        XCTAssertNil(validateStats("{\"debugging\":999}"))
    }

    func testValidateStatsRejectsNegative() {
        XCTAssertNil(validateStats("{\"chaos\":-5}"))
    }

    func testValidateStatsAcceptsAllKnownKeys() {
        let json = "{\"debugging\":50,\"patience\":50,\"chaos\":50,\"wisdom\":50,\"snark\":50}"
        let result = validateStats(json)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 5)
    }

    func testValidateStatsAcceptsBoundaryValues() {
        let result = validateStats("{\"debugging\":0,\"chaos\":100}")
        XCTAssertNotNil(result)
    }

    // MARK: - validateBinaryPath

    func testValidateBinaryPathAcceptsMachO64() {
        let path = tempDir.appendingPathComponent("test-binary")
        // Write Mach-O 64-bit magic (0xFEEDFACF) + padding
        var data = Data([0xCF, 0xFA, 0xED, 0xFE]) // little-endian MH_MAGIC_64
        data.append(Data(count: 100))
        try! data.write(to: path)
        XCTAssertNotNil(validateBinaryPath(path.path))
    }

    func testValidateBinaryPathAcceptsFatBinary() {
        let path = tempDir.appendingPathComponent("test-fat")
        // Write FAT_MAGIC (0xCAFEBABE) — big-endian
        var data = Data([0xCA, 0xFE, 0xBA, 0xBE])
        data.append(Data(count: 100))
        try! data.write(to: path)
        XCTAssertNotNil(validateBinaryPath(path.path))
    }

    func testValidateBinaryPathRejectsNonexistent() {
        XCTAssertNil(validateBinaryPath("/tmp/buddy_test_nonexistent_xyz_12345"))
    }

    func testValidateBinaryPathRejectsDirectory() {
        XCTAssertNil(validateBinaryPath(tempDir.path))
    }

    func testValidateBinaryPathRejectsNonMachO() {
        let path = tempDir.appendingPathComponent("text-file")
        try! "hello world".data(using: .utf8)!.write(to: path)
        XCTAssertNil(validateBinaryPath(path.path))
    }

    func testValidateBinaryPathResolvesSymlink() {
        let realPath = tempDir.appendingPathComponent("real-binary")
        var data = Data([0xCF, 0xFA, 0xED, 0xFE])
        data.append(Data(count: 100))
        try! data.write(to: realPath)

        let linkPath = tempDir.appendingPathComponent("link-binary")
        try! FileManager.default.createSymbolicLink(at: linkPath, withDestinationURL: realPath)

        let result = validateBinaryPath(linkPath.path)
        XCTAssertNotNil(result)
        // Resolved URL should point to real file
        XCTAssertTrue(result!.path.contains("real-binary"))
    }

    func testValidateBinaryPathRejectsTooSmall() {
        let path = tempDir.appendingPathComponent("tiny")
        try! Data([0xCF, 0xFA]).write(to: path) // Only 2 bytes, need 4
        XCTAssertNil(validateBinaryPath(path.path))
    }
}
