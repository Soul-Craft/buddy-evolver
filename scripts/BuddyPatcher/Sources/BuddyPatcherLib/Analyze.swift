import Foundation

public func runAnalyze(data: [UInt8], binaryPath: URL) {
    print("  Binary Analysis")
    print("  ═══════════════")
    print()

    // Species anchor search
    print("  --- Species Anchor ---")
    var foundAnchor = false
    for varMap in knownVarMaps {
        let anchor = anchorForMap(varMap)
        let anchorStr = String(bytes: anchor, encoding: .utf8) ?? "?"
        let anchors = findAll(in: data, pattern: anchor)
        if !anchors.isEmpty {
            print("  [+] Anchor found (\(anchors.count) occurrence(s)), first at offset 0x\(String(anchors[0], radix: 16)): \(anchorStr)")
            // Find the array-literal occurrence using same logic as patchSpecies:
            // scan backward from each anchor — [ must be within 2 bytes (immediately adjacent)
            for idx in anchors {
                var arrStart = idx
                while arrStart > 0 && data[arrStart] != 0x5B { arrStart -= 1 }
                guard idx - arrStart <= 2 else { continue }
                var arrEnd = idx
                while arrEnd < data.count && data[arrEnd] != 0x5D { arrEnd += 1 }
                let arrContent = Array(data[arrStart...arrEnd])
                if let str = String(bytes: arrContent, encoding: .utf8) {
                    print("  [+] Species array: \(str)")
                }
                break
            }
            foundAnchor = true
            break
        }
    }
    if !foundAnchor {
        print("  [!] Anchor NOT FOUND — binary structure has changed")
        // Search for 3-char variable ref patterns
        var candidates = Set<String>()
        for i in 0..<(data.count - 2) {
            let c0 = data[i], c1 = data[i+1], c2 = data[i+2]
            // Pattern: [A-Za-z][0-9]_ (e.g., GL_, b0_)
            let isLetter = (c0 >= 0x41 && c0 <= 0x5A) || (c0 >= 0x61 && c0 <= 0x7A)
            let isDigit = c1 >= 0x30 && c1 <= 0x39
            let isUnder = c2 == 0x5F // _
            if isLetter && isDigit && isUnder {
                if let s = String(bytes: [c0, c1, c2], encoding: .utf8) {
                    candidates.insert(s)
                }
            }
        }
        // Also check [A-Za-z][A-Z]_ pattern (e.g., GL_, VL_)
        for i in 0..<(data.count - 2) {
            let c0 = data[i], c1 = data[i+1], c2 = data[i+2]
            let isLetter = (c0 >= 0x41 && c0 <= 0x5A) || (c0 >= 0x61 && c0 <= 0x7A)
            let isUpper = c1 >= 0x41 && c1 <= 0x5A
            let isUnder = c2 == 0x5F
            if isLetter && isUpper && isUnder {
                if let s = String(bytes: [c0, c1, c2], encoding: .utf8) {
                    candidates.insert(s)
                }
            }
        }
        let sorted = candidates.sorted()
        print("  [?] Found \(sorted.count) potential 3-byte variable refs:")
        for c in sorted.prefix(30) {
            print("      \(c)")
        }
    }

    print()

    // Rarity weight search
    print("  --- Rarity Weights ---")
    let originalWeights = utf8Bytes("common:60,uncommon:25,rare:10,epic:4,legendary:1")
    if let idx = findFirst(in: data, pattern: originalWeights) {
        print("  [+] Original rarity weights found at 0x\(String(idx, radix: 16))")
    } else {
        // Try patched variants
        var foundRarity = false
        for r in validRarities {
            let rarityWeights: [(String, String)] = [
                ("common", "60"), ("uncommon", "25"), ("rare", "10"), ("epic", "4"), ("legendary", "1")
            ]
            var parts: [String] = []
            for (rarity, weight) in rarityWeights {
                if rarity == r {
                    parts.append("\(rarity):\(weight.count == 2 ? "01" : "1")")
                } else {
                    parts.append("\(rarity):\(weight.count == 2 ? "00" : "0")")
                }
            }
            let pattern = utf8Bytes(parts.joined(separator: ","))
            if let idx = findFirst(in: data, pattern: pattern) {
                let patternStr = String(bytes: pattern, encoding: .utf8) ?? "?"
                print("  [+] Rarity weights (patched) found at 0x\(String(idx, radix: 16)): \(patternStr)")
                foundRarity = true
                break
            }
        }
        if !foundRarity {
            print("  [!] Rarity weights NOT FOUND")
        }
    }

    print()

    // Shiny threshold search
    print("  --- Shiny Threshold ---")
    var foundShiny = false
    for pattern in [utf8Bytes("H()<0.01"), utf8Bytes("H()<1.01")] {
        if let idx = findFirst(in: data, pattern: pattern) {
            let patternStr = String(bytes: pattern, encoding: .utf8) ?? "?"
            print("  [+] Shiny threshold found at 0x\(String(idx, radix: 16)): \(patternStr)")
            foundShiny = true
            break
        }
    }
    if !foundShiny {
        print("  [!] Shiny threshold NOT FOUND")
    }
}

public func formatNumber(_ n: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
}
