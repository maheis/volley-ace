# VolleyAce

Volleyball Assistenz-App für Trainer, Spieler und Schiedsrichter.

- Punktetafel - Ersetzt die klassische Punktetafel, mit Touchbedienung!
- Taktiktafel - Taktiken speichern und auf der Punktetafel anzeigen.
- Teams - Spieler und Trainer verwalten, Teamstatistiken einsehen und Taktiken speichern.
- Punktewertung - Bewerten wie Punkte gemacht werden um eine Statistik zu Spielern und Teams zu erstellen.

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
- [ ] Resposives Design

## Features

- [x] Punktetafel
  - Zwei farbige Satzpunkt-Anzeigen (blau/rot
  - Gewonnene Sätze in der Mitte
  - Nach unten wischen: Punkt vergeben
  - Nach oben wischen: letzten Punkt zurücknehmen
  - Nach links/rechts wischen: Seiten, Farben und Spielstände tauschen
  - Satzgewinn automatisch ab 25 Punkten mit zwei Punkten Vorsprung
  - [x] Uhr / Stop-Uhr
    - [x] Stop-Uhr automatisch starten wenn erster Punkt vergeben wird (damit sie zumindest verzögert startet...)
  - [x] Letzte Punkte pro Satz anzeigen
  - [x] Verlauf pro Satz anzeigen
  - [x] Auszeiten pro Team
        30 Sekunden Timer
        2 Stück pro Satz und Team
  - [ ] Rotation / Spielerwechsel (optional)
    - [ ] Spielinfos
      - [ ] Team A
        - [ ] Team (optional)
        - [ ] Spieler/Nummern
      - [ ] Team B
        - [ ] Team (optional)
        - [ ] Spieler/Nummern
      - [ ] Aufschlagteam
      - [ ] Spielklasse auswählen (U12, U13, U14, U15, U16, U18, U20, Damen, Herren, Mixed, Freizeit)
            Rotation/Position muss je nach Spielklasse unterschiedlich sein!
            U12-U13: 3 Spieler, U14-U15: 4 Spieler, Rest: 6 Spieler
            U12-U15: Rotation nach 2 Aufschlägen und bei Aufschlagwechsel, Rest: Rotation nach Aufschlagwechsel
    - [ ]  
      - [ ] Startaufstellung (Positionsnummern)
      - [ ] Ersatzspieler
      - [ ] Spielerwechsel
    - [ ] Anzeige in einem Spielfeld auf den jeweiligen Positionen 1-6
          Bei Punktvergabe soll Rotation berücksichtigt werden, manuell soll aber auch eine Rotation ausgelöst werden können (falls ein Team außerhalb der Punkte-Rotation rotieren möchte)
- [x] Taktiktafel
  - [x] Speichern von Taktiken
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
      - [ ] Punktewertung
      - [ ] Trainingsstatistik
    - [ ] Spielerbewertung
    - [ ] Trainingsteilnahme
    - [ ] Trainingsbewertungen
    - [ ] Trainingsstände
    - [ ] Achievements
  - [x] Trainer
    - [x] Name
    - [x] Geburtsdatum / Alter
    - [x] Position
    - [x] Trainerprofil
    - [x] Trainerstatistik
    - [ ] Trainerbewertung
    - [ ] Achievements
- [x] Punktewertung
      Bewerten wie Punkte gemacht werden um eine Statistik zu Spielern und Teams zu erstellen.
      Es soll eine persistente Liste an Spielen geben, wird ein neues Spiel gestartet sollen die Spielinfos abgefragt werden.
      Wählt man ein Spiel aus, kann man entweder Punktewertung erfassen oder die Statistik einsehen.
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
    - [x] Wertung
          - Punkte
            Auswahl wie ein Punkt erreicht wurde.
            - Ass
            - Angriff
            - Block
            - Gegnerfehler
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
      - [ ] Auszeit (wichtig für den Verlauf)
    - [x] Wer
          Spieler als Karte mit Name und Trikotnummer, die man nach oben oder unten scrollen kann, um den Spieler auszuwählen.
    - [x] Verlauf
    - [x] Statistik
      - [x] Spielstand
      - [x] Satzstand
      - [x] Punkte pro Art
      - [x] Fehler pro Art
      - [ ] Diagram über Punkte/Fehler im Zeitverlauf
      - [x] Spieler
        - [x] Punkte / Fehler pro Spieler
        - [x] Punkte pro Art
        - [x] Fehler pro Art
        - [ ] Diagram über Punkte/Fehler im Zeitverlauf
        - [ ] Aufklappbare Details pro Spieler
      - [ ] Export (Format das z.B. in Excel importiert werden kann)
- [ ] Training
  - [ ] Team
  - [ ] Trainingsteilnahme
    - [ ] Teilnahme
    - [ ] Entschuldigt
    - [ ] Unentschuldigt
  - [ ] Trainingsplan
  - [ ] Trainingsstatistik
  - [ ] Trainingsbewertung
- [ ] Trainingspläne
- [ ] Trainingsübungen
- [ ] Volley-Arcade

## ToDo

- [x] Toast ist weiß!
- [x] Landscape Modus punktetafel soll automatisch zoom machen (pinch to zoom entfernen)
- [ ] icon (z.B. taskbar)
- [x] settings deutsch
- [-] sportschrift
- [x] app name aktuell mit unterstich
- [ ] import / export (teams, punktewertung, taktiktafel)
  - [ ] diff / import-date vs. änderungsdatum
- [ ] farbe rosa in die app übernehmen?
- [ ] varlaufdarstellung wie einen versionsgraphen