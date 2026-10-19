import Foundation

/// Konvertierungsregeln.
///
/// Zwei Dateien in ~/Library/Application Support/NewFileForMac:
/// - conversions.default.json – mitgeliefert, wird bei jedem App-Start erneuert
/// - conversions.json         – eigene Regeln, haben Vorrang
///
/// ```json
/// {
///   "tools": { "soffice": ["/Applications/LibreOffice.app/Contents/MacOS/soffice"] },
///   "installHints": { "soffice": "brew install --cask libreoffice" },
///   "rules": [
///     { "inputs": ["mp4", "mov"],
///       "outputs": [ { "ext": "mp3", "label": "MP3", "group": "Audio", "tool": "ffmpeg",
///                      "args": ["-i", "{input}", "-vn", "{output}"] },
///                    { "ext": "pdf", "label": "PDF", "via": "html" } ] }
///   ]
/// }
/// ```
/// - Platzhalter in `args`: {input}, {output}, {outputDir}, {name}
/// - `group`: Eintrag landet in einem Untermenü dieses Namens
/// - `via`: erst in dieses Format konvertieren, dann von dort ins Ziel
/// - Gibt es dasselbe Ziel mehrfach, wird der Reihe nach das erste genommen,
///   dessen Werkzeug installiert ist.
/// - Eingebaute Werkzeuge: siehe `BuiltinTool`.
/// Unbekannte Schlüssel wie "_comment" ignoriert der JSONDecoder.
struct ConversionConfig: Codable {
    /// Werkzeugname → mögliche Pfade (der erste existierende gewinnt).
    var tools: [String: [String]]?
    /// Werkzeugname → Installationshinweis für Fehlermeldungen.
    var installHints: [String: String]?
    var rules: [ConversionRule]

    static func load(from url: URL) throws -> ConversionConfig {
        try JSONDecoder().decode(ConversionConfig.self, from: Data(contentsOf: url))
    }

    /// Eigene Regeln + Standardregeln (eigene zuerst, also mit Vorrang).
    /// Ein Fehler in der eigenen Datei wird gemeldet, die Standardregeln
    /// gelten dann trotzdem.
    static func loadMerged(onUserFileError: (Error) -> Void = { _ in }) -> ConversionConfig {
        var merged = (try? load(from: AppPaths.defaultRulesFile))
            ?? ConversionConfig(tools: [:], installHints: [:], rules: [])
        if FileManager.default.fileExists(atPath: AppPaths.rulesFile.path) {
            do {
                let user = try load(from: AppPaths.rulesFile)
                merged.rules = user.rules + merged.rules
                merged.tools = (merged.tools ?? [:]).merging(user.tools ?? [:]) { _, mine in mine }
                merged.installHints = (merged.installHints ?? [:]).merging(user.installHints ?? [:]) { _, mine in mine }
            } catch {
                onUserFileError(error)
            }
        }
        return merged
    }

    /// Alle Regel-Einträge für Quelle → Ziel, in Prioritätsreihenfolge.
    func candidates(from inputExt: String, to targetExt: String) -> [ConversionOutput] {
        rules.filter { $0.accepts(inputExt) }
            .flatMap(\.outputs)
            .filter { FileFormat.same($0.ext, targetExt) }
    }

    /// Ziel-Formate für eine Endung fürs Menü – jedes Ziel einmal,
    /// Ziel == Quelle (auch "jpeg" == "jpg") ausgelassen.
    func outputs(forExtension ext: String) -> [ConversionOutput] {
        var seen = Set<String>()
        var result: [ConversionOutput] = []
        for rule in rules where rule.accepts(ext) {
            for output in rule.outputs where !FileFormat.same(output.ext, ext) {
                if seen.insert(FileFormat.canonical(output.ext)).inserted {
                    result.append(output)
                }
            }
        }
        return result
    }

    /// Ziel-Formate, die für *alle* ausgewählten Dateien möglich sind
    /// (Schnittmenge, Reihenfolge wie bei der ersten Datei).
    func commonOutputs(for files: [URL]) -> [ConversionOutput] {
        guard let first = files.first else { return [] }
        var result = outputs(forExtension: first.pathExtension)
        for file in files.dropFirst() {
            let allowed = Set(outputs(forExtension: file.pathExtension).map { FileFormat.canonical($0.ext) })
            result.removeAll { !allowed.contains(FileFormat.canonical($0.ext)) }
        }
        return result
    }
}

struct ConversionRule: Codable {
    var inputs: [String]
    var outputs: [ConversionOutput]

    func accepts(_ ext: String) -> Bool {
        inputs.contains { FileFormat.same($0, ext) }
    }
}

struct ConversionOutput: Codable {
    var ext: String
    var label: String
    var group: String?
    var tool: String?
    var args: [String]?
    var via: String?
}

/// Werkzeuge, die die App selbst mitbringt (kein externes Programm nötig).
enum BuiltinTool: String {
    /// Inhalt unverändert kopieren, nur die Endung ändert sich (txt → sh, py → txt …).
    case copy
    /// Text/RTF/DOCX/HTML/… über das macOS-Textsystem als PDF (A4) drucken.
    case textpdf
    /// Text aus einem PDF extrahieren (PDFKit).
    case pdftext
}

enum FileFormat {
    /// Endungen, die dasselbe Format bezeichnen.
    private static let aliases: [String: String] = [
        "jpeg": "jpg", "tif": "tiff", "htm": "html", "yml": "yaml",
        "heif": "heic", "aif": "aiff", "markdown": "md", "text": "txt",
    ]

    static func canonical(_ ext: String) -> String {
        let lower = ext.lowercased()
        return aliases[lower] ?? lower
    }

    static func same(_ a: String, _ b: String) -> Bool {
        canonical(a) == canonical(b)
    }
}
