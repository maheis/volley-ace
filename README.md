# VolleyAce

Volleyball Assistenz

## Technologie

- [ ] Flutter/Dart
  - [ ] Android
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

## Featrues

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
- [ ] Punktewertung
      Bewerten wie Punkte gemacht werden um eine Statistik zu Spielern und Teams zu erstellen.
      Es soll eine persistente Liste an Spielen geben, wird ein neues Spiel gestartet sollen die Spielinfos abgefragt werden.
      Wählt man ein Spiel aus, kann man entwender Punktewertung erfassen oder die Statistik einsehen.
  - [x] Spielinfos
        Abfragen beim Spielstart, um die Statistik zu speichern.
    - [x] Spielort
    - [x] Gegnerteam
    - [x] Spieltag / Datum (Heute) / Uhrzeit (Jetzt)
    - [x] Spieltyp (Liga, Turnier, Freundschaftsspiel, Trainingsspiel)
    - [x] Team / Spieler
          Im Ersten Schritt pro Wertungsbogen Spieler (Name und Trikotnummer) mit + und - Buttons hinzufügen oder entfernen.
          Im zweiten Schritt Spieler aus dem Team welches vorab angelegt wird ausgewählt werden und die Punktewertung pro Spieler speichern.
  - [ ] Punktewertung erfassen
    - [ ] Punkt / Fehler
          Zwei Buttons Grün und Rot die je für Punkt / Fehler stehen und dann zur Abfrage des Spielers scrollen.
    - [ ] Wer
          Spieler als Karte mit Name und Trikotnummer, die man nach oben oder unten scrollen kann, um den Spieler auszuwählen. 
      - Punkte
        Auswahl wie ein Punkt erreicht wurde.
        - [ ] Ass
        - [ ] Angriff
        - [ ] Block
      - Fehler
        Auswahl Welcher Fehler gemacht wurde.
        - [ ] Aufschlag
        - [ ] Ball ins Aus
        - [ ] Ball ins Netz
        - [ ] Ball nicht rüber
        - [ ] Zugeschaut (Ball im Feld)
        - [ ] Tusch
        - [ ] Übertritt
        - [ ] Netz Berührung
        - [ ] Sonstiges
    - [ ] Statistik
      - [ ] Spielstand
      - [ ] Satzstand
      - [ ] Punkte pro Spieler, aufgeschlüsselt nach Punktarten
      - [ ] Fehler pro Spieler, aufgeschlüsselt nach Fehlerarten
      - [ ] Punkte pro Team, aufgeschlüsselt nach Punktarten
      - [ ] Fehler pro Team, aufgeschlüsselt nach Fehlerarten
- [ ] Team
  - [ ] Spieler
    - [ ] Name
    - [ ] Trikotnummer
    - [ ] Geburtsdatum / Alter
    - [ ] Position
    - [ ] Spielerprofil
    - [ ] Spielerstatistik
    - [ ] Spielerbewertung
    - [ ] Spielertraining
    - [ ] Achievements
  - [ ] Trainer
    - [ ] Trainerprofil
    - [ ] Trainerstatistik
    - [ ] Trainerbewertung
    - [ ] Achievements
- [ ] Achievements
- [ ] Rotation
- [ ] Soundboard
- [ ] Trainingsübungen
- [ ] Trainingsteilnahme
- [ ] Trainingsbewertungen
- [ ] Trainingsstände (Archivments)

## ToDo

- [x] Toast ist weiß!
- [ ] Landscape Modus punktetafel soll automatisch zoom machen (pinch to zoom entfernen)