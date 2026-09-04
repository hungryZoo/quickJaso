import Foundation

public enum FilenameNormalizer {
    public static func normalizedNFC(_ name: String) -> String {
        name.precomposedStringWithCanonicalMapping
    }

    public static func isNFC(_ name: String) -> Bool {
        // Swift String equality is canonically equivalent; compare code units to detect NFD.
        Array(name.utf8) == Array(normalizedNFC(name).utf8)
    }

    public static func classify(_ name: String) -> NormalizationStatus {
        isNFC(name) ? .alreadyNFC : .needsRename
    }
}
