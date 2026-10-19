import Foundation

/// Kopiert die mitgelieferten Vorlagen und Regeln aus dem App-Bundle nach
/// ~/Library/Application Support/NewFileForMac, wo man sie frei ändern kann.
enum Defaults {
    private static let fm = FileManager.default
    private static var bundledTemplates: URL? { Bundle.main.url(forResource: "Templates", withExtension: nil) }
    private static var bundledRules: URL? { Bundle.main.url(forResource: "conversions", withExtension: "json") }

    static func installIfNeeded() {
        try? fm.createDirectory(at: AppPaths.supportDir, withIntermediateDirectories: true)
        // Vorlagen nur beim allerersten Start kopieren – sonst kämen
        // absichtlich gelöschte Vorlagen bei jedem Start zurück.
        if !fm.fileExists(atPath: AppPaths.templatesDir.path) {
            restoreMissingTemplates()
        }
        if !fm.fileExists(atPath: AppPaths.rulesFile.path), let bundledRules {
            try? fm.copyItem(at: bundledRules, to: AppPaths.rulesFile)
        }
    }

    static func restoreMissingTemplates() {
        guard let bundledTemplates else { return }
        try? fm.createDirectory(at: AppPaths.templatesDir, withIntermediateDirectories: true)
        for name in (try? fm.contentsOfDirectory(atPath: bundledTemplates.path)) ?? [] where !name.hasPrefix(".") {
            let target = AppPaths.templatesDir.appendingPathComponent(name)
            if !fm.fileExists(atPath: target.path) {
                try? fm.copyItem(at: bundledTemplates.appendingPathComponent(name), to: target)
            }
        }
    }

    /// Ersetzt conversions.json durch die Standardversion (alte → .bak).
    static func resetRules() {
        guard let bundledRules else { return }
        let backup = AppPaths.rulesFile.appendingPathExtension("bak")
        try? fm.removeItem(at: backup)
        try? fm.moveItem(at: AppPaths.rulesFile, to: backup)
        try? fm.copyItem(at: bundledRules, to: AppPaths.rulesFile)
    }
}
