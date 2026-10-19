import Foundation

/// Eine Vorlage = eine Datei im Vorlagen-Ordner.
///
/// Dateiname "10 Textdokument.txt" → Menütitel "Textdokument", Endung "txt".
/// Die führende Zahl dient nur der Sortierung und wird ausgeblendet.
struct FileTemplate {
    let fileName: String

    var fileExtension: String { (fileName as NSString).pathExtension }

    var title: String {
        let name = (fileName as NSString).deletingPathExtension
        return name.replacingOccurrences(of: #"^\d+\s+"#, with: "", options: .regularExpression)
    }
}

enum TemplateStore {
    /// Liest den Vorlagen-Ordner, sortiert wie im Finder ("2" vor "10").
    static func load(from dir: URL = AppPaths.templatesDir) -> [FileTemplate] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return names
            .filter { !$0.hasPrefix(".") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .map(FileTemplate.init)
    }
}
