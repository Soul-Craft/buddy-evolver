import XCTest
@testable import BuddyPatcherLib

final class AnalyzeTests: XCTestCase {

    // MARK: - formatNumber

    func testFormatNumberZero() {
        XCTAssertEqual(formatNumber(0), "0")
    }

    func testFormatNumberSmall() {
        XCTAssertEqual(formatNumber(42), "42")
    }

    func testFormatNumberThousands() {
        let result = formatNumber(1_000)
        // Locale-dependent separator — verify it's not just "1000"
        XCTAssertTrue(result.count > 4, "Expected locale-formatted string, got '\(result)'")
    }

    func testFormatNumberLarge() {
        let result = formatNumber(10_000_000)
        // Should contain separators (at least 10 chars with commas/periods)
        XCTAssertTrue(result.count >= 10, "Expected formatted number, got '\(result)'")
    }

    // MARK: - runAnalyze (crash-freedom tests)

    func testRunAnalyzeWithKnownAnchor() {
        // Build a synthetic binary containing the v90 species anchor
        let varMap = knownVarMaps[0]
        let speciesArray = buildSpeciesArray(varMap)
        let data = syntheticBinary(with: [speciesArray])

        // Should not crash — analyze prints to stdout
        runAnalyze(data: data, binaryPath: URL(fileURLWithPath: "/tmp/test"))
    }

    func testRunAnalyzeWithRarityWeights() {
        let rarity = buildRarityString()
        let data = syntheticBinary(with: [rarity])

        runAnalyze(data: data, binaryPath: URL(fileURLWithPath: "/tmp/test"))
    }

    func testRunAnalyzeWithShinyThreshold() {
        let shiny = buildShinyThreshold()
        let data = syntheticBinary(with: [shiny])

        runAnalyze(data: data, binaryPath: URL(fileURLWithPath: "/tmp/test"))
    }

    func testRunAnalyzeWithEmptyBinary() {
        // No patterns at all — exercises the candidate-scanning fallback
        let data = [UInt8](repeating: 0x00, count: 500)

        runAnalyze(data: data, binaryPath: URL(fileURLWithPath: "/tmp/test"))
    }

    func testRunAnalyzeWithAllPatterns() {
        // Full synthetic binary with all patchable patterns
        let varMap = knownVarMaps[0]
        let speciesArray = buildSpeciesArray(varMap)
        let rarity = buildRarityString()
        let shiny = buildShinyThreshold()
        let data = syntheticBinary(with: [speciesArray, rarity, shiny])

        runAnalyze(data: data, binaryPath: URL(fileURLWithPath: "/tmp/test"))
    }
}
