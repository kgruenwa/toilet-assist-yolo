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

| Klasse                 | Bedeutung                          |
|-----------------------|-------------------------------------|
| `sink`                | Waschbecken                         |
| `soap_dispenser`      | Seifenspender                       |
| `toilet`              | Toilette                            |
| `toilet_door_open`    | WC-Kabine geöffnet                  |
| `toilet_door_closed`  | WC-Kabine geschlossen               |

Dies ermöglicht z. B.:
- Orientierungshilfe und Assistenz für Sehbeeinträchtigte
- Automatisierte Erkennung von Nutzungszuständen (Ist die Toilette besetzt?)

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

Der Livestream zeigt die Live-Kamera mit Erkennungen aus zwei Modellen:
Basis-Modell (YOLO11s) → erkennt sink & toilet
Custom-Modell → erkennt soap_dispenser, toilet_door_open, toilet_door_closed

1. Virtuelle Umgebung aktivieren (falls noch nicht aktiv)
```bash
source .venv/bin/activate
```
2. Livestream starten
```bash
python src/dual_model_webcam.py
```
3.  Livestream beenden
einfach die ESC taste drücken 





