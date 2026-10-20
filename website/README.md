# Website

Produktseite für NewFileForMac. Statisches HTML/CSS/JS ohne Build-Schritt.

```bash
python3 -m http.server 4321 --directory website
```

Danach http://localhost:4321 öffnen. Ein lokaler Server ist nötig, weil `scene.js` ein ES-Modul ist (mit `file://` lädt der Browser es nicht).

## Aufbau

| Datei | Inhalt |
|---|---|
| [index.html](index.html) | Alle Sektionen: Hero, Problem, Live-Demo, Konvertieren, Features, Dateitypen, Preis, Footer |
| [css/style.css](css/style.css) | Design-Tokens (Dark/Light), Glas-Komponenten, Finder-Nachbau, Layout |
| [js/main.js](js/main.js) | Preloader, Smooth Scroll, Scroll-Animationen, die gescrollte Finder-Demo |
| [js/scene.js](js/scene.js) | WebGL: animierter Farbverlauf und Glas-Dateien, die ihn brechen |

Bibliotheken kommen per CDN in festen Versionen: GSAP 3.12.5 + ScrollTrigger, Lenis 1.1.13, Three.js 0.170.

## Wie die Demo funktioniert

Das Finder-Fenster hat feste Designmaße (880 × 560 px) und wird per `transform: scale()` an die Spalte angepasst. Deshalb kann die Animation mit festen Koordinaten arbeiten. Eine GSAP-Timeline (Cursor, Menüs, neue Dateien, Mitteilung) hängt per ScrollTrigger am Scrollen: Scrollen spult die Timeline vor und zurück.

Menüs und Untermenüs werden wie in macOS positioniert: rechts neben dem Eintrag, wenn Platz ist, sonst links.

## Inhalte

Formate, Menüeinträge und Zahlen (112 Endungen, 58 Zielformate, 9 Werkzeuge) stammen aus `Resources/conversions.json` und `Resources/Templates`. Ändern sich die Regeln, müssen `INPUTS` und `CONVERSIONS` in `main.js` und die Zahlen in `index.html` von Hand nachgezogen werden.

Ausgedacht und auf der Seite so gekennzeichnet sind die Preiskarten „Pro“ und „Studio“, die DMG, Team-Vorlagen und Support.

## Stolperfalle

`backdrop-filter` ist teuer. Auf vielen gleichzeitig animierten Elementen (z. B. über 100 Marquee-Chips) gibt der Compositor auf, und die Seite wird schwarz. Die Chips haben deshalb nur eine Glas-Optik ohne echten Blur.

## Barrierefreiheit

Bei „Bewegung reduzieren“ entfallen Preloader, Smooth Scroll und Scroll-Animationen. Die Demo zeigt dann direkt den Endzustand.
