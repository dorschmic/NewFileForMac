# NewFileForMac

Windows-ähnliche Finder-Funktionen per Rechtsklick:

- **Neue Datei** → Text, Markdown, Python, HTML, JSON, CSV, Shell, RTF, Word, Excel, PowerPoint …
- **Konvertieren in** → je nach Dateityp, z. B.
  - Text/Code (`.txt`, `.sh`, `.py`, `.json` …) → TXT, MD, PDF, Word, ODT, RTF, HTML oder einfach andere Endung
  - Markdown → HTML, Word, ODT, RTF, EPUB, PDF · CSV → Tabelle als Markdown/HTML/Word/PDF
  - Word/ODT/RTF/HTML → PDF, TXT, Markdown, DOC, EPUB … · PDF → TXT, PNG/JPEG
  - Bilder (inkl. HEIC, RAW) → JPEG, PNG, HEIC, WebP, AVIF, PDF, TIFF, GIF, BMP, ICO, PSD
  - Video → MP4, MOV, MKV, WebM, GIF, Audio-Spur, Standbild · Audio → MP3, M4A, WAV, AIFF, FLAC, Opus, OGG

## Installieren

```bash
brew install xcodegen ffmpeg pandoc webp
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
- **Konvertierungen:**
  - `conversions.default.json` – mitgelieferte Regeln, werden bei jedem App-Start erneuert (nicht bearbeiten)
  - `conversions.json` – **eigene Regeln**, haben Vorrang (Menüleiste → *Eigene Konvertierungsregeln bearbeiten*)

Aufbau einer Regel:

```json
{ "inputs": ["txt", "md"],
  "outputs": [
    { "ext": "pdf", "label": "PDF", "group": "Dokument", "tool": "textpdf" },
    { "ext": "mp3", "label": "MP3", "tool": "ffmpeg", "args": ["-i", "{input}", "{output}"] },
    { "ext": "pdf", "label": "PDF", "via": "html" }
  ] }
```

| Feld | Bedeutung |
|---|---|
| `tool` | Programmname (gesucht in `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin` oder unter `"tools"`) oder eingebautes Werkzeug |
| `args` | Argumente mit Platzhaltern `{input}`, `{output}`, `{outputDir}`, `{name}` |
| `group` | Eintrag landet im Untermenü dieses Namens |
| `via` | erst in dieses Format konvertieren, dann weiter (z. B. Markdown → HTML → PDF) |

Eingebaute Werkzeuge: `copy` (Inhalt bleibt, nur die Endung ändert sich; Skripte werden ausführbar), `textpdf` (Text/Code/RTF/DOCX/HTML als A4-PDF über das macOS-Textsystem), `pdftext` (Text aus PDF).

Gibt es dasselbe Ziel in mehreren Regeln, wird der Reihe nach die erste genommen, deren Werkzeug installiert ist. Beispiel: DOCX → PDF nimmt LibreOffice, falls installiert, sonst `textpdf`. Bei Mehrfachauswahl zeigt das Menü nur Formate, die für *alle* ausgewählten Dateien gehen. `jpg`/`jpeg`, `tif`/`tiff`, `htm`/`html`, `yml`/`yaml` usw. gelten als dasselbe Format.

## Stand

Getestet über das URL-Schema: eine Stichprobe von rund 50 Konvertierungen, die jedes Werkzeug (copy, textpdf, textutil, pandoc, sips, cwebp, ffmpeg) abdeckt, mit geprüften Ergebnissen. Nicht jedes Quell-/Zielpaar einzeln getestet, die LibreOffice-Regeln gar nicht.

LibreOffice (`brew install --cask libreoffice`, ca. 1 GB) ist optional. Nötig ist es nur für XLSX/PPTX → PDF, Tabellen ↔ CSV/ODS und PDF → DOCX. Ohne LibreOffice erscheinen diese Einträge trotzdem und melden beim Klick, was zu installieren ist.

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
