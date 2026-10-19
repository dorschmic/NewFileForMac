import SwiftUI
import FinderSync
import ServiceManagement

@main
struct NewFileForMacApp: App {
    // SwiftUI-App mit klassischem AppDelegate – den brauchen wir für
    // `application(_:open:)`, über das die URLs der Extension ankommen.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("NewFileForMac", systemImage: "doc.badge.plus") {
            MenuContent()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Defaults.installIfNeeded()
        Notifier.shared.setup()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            JobRunner.shared.handle(url)
        }
    }
}

/// Inhalt des Menüleisten-Menüs.
struct MenuContent: View {
    @ObservedObject private var runner = JobRunner.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        if runner.activeJobs > 0 {
            Text("Läuft: \(runner.activeJobs) Auftrag/Aufträge …")
            Divider()
        }
        Button("Vorlagen-Ordner öffnen") {
            NSWorkspace.shared.open(AppPaths.templatesDir)
        }
        Button("Konvertierungsregeln im Finder zeigen") {
            NSWorkspace.shared.activateFileViewerSelecting([AppPaths.rulesFile])
        }
        Divider()
        Button("Fehlende Standardvorlagen wiederherstellen") {
            Defaults.restoreMissingTemplates()
        }
        Button("Regeln auf Standard zurücksetzen") {
            Defaults.resetRules()
        }
        Divider()
        Button("Finder-Erweiterung verwalten …") {
            FIFinderSyncController.showExtensionManagementInterface()
        }
        Toggle("Bei Anmeldung starten", isOn: $launchAtLogin)
            .onChange(of: launchAtLogin) { _, enabled in
                do {
                    if enabled { try SMAppService.mainApp.register() }
                    else { try SMAppService.mainApp.unregister() }
                } catch {
                    Notifier.shared.post(title: "Anmeldeobjekt", body: error.localizedDescription)
                }
            }
        Divider()
        Button("Beenden") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
