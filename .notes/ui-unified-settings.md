# Einheitliche UI Controls, Design und Settings

## Status

Bereits vorhanden; entspricht dem gemeinsamen Standard.

## Gemeinsamer Standard

Alle Apps in `m.git` sollen dieselbe UI-Settings-Auswahl anbieten:

- Schriftart: `OpenDyslexic`, `NotoSans`, `CourierPrime`, `Ubuntu`, `Ubuntu Mono`
- Schriftgröße: 50 % bis 160 %
- Designmodus: hell oder dunkel
- Akzentfarbe: Rot, Orange, Grün, Gelb, Blau, Mint, Lila
- Highlight-Farbe: Rot, Orange, Grün, Gelb, Blau, Mint, Lila

## VolleyAce Umsetzung

- Settings-Modell: `lib/src/settings/app_settings.dart`
- Settings-Controller: `lib/src/settings/settings_controller.dart`
- Persistenz: `lib/src/settings/settings_repository.dart`
- Settings-Seite: `lib/src/settings/settings_page.dart`
- Farbpalette: `lib/src/theme/app_palette.dart`
- App-Theme: `lib/src/app.dart`

## Abgleich

VolleyAce nutzt bereits:

- `fontFamily`
- `textScaleFactor`
- `useLightTheme`
- `accentColorValue`
- `highlightColorValue`
- dieselbe Schriftliste
- dieselbe Farbpalette

Damit ist VolleyAce aktuell die Referenzstruktur für die gemeinsame UI-Settings-Schicht.
