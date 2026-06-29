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

## Swift App starten
Die Swift App befindet sich im Ordner:
```bash
Swift_app/toilet-assist-yolo
```
Die App nutzt die iPhone-Kamera und CoreML-Modelle, um Objekte direkt auf dem Gerät zu erkennen.

Die App führt Nutzer*innen schrittweise durch den Ablauf. 
Pro Schritt wird nur das jeweils relevante Zielobjekt gesucht. 
Die Rückmeldung erfolgt über Sprachausgabe, z. B. zur Richtung des erkannten Objekts. 
Zusätzlich können akustische Richtungssignale aktiviert oder deaktiviert werden.

### 1. Projekt in Xcode öffnen
Im Ordner Swift_app/toilet-assist-yolo die Xcode-Projektdatei öffnen:
```bash
toilet-assist-yolo.xcodeproj
```
### 2. Signing einstellen
In Xcode:
- Projekt auswählen
- App-Target auswählen
- Signing & Capabilities öffnen
- bei Team das eigene Apple-Konto auswählen
Der Bundle Identifier muss eindeutig sein, zum Beispiel:
```bash
com.katharina.toiletassist
```
### 3. Modelle prüfen
Die CoreML-Modelle müssen im Xcode-Projekt eingebunden sein.
Wichtig ist:

- Modell im Projekt anklicken
- rechts im File Inspector schauen
- bei Target Membership muss die App angehakt sein

### 4. App starten
Oben in Xcode ein Gerät auswählen, zum Beispiel:
- iPhone Simulator
- eigenes iPhone
Dann auf den Play-Button drücken.
Die App startet und zeigt die Kameraansicht mit Objekterkennung.
### 5. Hinweis
Falls Xcode nach Kamera-Berechtigung fragt, muss diese erlaubt werden.
Ohne Kamera-Zugriff kann die App keine Objekte erkennen.



