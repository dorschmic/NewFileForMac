import Foundation

enum ConversionError: LocalizedError {
    case noRule(String, String)
    case toolNotFound(String)
    case toolFailed(String, Int32, String)
    case noOutput

    var errorDescription: String? {
        switch self {
        case let .noRule(from, to): return "Keine Regel für \(from) → \(to)"
        case let .toolNotFound(tool): return "\(tool) nicht gefunden (brew install \(tool)?)"
        case let .toolFailed(tool, code, message):
            return "\(tool) beendet mit Code \(code)" + (message.isEmpty ? "" : ": \(message)")
        case .noOutput: return "Werkzeug hat keine Ausgabedatei erzeugt"
        }
    }
}

/// Führt eine einzelne Konvertierung laut conversions.json aus.
///
/// Ablauf: Das Werkzeug schreibt in einen temporären Ordner auf demselben
/// Volume. Erst wenn es erfolgreich war, wird das Ergebnis unter einem
/// freien Namen neben das Original verschoben. So bleiben bei Fehlern keine
/// halben Dateien liegen, und es wird nie etwas überschrieben.
enum Converter {
    static let searchPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]

    static func convert(_ input: URL, to targetExtension: String, config: ConversionConfig) async throws -> URL {
        guard let spec = config.outputs(forExtension: input.pathExtension)
                .first(where: { $0.ext.lowercased() == targetExtension.lowercased() })
        else { throw ConversionError.noRule(input.pathExtension, targetExtension) }

        let tool = try resolveTool(spec.tool, config: config)
        let fm = FileManager.default
        let tempDir = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                 appropriateFor: input, create: true)
        defer { try? fm.removeItem(at: tempDir) }

        let name = input.deletingPathExtension().lastPathComponent
        let tempOutput = tempDir.appendingPathComponent(name).appendingPathExtension(spec.ext)
        let placeholders = [
            "{input}": input.path,
            "{output}": tempOutput.path,
            "{outputDir}": tempDir.path,
            "{name}": name,
        ]
        let args = spec.args.map { arg in
            placeholders.reduce(arg) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
        }

        try await run(tool, args, logFile: tempDir.appendingPathComponent("stderr.log"))

        guard fm.fileExists(atPath: tempOutput.path) else { throw ConversionError.noOutput }
        return try FileNaming.placeUniquely(in: input.deletingLastPathComponent(),
                                            baseName: name, ext: spec.ext) {
            try fm.moveItem(at: tempOutput, to: $0)
        }
    }

    /// Erst die Pfade aus conversions.json, dann die üblichen bin-Ordner.
    static func resolveTool(_ name: String, config: ConversionConfig) throws -> URL {
        let candidates = (config.tools[name] ?? []) + searchPaths.map { "\($0)/\(name)" }
        for path in candidates {
            let expanded = (path as NSString).expandingTildeInPath
            if FileManager.default.isExecutableFile(atPath: expanded) {
                return URL(fileURLWithPath: expanded)
            }
        }
        throw ConversionError.toolNotFound(name)
    }

    /// Startet ein Programm und wartet asynchron auf sein Ende.
    /// stderr geht in eine Datei (eine Pipe könnte bei viel Output volllaufen).
    private static func run(_ tool: URL, _ args: [String], logFile: URL) async throws {
        FileManager.default.createFile(atPath: logFile.path, contents: nil)
        let log = try FileHandle(forWritingTo: logFile)
        defer { try? log.close() }

        let process = Process()
        process.executableURL = tool
        process.arguments = args
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = log
        // GUI-Apps haben einen minimalen PATH; manche Werkzeuge rufen andere auf.
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = (searchPaths + ["/bin", "/usr/sbin", "/sbin"]).joined(separator: ":")
        process.environment = env

        // terminationHandler (Callback) → async/await mit einer Continuation.
        let status: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }

        if status != 0 {
            let output = (try? String(contentsOf: logFile, encoding: .utf8)) ?? ""
            let lastLines = output.split(separator: "\n").suffix(3).joined(separator: " ")
            throw ConversionError.toolFailed(tool.lastPathComponent, status, lastLines)
        }
    }
}
