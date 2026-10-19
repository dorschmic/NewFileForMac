import Foundation

/// Inhalt von conversions.json.
///
/// ```json
/// {
///   "tools": { "ffmpeg": ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"] },
///   "rules": [
///     { "inputs": ["mp4", "mov"],
///       "outputs": [ { "ext": "mp3", "label": "MP3 (Audio)", "tool": "ffmpeg",
///                      "args": ["-i", "{input}", "-vn", "{output}"] } ] }
///   ]
/// }
/// ```
/// Platzhalter in `args`: {input}, {output}, {outputDir}, {name}
/// (Name der Eingabedatei ohne Endung). Unbekannte Schlüssel wie "_comment"
/// ignoriert der JSONDecoder einfach.
struct ConversionConfig: Codable {
    /// Werkzeugname → mögliche Pfade (der erste existierende gewinnt).
    var tools: [String: [String]] = [:]
    var rules: [ConversionRule]

    static func load(from url: URL = AppPaths.rulesFile) throws -> ConversionConfig {
        try JSONDecoder().decode(ConversionConfig.self, from: Data(contentsOf: url))
    }

    /// Alle Ziel-Formate für eine Endung. Gibt es dasselbe Ziel in mehreren
    /// Regeln, gewinnt die erste. Ziel == Quelle wird ausgelassen.
    func outputs(forExtension ext: String) -> [ConversionOutput] {
        let ext = ext.lowercased()
        var seen = Set<String>()
        var result: [ConversionOutput] = []
        for rule in rules where rule.inputs.contains(where: { $0.lowercased() == ext }) {
            for output in rule.outputs where output.ext.lowercased() != ext {
                if seen.insert(output.ext.lowercased()).inserted {
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
            let allowed = Set(outputs(forExtension: file.pathExtension).map { $0.ext.lowercased() })
            result.removeAll { !allowed.contains($0.ext.lowercased()) }
        }
        return result
    }
}

struct ConversionRule: Codable {
    var inputs: [String]
    var outputs: [ConversionOutput]
}

struct ConversionOutput: Codable {
    var ext: String
    var label: String
    var tool: String
    var args: [String]
}
