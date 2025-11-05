# toilet-assist-yolo
Bachelor 2026

**Toilet Assist YOLO** ist ein Computer-Vision-Projekt zur Erkennung relevanter Objekte in Sanitärräumen.  
Es basiert auf **YOLOv11 (Ultralytics)** und dient als technologische Grundlage für Assistenzsysteme.

---

##  Ziel des Projekts
Das Modell erkennt folgende Objekte:

| Klasse                 | Bedeutung                          |
|-----------------------|-------------------------------------|
| `sink`                | Waschbecken                         |
| `soap_dispenser`      | Seifenspender                       |
| `toilet`              | Toilette                            |
| `toilet_door_open`    | WC-Kabine geöffnet                  |
| `toilet_door_closed`  | WC-Kabine geschlossen               |

Dies ermöglicht z. B.:

- Orientierungshilfe und Assistenz für Sehbeinträchtige 
- Automatisierte Erkennung von Nutzungszuständen (Ist die Toilette besetzt?)

---

## 💾 Installation

```bash
pip install ultralytics roboflow python-dotenv
```
Apple M-Pro/M-Max (ohne GPU):
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu


