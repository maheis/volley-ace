# UI-Settings-Grundlage: VolleyAce

Diese Dokumentation beschreibt den aktuellen Aufbau der Einstellungen von VolleyAce und leitet daraus ein wiederverwendbares Muster fuer Settings-Seiten in neuen Anwendungen ab.

## 1. Aktueller Umfang

VolleyAce konzentriert die globalen Einstellungen auf wenige, direkt wirksame Optionen:

- **Darstellung:** Theme-Modus, Akzentfarbe und Highlight-Farbe.
- **Typografie:** Schriftfamilie und globale Textskalierung.
- **Bedienbarkeit:** bessere Lesbarkeit durch Schriftwahl und Skalierung.

Fachliche Einstellungen fuer Punktetafel, Taktik, Teams, Training, Statistik und Arcade bleiben in den jeweiligen Modulen. Dadurch bleibt die globale Settings-Seite klein und die Optionen bleiben dort, wo ihr Kontext bekannt ist.

## 2. Settings-Modell

Das zentrale Modell liegt in `lib/src/settings/app_settings.dart` und ist immutable:

| Feld | Typ | Default | Bedeutung |
|---|---|---|---|
| `fontFamily` | `String` | `Ubuntu` | Global verwendete Schriftfamilie |
| `textScaleFactor` | `double` | `1.0` | Globale Textskalierung, begrenzt auf 0.5 bis 1.6 |
| `useLightTheme` | `bool` | `false` | Light-Theme aktivieren; Dark ist Standard |
| `accentColorValue` | `int` | `0xFFE57373` | Seed-/Akzentfarbe |
| `highlightColorValue` | `int` | `0xFFFFB74D` | Hervorhebungsfarbe fuer Controls |

Verfuegbare Fonts:

- OpenDyslexic
- NotoSans
- CourierPrime
- Ubuntu
- Ubuntu Mono

`copyWith` erlaubt kontrollierte Teilupdates, ohne das Modell zu mutieren.

## 3. Seitenaufbau

Die `SettingsPage` ist eine zustandsbehaftete Seite mit `Scaffold`, `AppBar` und scrollbarer `ListView`.

Reihenfolge der Controls:

1. Schriftart
2. Theme-Modus
3. Akzentfarbe
4. Highlight-Farbe
5. Schriftgroesse
6. Vorschau

| Einstellung | Control | Verhalten |
|---|---|---|
| Schriftart | `DropdownButton<String>` | Auswahl aus erlaubter Liste |
| Theme | `SwitchListTile` | Hell/Dunkel umschalten |
| Akzentfarbe | Dropdown mit Farbswatch | Auswahl aus `AppPalette.accentColors` |
| Highlight-Farbe | Dropdown mit Farbswatch | Auswahl aus `AppPalette.accentColors` |
| Schriftgroesse | `Slider` | 50 % bis 160 %, 22 Schritte |
| Ergebnis | Vorschau-Card | zeigt die Wirkung der Auswahl |

Die Seite arbeitet mit lokalen Entwurfswerten. Erst beim Druecken von **Speichern** wird ein neues `AppSettings`-Objekt an die Anwendung zurueckgegeben. Bei ungespeicherten Aenderungen muss das Verlassen bestaetigt werden.

## 4. Architektur und Aenderungsfluss

```text
SettingsPage
    |
SettingsController extends ChangeNotifier
    |
AppSettings (immutable model)
    |
SettingsRepository
    |
Sembast settings store
```

```text
App
    -> SettingsController.load()
    -> SettingsRepository.load()
    -> AppSettings
    -> SettingsPage(initial: settings)
    -> lokale Entwurfswerte
    -> Speichern
    -> SettingsController.update(newSettings)
    -> notifyListeners()
    -> SettingsRepository.save(newSettings)
```

Der Controller ist die Laufzeit-Schnittstelle:

- `load()` laedt die Settings aus dem Repository.
- `settings` stellt den aktuellen Wert bereit.
- `isLoaded` zeigt den abgeschlossenen Ladevorgang an.
- `update(...)` veroeffentlicht und speichert neue Settings.

Die Settings-Seite greift nicht direkt auf Sembast oder Plattform-APIs zu.

## 5. Laufzeitwirkung

Die globalen Einstellungen werden in `app.dart` angewendet:

- `theme` und `darkTheme` werden mit `ColorScheme.fromSeed` erzeugt.
- `themeMode` folgt `useLightTheme`.
- `fontFamily` wird auf `textTheme` und `primaryTextTheme` angewendet.
- `MediaQuery.textScaler` nutzt `textScaleFactor`.
- Akzent- und Highlight-Farben werden in Theme-Komponenten verwendet.

Damit wirken Aenderungen auf Navigation, Buttons, Eingabefelder, FABs, Snackbar, Icons und die fachlichen Module.

## 6. Speicherung und Migration

`SettingsRepository` speichert einen einzelnen lokalen Sembast-Record:

- Store: `settings`
- Record-Key: `app`
- Persistierte Schluessel: `fontFamily`, `uiTextScaleFactor`, `useLightTheme`, `accentColorValue`, `highlightColorValue`
- Werte werden beim Laden validiert und begrenzt.
- Unbekannte oder fehlende Werte fallen auf `AppSettings.defaults` zurueck.
- Migrationen werden ueber `fontFamilyMigratedToUbuntu` und `themePreferenceMigratedToLightMode` markiert.

Das Repository kennt Speicherformat und Migration; die Seite kennt nur das Modell. Dieses Muster ist fuer neue Anwendungen gut wiederverwendbar.

## 7. Vorlage fuer neue Anwendungen

| Baustein | Verantwortung |
|---|---|
| `AppSettings` | typisierte Werte, Defaults, `copyWith` |
| `SettingsPage` | Eingabe, Vorschau, Speichern/Verwerfen |
| `SettingsController` | Laden, Veröffentlichen, Speichern |
| `SettingsRepository` | Persistenz, Validierung, Migration |
| Storage-Adapter | konkretes lokales Backend |
| App-Root | globale Anwendung von Theme, Font und Skalierung |

Empfohlene Grundstruktur:

```dart
@immutable
class AppSettings {
  const AppSettings({
    required this.fontFamily,
    required this.textScaleFactor,
    required this.useLightTheme,
  });

  final String fontFamily;
  final double textScaleFactor;
  final bool useLightTheme;
}
```

## 8. UX- und Designregeln

- Gruppen nach ihrer Wirkung benennen: Darstellung, Lesbarkeit, Farben, Verhalten und Daten.
- Jede Option zeigt ihren aktuellen Wert unmittelbar.
- Farbauswahl kombiniert Farbswatch und Namen; Farbe allein reicht nicht.
- Slider zeigen Wert, Einheit, Minimum und Maximum.
- Globale visuelle Aenderungen werden in einer Vorschau sichtbar.
- Speichern ist eindeutig; Verwerfen wird bei Aenderungen bestaetigt.
- Destruktive oder datenbezogene Aktionen gehoeren in einen getrennten Bereich.
- Moduleigene Optionen bleiben im jeweiligen Fachmodul.
- Einstellungen werden beim Laden und Speichern validiert.
- Bei wachsendem Umfang sind Tabs oder Unterseiten besser als eine endlose Liste.

## 9. Accessibility und Qualitaet

- Alle Controls erhalten sichtbare Labels.
- Icon-only-Aktionen bekommen Tooltips und Semantics.
- Die Settings-Seite muss mit Tastatur und Screenreader bedienbar sein.
- Schriftvergroesserung darf keine abgeschnittenen oder ueberlappenden Controls erzeugen.
- Theme- und Farbkombinationen werden in hell und dunkel auf Kontrast geprueft.
- Ungueltige oder veraltete gespeicherte Werte fallen kontrolliert auf Defaults zurueck.

## 10. Checkliste fuer neue Apps

- [ ] Settings-Modell immutable und typisiert.
- [ ] Defaults an einer zentralen Stelle.
- [ ] Controller und Repository getrennt.
- [ ] Persistenzformat dokumentiert.
- [ ] Migrationen fuer geaenderte Defaults oder Schluessel vorhanden.
- [ ] Erlaubte Werte und Wertebereiche validiert.
- [ ] Lokale Bearbeitung mit Speichern/Verwerfen umgesetzt.
- [ ] Vorschau fuer visuelle Einstellungen vorhanden.
- [ ] Globale Laufzeitwirkung am App-Root gebuendelt.
- [ ] Accessibility, Kontrast und grosse Schrift getestet.
- [ ] Fachliche Modul-Settings von globalen UI-Settings getrennt.

## 11. Aktueller Abgleich

**Umgesetzt:** typisiertes Modell, zentrale Defaults, Controller, Repository, Sembast-Persistenz, Migrationen, lokale Aenderungsbearbeitung, Vorschau, Theme-/Font-/Farbsteuerung und globale Textskalierung.

**Offen beziehungsweise weiter pruefbar:** vollstaendige Tastatur- und Screenreader-Pruefung, Kontrastpruefung aller Farbkombinationen sowie eine adaptive Aufteilung der Settings-Seite bei kuenftig wachsendem Umfang.
