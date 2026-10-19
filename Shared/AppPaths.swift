import Foundation

/// Gemeinsame Pfade für App und Finder-Extension.
enum AppPaths {
    /// Das *echte* Home-Verzeichnis des Benutzers.
    ///
    /// In der Sandbox liefert `FileManager.default.homeDirectoryForCurrentUser`
    /// den Container (~/Library/Containers/<id>/Data). Die Extension braucht
    /// aber den echten Pfad, deshalb fragen wir die Benutzerdatenbank direkt.
    static let realHome: URL = {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }()

    /// ~/Library/Application Support/NewFileForMac
    static let supportDir = realHome
        .appendingPathComponent("Library/Application Support/NewFileForMac", isDirectory: true)

    /// Vorlagen für "Neue Datei" – jede Datei hier wird zu einem Menüeintrag.
    static let templatesDir = supportDir.appendingPathComponent("Templates", isDirectory: true)

    /// Eigene Konvertierungsregeln (haben Vorrang).
    static let rulesFile = supportDir.appendingPathComponent("conversions.json")

    /// Mitgelieferte Regeln – wird bei jedem App-Start überschrieben.
    static let defaultRulesFile = supportDir.appendingPathComponent("conversions.default.json")
}
