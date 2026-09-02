# UI-Design-Richtlinie: VolleyAce

Diese Richtlinie beschreibt den aktuell überprüften visuellen Stand von VolleyAce. Sie dient als Referenz für weitere UI-Arbeiten.

## Implementierungsabgleich (2026-09)

| Bereich | Status | Tatsächlicher Stand |
|---|---|---|
| Material 3 | umgesetzt | `ThemeData(useMaterial3: true)` |
| Dark/Light-Theme | umgesetzt | Dark ist Standard; Light kann in den Einstellungen aktiviert werden |
| Farben | umgesetzt | Akzent- und Highlightfarbe sind konfigurierbar; Teamfarben enthalten zusätzlich Schwarz und Weiß |
| Typografie | umgesetzt | Ubuntu als Standard; OpenDyslexic, NotoSans, CourierPrime und Ubuntu Mono verfügbar |
| Schriftgröße | umgesetzt | Global über `MediaQuery.textScaler` skalierbar |
| Module | umgesetzt | Punktetafel, Taktiktafel, Teams, Training, Statistik und Arcade vorhanden |
| Responsive Design | teilweise | Zentrale Ansichten reagieren auf verfügbare Fläche; vollständiger Unterseiten-Abgleich offen |
| Accessibility | teilweise | Mehrere `Semantics`- und Tooltip-Beschriftungen vorhanden; vollständige Prüfung offen |

---

## Leitbild

Eine fokussierte Sport- und Assistenz-App für Trainer, Spieler und Schiedsrichter. Die Bedienung muss während eines Spiels schnell erfassbar sein; Spielstand, Daten und nächste Aktion stehen im Vordergrund.

---

## Theme

| Eigenschaft | Wert |
|---|---|
| Helligkeit | Dark standardmäßig, Light optional (`Brightness.dark` / `Brightness.light`) |
| Seed-Farbe | konfigurierbare Akzentfarbe, standardmäßig Rot (`#e57373`) |
| Erzeugung | `ColorScheme.fromSeed` mit dynamischer Helligkeit, Orange als `secondary` und Mint als `tertiary` |
| Flutter-Widget | `ThemeData` mit `colorScheme`, kein `primarySwatch` |

Das Theme basiert auf `ColorScheme.fromSeed` und ergänzt semantische sowie konfigurierbare Farben. Die App unterstützt Dark und Light.

---

## Farben

### Farbpalette

aed581 - grün
fff176 - gelb
64b5f6 - blau
e57373 - rot
8fdcbe - mint
9575cd - lila
ffb74d - orange

### Strukturfarben (aus ColorScheme)

Alle Hintergründe, Oberflächen und Standard-Text kommen aus dem generierten `ColorScheme` — nie hartcodierte Hex-Werte für strukturelle UI.

| Rolle | Flutter-Token | Verwendung |
|---|---|---|
| Hintergrund | `cs.surface` | Seiten-Hintergrund |
| Karten/Container | `cs.primaryContainer`, `cs.secondaryContainer` | Task-Karten, Panels |
| Primärtext | `cs.onSurface` | Standard-Textfarbe |
| Sekundärtext | `cs.onSurfaceVariant` | Datum, Metadaten, Hinweise |

### Semantische Farben (hartcodiert)

Diese Farben haben eine feste Bedeutung und werden konsistent über die ganze App verwendet:

| Bedeutung | Farbe | Flutter-Wert |
|---|---|---|
| Punkteteam links | Blau | `Color(0xFF64B5F6)` |
| Punkteteam rechts | Rot | `Color(0xFFE57373)` |
| Positive Zustände | Grün | `Color(0xFFAED581)` |
| Hervorhebung | Gelb / Orange | `Color(0xFFFFF176)` / `Color(0xFFFFB74D)` |
| Fehler / destruktive Aktion | Rot | `Color(0xFFE57373)` |
| Transparent / kein Hintergrund | — | `Colors.transparent` |

**Regel:** Statusfarben niemals als Hintergrundfarbe — immer als Textfarbe oder Icon-Farbe einsetzen.

---

## Typografie

### Schriftarten

Die App bietet fünf Fonts zur Auswahl — Ubuntu ist Standard; OpenDyslexic bleibt als zugängliche Alternative verfügbar:

| Font | Einsatz |
|---|---|
| OpenDyslexic | Alternative — verbesserte Lesbarkeit für Dyslexiker |
| NotoSans | Saubere Alternative, System-nah |
| CourierPrime | Monospace-Option |
| Ubuntu | Standard |
| Ubuntu Mono | Monospace-Option |

Alle Fonts werden über `pubspec.yaml` als Asset eingebunden (`assets/fonts/`). Der gewählte Font wird über die Einstellungen global auf das `ThemeData` angewendet.

```dart
// Font auf das gesamte Theme anwenden
data: baseTheme.copyWith(
  textTheme: baseTheme.textTheme.apply(fontFamily: _fontFamily),
  primaryTextTheme: baseTheme.primaryTextTheme.apply(fontFamily: _fontFamily),
)
```

### Größenskala

| Verwendung | Größe | Gewicht |
|---|---|---|
| Screen-Titel / Hero | 24 | `w700` |
| Abschnitts-Überschrift | 18–19 | `bold` / `w700` |
| Standard-Body / Task-Titel | 15–16 | normal / `w600` |
| Sekundär / Label | 12–14 | normal |
| Kleintext / Metadaten | 10–11 | normal |

Die Basis-Schriftgröße (`_baseFontSize`) liegt bei **15.0** und wird für Task-Text verwendet.

---

## Abstände (Spacing)

Kein eigenes Spacing-System — es gelten folgende bevorzugte Werte in der Praxis:

| Token | Wert | Typische Verwendung |
|---|---|---|
| xs | 4 px | Minimaler Innenabstand, Icon-Gaps |
| sm | 6–8 px | Standard-Padding horizontal |
| md | 12 px | Standard-Padding vertikal, Listenabstände |
| lg | 16 px | Abschnitte, größere Container |

Häufigste Padding-Werte: `horizontal: 12`, `vertical: 6–8`.

---

## Eckenradien

| Element | Radius |
|---|---|
| Buttons, Chips, kleine Karten | `BorderRadius.circular(12)` |
| Größere Container / Dialoge | `BorderRadius.circular(14)` |

---

## Icons

Ausschließlich **Material Icons** (`Icons.*`) aus dem Flutter-Standard-Set. Kein eigenes Icon-Set, keine externen Icon-Pakete.

Bevorzugt werden `_rounded`-Varianten wenn vorhanden (z. B. `Icons.download_rounded`, `Icons.upload_rounded`).

Wichtige Icons und ihre Bedeutung in der App:

| Icon | Bedeutung |
|---|---|
| `Icons.radio_button_unchecked` | Aufgabe offen |
| `Icons.task_alt` | Aufgabe erledigt |
| `Icons.star` / `Icons.star_border` | Wichtig (Flag) |
| `Icons.play_arrow` / `Icons.stop` | In Bearbeitung starten/stoppen |
| `Icons.push_pin` / `Icons.push_pin_outlined` | Angeheftet |
| `Icons.drag_handle` | Drag & Drop Handle |
| `Icons.calendar_today` | Datum |
| `Icons.timelapse` | Zeiterfassung |
| `Icons.delete` / `Icons.delete_forever` | Löschen / endgültig löschen |
| `Icons.sync` | Cloud-Sync |
| `Icons.more_vert` | Kontextmenü |

---

## Komponenten-Konventionen

### Task-Zeile

- Hintergrund: kein farbiger Hintergrund — nur der Kartencontainer (`Card` oder `ColorScheme`-Container)
- Textfarbe zeigt den Status (siehe semantische Farben)
- Linke Seite: Status-Icon (offen/erledigt)
- Rechte Seite: Aktions-Icons (`IconButton` mit `tapTargetSize: MaterialTapTargetSize.shrinkWrap`)
- Gedimmter Text bei erledigten Aufgaben (60 % Opacity)

### Buttons

- Primäraktion: `ElevatedButton`
- Sekundäraktion / Abbrechen: `TextButton`
- Ikonbasierte Aktionen in Listen: `IconButton`
- Destruktive Aktionen (Löschen): `foregroundColor: Color(0xFFe57373)`, `BorderSide(color: Color(0xFFe57373))`

### Dialoge

- Standard Flutter `AlertDialog` / `showDialog`
- Keine Custom-Dialog-Rahmen

### Listen

- `ListView` ohne Trennlinien (kein `Divider`)
- Drag & Drop via `ReorderableListView` mit `Icons.drag_handle`

---

## Layout

- **Modulstruktur:** Startseite | Punktetafel | Taktiktafel | Teams | Training | Statistik
- AppBars sind Bestandteil der aktuellen Navigation und enthalten kontextbezogene Aktionen.
- FloatingActionButtons können für kontextbezogene Primäraktionen verwendet werden.
- Statuszeile (Sync-Status, Uhrzeit) oben im Panel, klein (fontSize 11)

---

## Barrierefreiheit

- **OpenDyslexic als verfügbare Alternative** — Ubuntu ist aktuell die Standardschrift
- Schriftgröße benutzerkonfigurierbar (Settings)
- Kontraste folgen dem generierten Dark ColorScheme (Material Design-konform)
- Alle `IconButton`s haben `tooltip`
- Keine reinen Farbsignale — Icons, Zahlen oder Text begleiten Farbänderungen

## Noch zu prüfen

- Vollständiges Responsive-Design aller Unterseiten.
- Vollständige Tastaturnavigation und Screenreader-Beschriftungen.
- Kontrastprüfung beider Themes und der Teamfarben.
- Einheitliche Übersetzung aller Texte, falls weitere Sprachen angeboten werden.
