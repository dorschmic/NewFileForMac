import Foundation

/// Nimmt Aufträge (URLs von der Extension) an und führt sie aus.
@MainActor
final class JobRunner: ObservableObject {
    static let shared = JobRunner()

    /// Für die Anzeige im Menüleisten-Menü.
    @Published private(set) var activeJobs = 0

    func handle(_ url: URL) {
        guard let job = Job(url: url) else {
            Notifier.shared.post(title: "Unbekannter Auftrag", body: url.absoluteString)
            return
        }
        switch job {
        case let .newFile(template, directory):
            createFile(template: template, in: URL(fileURLWithPath: directory, isDirectory: true))
        case let .convert(files, targetExtension):
            convert(files.map { URL(fileURLWithPath: $0) }, to: targetExtension)
        }
    }

    // MARK: - Neue Datei

    private func createFile(template: String, in directory: URL) {
        let source = AppPaths.templatesDir.appendingPathComponent(template)
        let ext = (template as NSString).pathExtension
        do {
            let created = try FileNaming.placeUniquely(in: directory, baseName: "Neue Datei", ext: ext) {
                try FileManager.default.copyItem(at: source, to: $0)
            }
            // copyItem übernimmt die Datumsangaben der Vorlage – auf "jetzt" setzen.
            let now = Date()
            try? FileManager.default.setAttributes([.creationDate: now, .modificationDate: now],
                                                   ofItemAtPath: created.path)
        } catch {
            Notifier.shared.post(title: "Neue Datei fehlgeschlagen", body: error.localizedDescription)
        }
    }

    // MARK: - Konvertieren

    private func convert(_ files: [URL], to targetExtension: String) {
        let config: ConversionConfig
        do { config = try ConversionConfig.load() } catch {
            Notifier.shared.post(title: "conversions.json fehlerhaft", body: "\(error)")
            return
        }

        activeJobs += 1
        Task {
            // Nacheinander – ffmpeg & Co. nutzen ohnehin mehrere Kerne.
            var created: [URL] = []
            var failures: [String] = []
            for file in files {
                do {
                    created.append(try await Converter.convert(file, to: targetExtension, config: config))
                } catch {
                    failures.append("\(file.lastPathComponent): \(error.localizedDescription)")
                }
            }
            activeJobs -= 1
            report(created: created, failures: failures, target: targetExtension)
        }
    }

    private func report(created: [URL], failures: [String], target: String) {
        let ext = target.uppercased()
        if failures.isEmpty {
            let body = created.count == 1 ? created[0].lastPathComponent : "\(created.count) Dateien"
            Notifier.shared.post(title: "In \(ext) konvertiert", body: body, reveal: created)
        } else {
            let title = created.isEmpty ? "Konvertierung fehlgeschlagen"
                                        : "\(created.count) konvertiert, \(failures.count) fehlgeschlagen"
            Notifier.shared.post(title: title, body: failures.joined(separator: "\n"), reveal: created)
        }
    }
}
