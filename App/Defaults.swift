import Foundation

/// Kopiert die mitgelieferten Vorlagen und Regeln aus dem App-Bundle nach
/// ~/Library/Application Support/NewFileForMac, wo man sie frei ändern kann.
enum Defaults {
    private static let fm = FileManager.default
    private static var bundledTemplates: URL? { Bundle.main.url(forResource: "Templates", withExtension: nil) }
    private static var bundledRules: URL? { Bundle.main.url(forResource: "conversions", withExtension: "json") }

    /// Leere Datei für eigene Regeln.
    private static let userRulesSkeleton = """
    {
      "_comment": "Eigene Regeln – haben Vorrang vor conversions.default.json. Die Standarddatei wird bei jedem App-Start erneuert, Änderungen gehören deshalb hierher. Aufbau und Beispiele: siehe conversions.default.json.",
      "rules": [
      ]
    }

    """

    static func installIfNeeded() {
        try? fm.createDirectory(at: AppPaths.supportDir, withIntermediateDirectories: true)
        // Vorlagen nur beim allerersten Start kopieren – sonst kämen
        // absichtlich gelöschte Vorlagen bei jedem Start zurück.
        if !fm.fileExists(atPath: AppPaths.templatesDir.path) {
            restoreMissingTemplates()
        }
        installRules()
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

    /// Standardregeln immer erneuern (so kommen Updates an),
    /// eigene Regeldatei nur anlegen, wenn sie fehlt.
    private static func installRules() {
        if let bundledRules {
            try? fm.removeItem(at: AppPaths.defaultRulesFile)
            try? fm.copyItem(at: bundledRules, to: AppPaths.defaultRulesFile)
        }
        migrateOldRulesFile()
        if !fm.fileExists(atPath: AppPaths.rulesFile.path) {
            try? userRulesSkeleton.write(to: AppPaths.rulesFile, atomically: true, encoding: .utf8)
        }
    }

    /// Version 0.1 hat die Standardregeln direkt nach conversions.json kopiert.
    /// Diese alte Kopie würde die neuen Standardregeln überdecken → zur Seite legen.
    private static func migrateOldRulesFile() {
        guard let content = try? String(contentsOf: AppPaths.rulesFile, encoding: .utf8),
              content.contains("\"_comment\": \"Video → Audio / GIF\"")
        else { return }
        let backup = AppPaths.rulesFile.appendingPathExtension("bak")
        try? fm.removeItem(at: backup)
        try? fm.moveItem(at: AppPaths.rulesFile, to: backup)
    }
}
