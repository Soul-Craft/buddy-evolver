import Foundation

// ── Orchestration ────────────────────────────────────────────────────
//
// Pure patch pipeline extracted from main.swift for testability.
// Takes input data + options, returns patched data + metadata about what was applied.
// Does not touch the filesystem, backups, codesign, or process state.

public struct PipelineResult {
    public let patchedData: [UInt8]
    public let totalPatches: Int
    public let varMap: [String: String]
    public let anchor: [UInt8]
    public let warnings: [String]

    public init(patchedData: [UInt8], totalPatches: Int, varMap: [String: String],
                anchor: [UInt8], warnings: [String]) {
        self.patchedData = patchedData
        self.totalPatches = totalPatches
        self.varMap = varMap
        self.anchor = anchor
        self.warnings = warnings
    }
}

/// Detects whether any work is requested in the given options.
public func hasPatchWork(_ opts: Options) -> Bool {
    return opts.species != nil || opts.rarity != nil || opts.shiny || opts.noShiny ||
        opts.emoji != nil || opts.name != nil || opts.personality != nil || opts.stats != nil
}

/// Apply all requested patches to the given data buffer.
/// Pure function — no filesystem or process side effects.
public func runPatchPipeline(data: [UInt8], opts: Options) -> PipelineResult {
    var patched = data
    var totalPatches = 0
    var warnings: [String] = []

    // Detect var map
    let varMap: [String: String]
    let anchor: [UInt8]
    if let detected = detectVarMap(in: patched) {
        varMap = detected.varMap
        anchor = detected.anchor
    } else {
        varMap = knownVarMaps[0]
        anchor = anchorForMap(varMap)
        warnings.append("No known anchor matched — using newest variable map as fallback")
    }

    // Species
    if let species = opts.species {
        totalPatches += patchSpecies(&patched, target: species, anchor: anchor, varMap: varMap)
    }

    // Rarity
    if let rarity = opts.rarity {
        totalPatches += patchRarity(&patched, target: rarity)
    }

    // Shiny (shiny takes precedence over noShiny if both set)
    if opts.shiny {
        totalPatches += patchShiny(&patched, makeShiny: true)
    } else if opts.noShiny {
        totalPatches += patchShiny(&patched, makeShiny: false)
    }

    // Art (emoji) — requires species to know which art block to target
    if let emoji = opts.emoji, let species = opts.species {
        totalPatches += patchArt(&patched, target: species, emoji: emoji, varMap: varMap)
    } else if opts.emoji != nil && opts.species == nil {
        warnings.append("--emoji requires --species to know which art to replace")
    }

    return PipelineResult(
        patchedData: patched,
        totalPatches: totalPatches,
        varMap: varMap,
        anchor: anchor,
        warnings: warnings
    )
}
