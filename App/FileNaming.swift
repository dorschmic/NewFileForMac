import Foundation

enum FileNaming {
    /// Legt eine Datei unter einem freien Namen an: "Name.ext", "Name 2.ext", …
    ///
    /// `place` bekommt den Kandidaten-Pfad und kopiert/verschiebt dorthin.
    /// `copyItem`/`moveItem` überschreiben nie, sondern werfen
    /// `fileWriteFileExists` – dann probieren wir einfach die nächste Nummer.
    /// So gibt es auch bei zwei gleichzeitigen Aufträgen keinen Überschreiber.
    static func placeUniquely(in directory: URL, baseName: String, ext: String,
                              _ place: (URL) throws -> Void) throws -> URL {
        var number = 1
        while true {
            let name = number == 1 ? baseName : "\(baseName) \(number)"
            let candidate = directory.appendingPathComponent(ext.isEmpty ? name : "\(name).\(ext)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                do {
                    try place(candidate)
                    return candidate
                } catch let error as CocoaError where error.code == .fileWriteFileExists {
                    // jemand war schneller → nächste Nummer
                }
            }
            number += 1
        }
    }
}
