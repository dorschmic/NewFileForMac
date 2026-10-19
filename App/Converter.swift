import AppKit
import PDFKit

enum ConversionError: LocalizedError {
    case noRule(String, String)
    case toolNotFound(String, hint: String?)
    case toolFailed(String, Int32, String)
    case noOutput
    case chainTooLong
    case builtinFailed(String)

    var errorDescription: String? {
        switch self {
        case let .noRule(from, to): return "Keine Regel für \(from) → \(to)"
        case let .toolNotFound(tool, hint):
            return "\(tool) nicht gefunden" + (hint.map { " – installieren mit: \($0)" } ?? "")
        case let .toolFailed(tool, code, message):
            return "\(tool) beendet mit Code \(code)" + (message.isEmpty ? "" : ": \(message)")
        case .noOutput: return "Werkzeug hat keine Ausgabedatei erzeugt"
        case .chainTooLong: return "Zu viele Zwischenschritte (via)"
        case let .builtinFailed(message): return message
        }
    }
}

/// Führt eine einzelne Konvertierung laut den Regeln aus.
///
/// Ablauf: Alles entsteht in einem temporären Ordner auf demselben Volume.
/// Erst wenn alles geklappt hat, wird das Ergebnis unter einem freien Namen
/// neben das Original verschoben. So bleiben bei Fehlern keine halben
/// Dateien liegen, und es wird nie etwas überschrieben.
@MainActor
enum Converter {
    static let searchPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]

    static func convert(_ input: URL, to targetExtension: String, config: ConversionConfig) async throws -> URL {
        let fm = FileManager.default
        let tempDir = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                 appropriateFor: input, create: true)
        defer { try? fm.removeItem(at: tempDir) }

        let result = try await produce(input, targetExtension, in: tempDir, config: config, depth: 0)
        let name = input.deletingPathExtension().lastPathComponent
        return try FileNaming.placeUniquely(in: input.deletingLastPathComponent(),
                                            baseName: name, ext: result.pathExtension) {
            try fm.moveItem(at: result, to: $0)
        }
    }

    /// Erzeugt `input` im Zielformat innerhalb von `dir` und gibt den Pfad zurück.
    /// Probiert alle passenden Regeln der Reihe nach; fehlt ein Werkzeug,
    /// kommt die nächste dran.
    private static func produce(_ input: URL, _ target: String, in dir: URL,
                                config: ConversionConfig, depth: Int) async throws -> URL {
        guard depth < 4 else { throw ConversionError.chainTooLong }
        let candidates = config.candidates(from: input.pathExtension, to: target)
        guard !candidates.isEmpty else { throw ConversionError.noRule(input.pathExtension, target) }

        var lastError: Error = ConversionError.noRule(input.pathExtension, target)
        for spec in candidates {
            do {
                return try await apply(spec, to: input, in: dir, config: config, depth: depth)
            } catch let error as ConversionError {
                guard case .toolNotFound = error else { throw error }
                lastError = error   // Werkzeug fehlt → nächste Regel probieren
            }
        }
        throw lastError
    }

    private static func apply(_ spec: ConversionOutput, to input: URL, in dir: URL,
                              config: ConversionConfig, depth: Int) async throws -> URL {
        // Jeder Schritt bekommt einen eigenen Unterordner (Kette: md → html → pdf).
        let stepDir = dir.appendingPathComponent("step\(depth)-\(spec.ext)", isDirectory: true)
        try FileManager.default.createDirectory(at: stepDir, withIntermediateDirectories: true)

        if let via = spec.via {
            let intermediate = try await produce(input, via, in: stepDir, config: config, depth: depth + 1)
            return try await produce(intermediate, spec.ext, in: stepDir, config: config, depth: depth + 1)
        }

        let name = input.deletingPathExtension().lastPathComponent
        let output = stepDir.appendingPathComponent(name).appendingPathExtension(spec.ext)
        guard let toolName = spec.tool else { throw ConversionError.noRule(input.pathExtension, spec.ext) }

        if let builtin = BuiltinTool(rawValue: toolName) {
            try runBuiltin(builtin, input: input, output: output)
        } else {
            let tool = try resolveTool(toolName, config: config)
            let placeholders = [
                "{input}": input.path,
                "{output}": output.path,
                "{outputDir}": stepDir.path,
                "{name}": name,
            ]
            let args = (spec.args ?? []).map { arg in
                placeholders.reduce(arg) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
            }
            try await run(tool, args, logFile: dir.appendingPathComponent("stderr-\(depth).log"))
        }

        guard FileManager.default.fileExists(atPath: output.path) else { throw ConversionError.noOutput }
        return output
    }

    // MARK: - Externe Werkzeuge

    /// Erst die Pfade aus den Regeln, dann die üblichen bin-Ordner.
    static func resolveTool(_ name: String, config: ConversionConfig) throws -> URL {
        let candidates = (config.tools?[name] ?? []) + searchPaths.map { "\($0)/\(name)" }
        for path in candidates {
            let expanded = (path as NSString).expandingTildeInPath
            if FileManager.default.isExecutableFile(atPath: expanded) {
                return URL(fileURLWithPath: expanded)
            }
        }
        throw ConversionError.toolNotFound(name, hint: config.installHints?[name] ?? "brew install \(name)")
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

    // MARK: - Eingebaute Werkzeuge

    private static func runBuiltin(_ tool: BuiltinTool, input: URL, output: URL) throws {
        switch tool {
        case .copy:
            try FileManager.default.copyItem(at: input, to: output)
            // Skripte gleich ausführbar machen
            let perms = ["sh", "zsh", "bash", "command"].contains(output.pathExtension.lowercased()) ? 0o755 : 0o644
            try FileManager.default.setAttributes([.posixPermissions: perms], ofItemAtPath: output.path)
        case .textpdf:
            try renderPDF(input, to: output)
        case .pdftext:
            guard let pdf = PDFDocument(url: input) else {
                throw ConversionError.builtinFailed("PDF nicht lesbar")
            }
            try (pdf.string ?? "").write(to: output, atomically: true, encoding: .utf8)
        }
    }

    /// Formate, die NSAttributedString selbst als formatierten Text versteht.
    private static let richTextExtensions: Set<String> = ["rtf", "rtfd", "docx", "doc", "odt", "html", "htm", "webarchive"]

    /// Der HTML-Import (WebKit) folgt dem Dark Mode des Systems: CSS wie
    /// `color: light-dark(#1a1a1a, #fdfdfd)` liefert dann fast weiße Schrift.
    /// Für ein weißes Blatt machen wir zu helle Schrift schwarz und entfernen
    /// zu dunkle Hintergründe.
    private static func printableColors(_ source: NSAttributedString) -> NSAttributedString {
        func brightness(_ color: NSColor) -> CGFloat {
            guard let c = color.usingColorSpace(.sRGB) else { return 0 }
            return 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
        }
        let text = NSMutableAttributedString(attributedString: source)
        let all = NSRange(location: 0, length: text.length)
        text.enumerateAttribute(.foregroundColor, in: all) { value, range, _ in
            if let color = value as? NSColor, brightness(color) > 0.75 {
                text.addAttribute(.foregroundColor, value: NSColor.black, range: range)
            }
        }
        text.enumerateAttribute(.backgroundColor, in: all) { value, range, _ in
            if let color = value as? NSColor, brightness(color) < 0.5 {
                text.removeAttribute(.backgroundColor, range: range)
            }
        }
        return text
    }

    /// "Druckt" ein Dokument über das macOS-Textsystem in eine PDF-Datei (A4).
    private static func renderPDF(_ input: URL, to output: URL) throws {
        var text = NSAttributedString()
        if richTextExtensions.contains(input.pathExtension.lowercased()) {
            let imported = try NSAttributedString(url: input, options: [:], documentAttributes: nil)
            text = printableColors(imported)
        } else {
            // Alles andere (txt, sh, py, json, …) als reinen Text in Monospace.
            let plain = try String(contentsOf: input, encoding: .utf8)
            text = NSAttributedString(string: plain, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: NSColor.black,
            ])
        }

        let printInfo = NSPrintInfo(dictionary: [.jobSavingURL: output])
        printInfo.jobDisposition = .save
        printInfo.paperSize = NSSize(width: 595, height: 842)   // A4 in Punkt
        for margin in [\NSPrintInfo.topMargin, \.bottomMargin, \.leftMargin, \.rightMargin] {
            printInfo[keyPath: margin] = 56                       // ca. 2 cm
        }
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isVerticallyCentered = false                    // Standard wäre: mittig auf der Seite
        printInfo.isHorizontallyCentered = false

        let width = printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 100))
        textView.appearance = NSAppearance(named: .aqua)          // auch im Dark Mode schwarz auf weiß
        textView.backgroundColor = .white
        textView.textStorage?.setAttributedString(text)
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        textView.sizeToFit()

        let operation = NSPrintOperation(view: textView, printInfo: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        guard operation.run() else { throw ConversionError.builtinFailed("PDF-Erzeugung fehlgeschlagen") }
    }
}
