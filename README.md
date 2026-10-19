# NewFileForMac

Windows-ähnliche Finder-Funktionen per Rechtsklick:

- **Neue Datei** → Text, Markdown, Python, HTML, JSON, CSV, Shell, RTF, Word, Excel, PowerPoint …
- **Konvertieren in** → je nach Dateityp (Video → MP3/M4A/WAV/GIF/MP4, Bilder → JPEG/PNG/HEIC/TIFF/PDF, Text → DOCX/RTF/HTML, …)

## Installieren

```bash
brew install xcodegen ffmpeg
```

```bash
Scripts/install.sh
```

Das Skript erzeugt das Xcode-Projekt, baut die App im Release-Modus, kopiert sie nach `~/Applications`, aktiviert die Finder-Erweiterung und startet den Finder neu. Falls das Menü nicht erscheint: Menüleisten-Symbol → *Finder-Erweiterung verwalten …* und dort einschalten.

Zum Entwickeln: `xcodegen generate` ausführen, dann `NewFileForMac.xcodeproj` öffnen. **Das `.xcodeproj` nie von Hand ändern** – alle Einstellungen stehen in [project.yml](project.yml).

## Architektur

```
Finder ──Rechtsklick──▶ FinderExtension (Sandbox)
                          │ liest Templates/ + conversions.json (nur lesen)
                          │ baut das Menü
                          ▼ Klick
              newfileformac://job?data=<JSON als Base64URL>
                          │ (NSWorkspace.open – startet die App bei Bedarf)
                          ▼
                NewFileForMac.app (Menüleiste, ohne Sandbox)
                  ├─ Neue Datei: Vorlage kopieren, freien Namen suchen
                  └─ Konvertieren: Werkzeug in Temp-Ordner laufen lassen,
                     Ergebnis neben das Original verschieben, Mitteilung
```

| Datei | Aufgabe |
|---|---|
| [Shared/Job.swift](Shared/Job.swift) | Auftrag (Codable-Enum) + Kodierung als URL |
| [Shared/AppPaths.swift](Shared/AppPaths.swift) | Pfade; echtes Home-Verzeichnis auch in der Sandbox |
| [Shared/TemplateStore.swift](Shared/TemplateStore.swift) | Vorlagen-Ordner einlesen |
| [Shared/ConversionRules.swift](Shared/ConversionRules.swift) | Modell für `conversions.json`, Ziel-Formate pro Endung |
| [FinderExtension/FinderSync.swift](FinderExtension/FinderSync.swift) | Menüs bauen, Aufträge verschicken |
| [App/JobRunner.swift](App/JobRunner.swift) | Aufträge annehmen und ausführen |
| [App/Converter.swift](App/Converter.swift) | Werkzeug starten (`Process` + async/await) |
| [App/FileNaming.swift](App/FileNaming.swift) | „Name 2.ext“ ohne Überschreiben, auch bei Wettläufen |
| [Scripts/make_templates.sh](Scripts/make_templates.sh) | Baut die Vorlagen, inkl. gültiger leerer Office-Pakete |

## Anpassen

Alles liegt in `~/Library/Application Support/NewFileForMac/` (Menüleiste → *Vorlagen-Ordner öffnen*):

- **Vorlagen:** einfach Dateien in `Templates/` legen. `15 Notiz.md` erscheint als „Notiz“; die Zahl steuert nur die Reihenfolge. Änderungen wirken sofort beim nächsten Rechtsklick.
- **Konvertierungen:** `conversions.json` bearbeiten. Eine Regel ordnet Eingabe-Endungen Ausgaben zu, jede Ausgabe nennt Werkzeug und Argumente. Platzhalter: `{input}`, `{output}`, `{outputDir}`, `{name}`. Werkzeuge werden in `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin` gesucht oder über `"tools"` mit Pfad angegeben.

Bei Mehrfachauswahl zeigt das Menü nur Formate, die für *alle* ausgewählten Dateien gehen.

## Stand

| Funktion | Werkzeug | Status |
|---|---|---|
| Neue Datei (alle Vorlagen) | – | getestet |
| Video → MP3/M4A/WAV/GIF/MP4, Audio ↔ Audio | ffmpeg | MP3 + GIF getestet |
| Bilder (HEIC/JPG/PNG/…) | sips | HEIC → JPG getestet |
| DOCX/RTF/TXT/HTML untereinander | textutil | RTF → DOCX getestet |
| Markdown → DOCX/HTML | pandoc (`brew install pandoc`) | Regel vorhanden, ungetestet |
| Office → PDF, PDF → DOCX | LibreOffice (`brew install --cask libreoffice`) | Regel vorhanden, ungetestet |

## Debugging

```bash
/usr/bin/log stream --predicate 'subsystem == "de.micheldorsch.NewFileForMac"'
```

```bash
pluginkit -m -v -i de.micheldorsch.NewFileForMac.FinderExtension
```

(In zsh ist `log` ein eingebauter Befehl – deshalb `/usr/bin/log`.)

Läuft die App zusätzlich aus Xcode (DerivedData), gibt es zwei Kopien mit derselben Bundle-ID; macOS nimmt dann eventuell die falsche Extension. Im Zweifel `Scripts/install.sh` erneut ausführen.

## Ideen für später

- Neue Datei direkt auswählen und in den Umbenennen-Modus schalten (wie unter Windows)
- Fortschrittsanzeige für lange Videokonvertierungen (ffmpeg `-progress`)
- Eigenes ImageIO-Werkzeug in Swift statt `sips` (z. B. Größe ändern)
- Markdown → PDF (pandoc + LaTeX-Engine, oder über HTML)
