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

```bash
pip install ultralytics roboflow python-dotenv
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
Das trainierte Modell wird automatisch gespeichert in:

```bash
runs/detect/train*/
```
---
## ▸ Erkennung auf Bildern

```bash
yolo detect predict \
  model="runs/detect/train*/weights/best.pt" \
  source="docs/sample.jpg" \
  conf=0.25
```
Ausgabe inkl. Bounding Boxes:

```bash
runs/detect/predict/
```
Um ein anderes Bild zu testen, einfach den Dateinamen ändern:

```bash
yolo detect predict \
  model="runs/detect/train*/weights/best.pt" \
  source="WC_5.11.2025.jpg" \
  conf=0.25
```






