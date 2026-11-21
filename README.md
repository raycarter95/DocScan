# DocScan – Dokumente scannen, benennen, in Google Drive ablegen

iOS-App (SwiftUI, iOS 17+):

1. **Foto aufnehmen** (oder aus Fotos wählen)
2. **Dokument wird automatisch erkannt** (Apple Vision). Die vier Ecken lassen sich verschieben, eine Lupe hilft beim genauen Platzieren
3. **Häkchen oben rechts** → Perspektive wird entzerrt, Kontrast optimiert
4. **Namensvorschlag aus dem Text** (OCR auf dem Gerät), z. B. „Rechnung Zahnarzt“, „Mahnung Stadtwerke“, „Steuerbescheid Finanzamt“
   – auf iPhones mit Apple Intelligence (iOS 26) zusätzlich ein KI-Vorschlag, ebenfalls nur auf dem Gerät
5. **Teilen** (System-Teilen-Dialog) oder **Hochladen** an das voreingestellte Ziel:
   - einen Ordner in **Google Drive** (frei wählbar, auch Unterordner, neue Ordner anlegen)
   - oder **auf dem iPhone** (Dateien-App → „Auf meinem iPhone“ → DocScan)

Gespeichert wird als **durchsuchbares PDF**: das Bild plus unsichtbarer Text, so funktionieren Suche und Kopieren. Alternativ als JPEG.

## Projektstruktur

```
project.yml                  XcodeGen-Projektbeschreibung
Config/Secrets.xcconfig      Google-Client-ID (musst du eintragen)
DocScan/
  App/DocScanApp.swift
  Models/                    Quad (Ecken), Einstellungen, ScanSession
  Services/
    DocumentProcessor.swift  Dokumenterkennung + Entzerrung
    TextRecognizer.swift     OCR (Deutsch/Englisch)
    NameSuggester.swift      Namensvorschlag per Stichwortliste (erweiterbar!)
    AINameSuggester.swift    optional: Apple Intelligence
    Exporter.swift           PDF/JPEG + lokales Speichern
    GoogleDrive.swift        Google-Anmeldung + Drive-REST-API
  Views/                     Start, Kamera, Ränder anpassen, Name/Teilen/Hochladen, Einstellungen, Ordnerwahl
```

## Einrichtung (Mac mit Xcode 16 oder neuer)

### 1. Xcode-Projekt erzeugen

```bash
brew install xcodegen
```

```bash
cd DocScan && xcodegen generate && open DocScan.xcodeproj
```

In Xcode unter *Signing & Capabilities* dein Team auswählen. Wenn nötig, die Bundle-ID ändern, z. B. `de.deinname.docscan`.
Danach läuft die App schon auf dem iPhone. „Hochladen“ speichert dann zunächst in der Dateien-App.

### 2. Google Drive anbinden (einmalig, ca. 10 Minuten)

1. <https://console.cloud.google.com> öffnen und ein **neues Projekt** anlegen
2. *APIs & Dienste → Bibliothek* → **Google Drive API** aktivieren
3. *APIs & Dienste → OAuth-Zustimmungsbildschirm* (bzw. „Google Auth Platform“):
   - Nutzertyp **Extern**, App-Name „DocScan“, deine E-Mail eintragen
   - Unter **Testnutzer** dein eigenes Google-Konto hinzufügen
4. *Anmeldedaten → Anmeldedaten erstellen → OAuth-Client-ID* → Typ **iOS**, Bundle-ID wie in Xcode
5. **Client-ID** und **iOS-URL-Schema** (umgekehrte Client-ID) in `Config/Secrets.xcconfig` eintragen
6. `xcodegen generate` erneut ausführen und die App starten
7. In der App: *Einstellungen → Google-Drive-Ordner hinzufügen* → anmelden → Ordner wählen. Dieser Ordner ist ab dann das Standard-Ziel

> **Hinweis zum Testmodus:** Solange die Google-App im Status „Testing“ ist, läuft die Anmeldung nach
> **7 Tagen** ab, und du musst dich in der App neu anmelden. Für die private Nutzung kannst du den
> Veröffentlichungsstatus auf „In Produktion“ setzen. Google zeigt dann beim Anmelden einmalig die Warnung
> „App nicht verifiziert“ (→ *Erweitert → Weiter*), danach bleibt die Anmeldung bestehen.
>
> Die App nutzt den vollen Drive-Zugriff (`auth/drive`). Nur so lassen sich bestehende Ordner als Ziel auswählen.

## Namensvorschläge anpassen

In `DocScan/Services/NameSuggester.swift` stehen zwei Listen:

- `documentTypes`: Rechnung, Mahnung, Vertrag, Bescheid, …
- `subjects`: Zahnarzt, Finanzamt, Krankenkasse, Stadtwerke, …

Die Reihenfolge gibt die Priorität vor: Spezifisches steht vor Allgemeinem, also „Zahnarzt“ vor „Arzt“.
Eigene Einträge, etwa deinen Vermieter oder Arbeitgeber, kannst du einfach ergänzen:

```swift
("Arbeitgeber", [#"muster gmbh"#]),
```

Wird kein bekannter Absender gefunden, nimmt die App den Firmennamen aus dem Briefkopf (GmbH, AG …).
In den Einstellungen lässt sich zusätzlich das Dokumentdatum voranstellen: `2026-11-14 Rechnung Zahnarzt`.

## Ideen für Version 2

- Mehrseitige Dokumente (mehrere Fotos → ein PDF)
- Live-Kantenerkennung schon im Kamerabild
- Unterordner automatisch nach Dokumentart oder Jahr wählen (z. B. `Rechnungen/2026`)
- Upload-Warteschlange, wenn offline
