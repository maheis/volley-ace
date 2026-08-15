# VolleyAce

Volleyball Assistenz-App für Trainer, Spieler und Schiedsrichter.

- Punktetafel - Ersetzt die klassische Punktetafel, mit Touchbedienung!
- Punktewertung - Bewerten wie Punkte gemacht werden um eine Statistik zu Spielern und Teams zu erstellen.
- Teams - Spieler und Trainer verwalten, Teamstatistiken einsehen und Taktiken speichern.
- Taktiktafel - Taktiken speichern und auf der Punktetafel anzeigen.

![Vorstellungsgrafik](.notes/vorstellungsgrafik.png)

## Technologie

- [x] Flutter/Dart
  - [x] Android
  - [ ] Web
  - [ ] Windows/Linux
- Lokaler Storage: Sembast
  - Datei: `volley_ace.db` auf Desktop/Android
  - IndexedDB im Web
  - Settings-Store: `settings`, Datensatz `app`
- [ ] Cloud Sync
- [ ] Anmeldung
- [ ] Teams
  - [ ] Mitglieder
  - [ ] Trainer
- [ ] Sprachsteuerung (insbesondere für die Punktetafel)
- [x] Bildschirm aktiv lassen

## Features

- [x] Punktetafel
  - Zwei farbige Satzpunkt-Anzeigen (blau/rot)
  - Gewonnene Sätze in der Mitte
  - Nach unten wischen: Punkt vergeben
  - Nach oben wischen: letzten Punkt zurücknehmen
  - Nach links/rechts wischen: Seiten, Farben und Spielstände tauschen
  - Satzgewinn automatisch ab 25 Punkten mit zwei Punkten Vorsprung
  - [x] Uhr / Stop-Uhr
  - [x] Letzte Punkte pro Satz anzeigen
  - [ ] Auszeiten pro Team anzeigen
  - [ ] Spielerwechsel pro Team anzeigen
- [x] Punktewertung
      Bewerten wie Punkte gemacht werden um eine Statistik zu Spielern und Teams zu erstellen.
      Es soll eine persistente Liste an Spielen geben, wird ein neues Spiel gestartet sollen die Spielinfos abgefragt werden.
      Wählt man ein Spiel aus, kann man entwender Punktewertung erfassen oder die Statistik einsehen.
  - [x] Spielinfos
        Abfragen beim Spielstart, um die Statistik zu speichern.
    - [x] Spielort
    - [x] Gegnerteam
    - [x] Spieltag / Datum (Heute) / Uhrzeit (Jetzt)
    - [x] Spieltyp (Liga, Turnier, Freundschaftsspiel, Trainingsspiel)
    - [x] Team / Spieler / Trainer
          Im Ersten Schritt pro Wertungsbogen Spieler (Name und Trikotnummer) mit + und - Buttons hinzufügen oder entfernen.
          Im zweiten Schritt Spieler aus dem Team welches vorab angelegt wird ausgewählt werden und die Punktewertung pro Spieler speichern.
  - [x] Punktewertung erfassen
    - [x] Punkt / Fehler
          Zwei Buttons Grün und Rot die je für Punkt / Fehler stehen und dann zur Abfrage des Spielers scrollen.
          Spielstand / Uhrzeit / Stopuhr
          - [ ] Auszeiten pro Team anzeigen
          - [ ] Spielerwechsel pro Team anzeigen
    - [x] Wer
          Spieler als Karte mit Name und Trikotnummer, die man nach oben oder unten scrollen kann, um den Spieler auszuwählen. 
    - [x] Wertung
          - Punkte
            Auswahl wie ein Punkt erreicht wurde.
            - Ass
            - Angriff
            - Block
          - Fehler
            Auswahl Welcher Fehler gemacht wurde.
            - Aufschlag
            - Ball ins Aus
            - Ball ins Netz
            - Ball nicht rüber
            - Zugeschaut (Ball im Feld)
            - Tusch
            - Übertritt
            - Netz Berührung
            - Sonstiges
    - [x] Statistik
      - [x] Spielstand
      - [x] Satzstand
      - [x] Punkte pro Art
      - [x] Fehler pro Art
      - [x] Spieler
        - [x] Punkte / Fehler pro Spieler
        - [x] Punkte pro Art
        - [x] Fehler pro Art
      - [ ] Export (Format das z.B. in Excel importiert werden kann)
- [x] Team
  - [x] Info
    - [x] Teamname
    - [ ] Teamlogo
    - [ ] Teamfarben
    - [ ] Teamprofil
    - [ ] Teamstatistik
    - [ ] Teambewertung
    - [ ] Achievements
  - [x] Spieler
    - [x] Name
    - [x] Trikotnummer
    - [x] Geburtsdatum / Alter
    - [x] Position
    - [x] Spielerprofil
    - [x] Spielerstatistik
    - [ ] Spielerbewertung
    - [ ] Spielertraining
    - [ ] Achievements
  - [x] Trainer
    - [x] Name
    - [x] Geburtsdatum / Alter
    - [x] Position
    - [x] Trainerprofil
    - [x] Trainerstatistik
    - [ ] Trainerbewertung
    - [ ] Achievements
- [ ] Rotation
- [x] Taktiktafel
  - [x] Speichern von Taktiken
- [ ] Soundboard
- [ ] Achievements
- [ ] Trainingsübungen
- [ ] Trainingsteilnahme
- [ ] Trainingsbewertungen
- [ ] Trainingsstände (Archivments)

## ToDo

- [x] Toast ist weiß!
- [x] Landscape Modus punktetafel soll automatisch zoom machen (pinch to zoom entfernen)
- [ ] icon (z.B. taskbar)
- [x] settings deutsch
- [ ] sportschrift
- [x] app name aktuell mit unterstich
- [ ] import / export (teams, punktewertung)
- [ ] farbe rosa in die app übernehmen
