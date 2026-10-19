import Cocoa
import FinderSync
import UniformTypeIdentifiers
import os

/// Finder Sync Extension: baut die Kontextmenüs und schickt Aufträge an die App.
///
/// Wichtig: Finder *kopiert* die Menüeinträge, bevor er sie anzeigt. Dabei
/// gehen `representedObject` & Co. verloren – erhalten bleiben nur Titel,
/// Bild, `action` und `tag`. Deshalb kodieren wir die Auswahl im `tag`
/// und berechnen in der Action-Methode die Liste noch einmal.
class FinderSync: FIFinderSync {

    private enum Tag {
        static let newFileHere = 1000    // in den aktuell angezeigten Ordner
        static let newFileInside = 2000  // in den ausgewählten Ordner
        static let convert = 3000
    }

    private let log = Logger(subsystem: "de.micheldorsch.NewFileForMac", category: "FinderSync")

    override init() {
        super.init()
        // "/" = Menüs überall anbieten (inkl. /Volumes/…).
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
        log.notice("FinderSync gestartet – \(TemplateStore.load().count) Vorlagen gefunden")
    }

    // MARK: - Toolbar-Button (optional über "Symbolleiste anpassen…")

    override var toolbarItemName: String { "Neue Datei" }
    override var toolbarItemToolTip: String { "Neue Datei aus Vorlage anlegen" }
    override var toolbarItemImage: NSImage {
        NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil) ?? NSImage()
    }

    // MARK: - Menüaufbau

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "")
        switch menuKind {
        case .contextualMenuForContainer, .contextualMenuForSidebar, .toolbarItemMenu:
            addNewFileMenu(to: menu, baseTag: Tag.newFileHere)
        case .contextualMenuForItems:
            if selectedFolder() != nil {
                addNewFileMenu(to: menu, baseTag: Tag.newFileInside)
            }
            addConvertMenu(to: menu)
        @unknown default:
            break
        }
        return menu
    }

    private func addNewFileMenu(to menu: NSMenu, baseTag: Int) {
        let templates = TemplateStore.load()
        guard !templates.isEmpty else { return }

        let submenu = NSMenu(title: "Neue Datei")
        for (index, template) in templates.enumerated() {
            let item = NSMenuItem(title: template.title,
                                  action: #selector(newFileClicked(_:)),
                                  keyEquivalent: "")
            item.tag = baseTag + index
            item.image = icon(forExtension: template.fileExtension)
            submenu.addItem(item)
        }
        let parent = NSMenuItem(title: "Neue Datei", action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
        parent.submenu = submenu
        menu.addItem(parent)
    }

    private func addConvertMenu(to menu: NSMenu) {
        let files = selectedFiles()
        guard !files.isEmpty, let config = loadRules() else { return }
        let outputs = config.commonOutputs(for: files)
        guard !outputs.isEmpty else { return }

        let submenu = NSMenu(title: "Konvertieren")
        for (index, output) in outputs.enumerated() {
            let item = NSMenuItem(title: output.label,
                                  action: #selector(convertClicked(_:)),
                                  keyEquivalent: "")
            item.tag = Tag.convert + index
            item.image = icon(forExtension: output.ext)
            submenu.addItem(item)
        }
        let title = files.count == 1 ? "Konvertieren in" : "\(files.count) Dateien konvertieren in"
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        parent.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
        parent.submenu = submenu
        menu.addItem(parent)
    }

    // MARK: - Actions

    @objc private func newFileClicked(_ sender: NSMenuItem) {
        let templates = TemplateStore.load()
        let directory: URL?
        let index: Int
        if sender.tag >= Tag.newFileInside {
            directory = selectedFolder()
            index = sender.tag - Tag.newFileInside
        } else {
            directory = FIFinderSyncController.default().targetedURL()
            index = sender.tag - Tag.newFileHere
        }
        guard let directory, templates.indices.contains(index) else { return }
        send(.newFile(template: templates[index].fileName, directory: directory.path))
    }

    @objc private func convertClicked(_ sender: NSMenuItem) {
        let files = selectedFiles()
        guard let config = loadRules() else { return }
        let outputs = config.commonOutputs(for: files)
        let index = sender.tag - Tag.convert
        guard outputs.indices.contains(index) else { return }
        send(.convert(files: files.map(\.path), targetExtension: outputs[index].ext))
    }

    // MARK: - Hilfsfunktionen

    /// Übergibt den Auftrag per URL an die Haupt-App (startet sie bei Bedarf).
    private func send(_ job: Job) {
        do {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            NSWorkspace.shared.open(try job.url(), configuration: config) { [log] _, error in
                if let error { log.error("Auftrag nicht zugestellt: \(error.localizedDescription)") }
            }
        } catch {
            log.error("Auftrag nicht kodierbar: \(error.localizedDescription)")
        }
    }

    private func loadRules() -> ConversionConfig? {
        do { return try ConversionConfig.load() } catch {
            log.error("conversions.json nicht lesbar: \(error.localizedDescription)")
            return nil
        }
    }

    private func selectedItems() -> [URL] {
        FIFinderSyncController.default().selectedItemURLs() ?? []
    }

    /// Ausgewählte Dateien (Ordner werden ignoriert).
    private func selectedFiles() -> [URL] {
        selectedItems().filter { !isDirectory($0) }
    }

    /// Genau ein ausgewählter Ordner (für "Neue Datei" darin), sonst nil.
    private func selectedFolder() -> URL? {
        let items = selectedItems()
        guard items.count == 1, let item = items.first, isDirectory(item) else { return nil }
        return item
    }

    private func isDirectory(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        return values?.isDirectory == true && values?.isPackage != true
    }

    private func icon(forExtension ext: String) -> NSImage {
        let image = NSWorkspace.shared.icon(for: UTType(filenameExtension: ext) ?? .data)
        image.size = NSSize(width: 16, height: 16)
        return image
    }
}
