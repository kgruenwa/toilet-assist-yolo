<!-- Banner -->
<p align="center">
  <img src="assets/banner_yolo.png" alt="Toilet Assist YOLO – Banner" width="100%">
</p>

<!-- Dein Logo oben rechts -->
<img src="assets/ToiGuide.png" alt="Projekt-Logo" width="96" align="right">

# toilet-assist-yolo  
Bachelor 2026

**Toilet Assist YOLO** ist ein Computer-Vision-Projekt zur Erkennung relevanter Objekte in Sanitärräumen.  
Es basiert auf **YOLOv11 (Ultralytics)** und dient als technologische Grundlage für Assistenzsysteme.

---

## Inhaltsverzeichnis
- [Ziel des Projekts](#-ziel-des-projekts)
- [Installation](#-installation)
- [Training starten](#-training-starten)
- [Erkennung auf Bildern](#-erkennung-auf-bildern)
- [Livestream starten](#-livestream-starten)
- [Swift App starten](#swift-app-starten)

---

## ▸ Ziel des Projekts
Das Modell erkennt folgende Objekte:

| Klasse           | Bedeutung      |
|------------------|----------------|
| `toilet`         | Toilette       |
| `flush`          | Spülung        |
| `sink`           | Waschbecken    |
| `soap_dispenser` | Seifenspender  |

Die aktuelle App-Version konzentriert sich auf eine schrittweise Orientierung innerhalb des Sanitärraums. 
Die erkannten Zielobjekte werden nacheinander gesucht: Toilette, Spülung, Waschbecken und Seifenspender.

Dies ermöglicht z. B.:
- schrittweise Orientierungshilfe für blinde und sehbeeinträchtigte Personen
- sprachbasierte Rückmeldung zur Position erkannter Objekte
- zusätzliche akustische Unterstützung über Richtungstöne
- prototypische Umsetzung einer Smartphone-basierten Assistenz im Sanitärraum

---

## ▸ Installation
### Voraussetzungen 
Python 3.9–3.11 (getestet mit 3.9.6)
pip & venv

```bash
cd toilet-assist-yolo

python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate

pip install -r requirements.txt
```


---
## ▸ Training starten

```bash
yolo detect train \
  data=data/data.yaml \
  model=yolo11s.pt \
  epochs=50 \
  imgsz=640

```
Das trainierte Modell wird automatisch gespeichert unter folgendem Ordner:

```bash
runs/detect/train*/weights/best.pt
```
---
## ▸ Erkennung auf Bildern

```bash
yolo predict \
  model="runs/detect/train10/weights/best.pt" \
  source="docs" \
  imgsz=960 \
  conf=0.15 \
  name=trained
```
Ergebnisse werden in folgenden Ordnern angezeigt: 
```bash
runs/detect/trained/
```
Vergleich mit dem Basis Modell:
```bash
./compare.sh

```
Ergebnisse werden in folgenden Ordnern angezeigt: 
```bash
runs/detect/trained/
runs/detect/base/


```

## ▸ Livestream starten 

Der Livestream zeigt die Live-Kamera mit Objekterkennungen des trainierten Modells.

Aktuell relevante Klassen:
- `toilet`
- `flush`
- `sink`
- `soap_dispenser`

### Livestream ausführen

Virtuelle Umgebung aktivieren:

```bash
source .venv/bin/activate
```

Livestream starten:

```bash
python src/dual_model_webcam.py
```

Livestream beenden:

```bash
ESC drücken
```

> Hinweis: Falls ein anderes Skript für den Livestream verwendet wird, muss der Dateiname entsprechend angepasst werden.

---

## ▸ Swift App starten

Die Swift App befindet sich im Ordner:

```bash
Swift_app/toilet-assist-yolo
```

Die App nutzt die iPhone-Kamera und ein CoreML-Modell, um Objekte direkt auf dem Gerät zu erkennen.

Die App führt Nutzer*innen schrittweise durch den Ablauf. Pro Schritt wird nur das jeweils relevante Zielobjekt gesucht. Die aktuelle Reihenfolge ist:

1. Toilette finden
2. Spülung finden
3. Waschbecken finden
4. Seifenspender finden

Die Rückmeldung erfolgt über Sprachausgabe, z. B. zur Richtung des erkannten Objekts. Zusätzlich können akustische Richtungssignale aktiviert oder deaktiviert werden. Die Sprachausgabe bleibt dabei weiterhin aktiv.

### 1. Projekt in Xcode öffnen

Im Ordner `Swift_app/toilet-assist-yolo` die Xcode-Projektdatei öffnen:

```bash
toilet-assist-yolo.xcodeproj
```

### 2. Signing einstellen

In Xcode:

- Projekt auswählen
- App-Target auswählen
- `Signing & Capabilities` öffnen
- bei `Team` das eigene Apple-Konto auswählen

Der Bundle Identifier muss eindeutig sein, zum Beispiel:

```bash
com.katharina.toiletassist
```

### 3. Modell prüfen

Das CoreML-Modell muss im Xcode-Projekt eingebunden sein.

Wichtig ist:

- Modell im Projekt anklicken
- rechts im File Inspector prüfen
- bei `Target Membership` muss die App angehakt sein

Das aktuell im Swift-Code verwendete Modell heißt:

```swift
bestnewversion
```

Falls das Modell in Xcode anders heißt, muss der Modellname im `CameraViewModel` angepasst werden.

### 4. App starten

Oben in Xcode ein eigenes iPhone als Gerät auswählen und auf den Play-Button drücken.

Der iPhone Simulator eignet sich nur eingeschränkt, da die App eine echte Kamera benötigt.

Die App startet und zeigt die Kameraansicht mit Objekterkennung.

### 5. Hinweis

Falls iOS nach Kamera-Berechtigung fragt, muss diese erlaubt werden. Ohne Kamera-Zugriff kann die App keine Objekte erkennen.

