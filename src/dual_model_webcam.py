import cv2
import numpy as np
from ultralytics import YOLO

# ---- Modelle ----
BASE_MODEL = "yolo11s.pt"                             # nur sink/toilet
CUSTOM_MODEL = "runs/detect/train10/weights/best.pt"  # trainiertes Modell
IMG = 640 # Eingangsgröße der Bilder für YOLO (640x640)
CONF = 0.25 #Confidenz mit dem Yolo die Gegenstände die er erkennt auch ausgibt 
IOU_MERGE = 0.5 #doppelte Erkennung entfernen 
DEVICE = None # None = YOLO entscheidet selbst (GPU/Wirtschaft/CPU)

# Zuordnung verschiedener Labelvarianten zu einem gemeinsamen einheitlichen Namen
NORMALIZE = {
    "washbasin": "sink",
    "basin": "sink",
    "wc": "toilet",
    "toilet_bowl": "toilet",
    "soap-dispenser": "soap_dispenser",
    "soap": "soap_dispenser",
    "door_open": "toilet_door_open",
    "door_closed": "toilet_door_closed",
    "toilet-door-open": "toilet_door_open",
    "toilet-door-closed": "toilet_door_closed",
}

# Aus dem Basis-Modell möchten wir nur diese Objektklassen verwenden:
USE_FROM_BASE   = {"sink", "toilet"}
# Aus dem Custom-Modell möchten wir nur diese Klassen übernehmen:
USE_FROM_CUSTOM = {"soap_dispenser", "toilet_door_open", "toilet_door_closed"}

#alle Labels in eine Satndartform wie in Normalize angegeben bringen: 
def to_canonical(name: str) -> str:
    return NORMALIZE.get(name, name) 

#Diese Funktion berechnet die Überlappung der Boxen 
def iou_xyxy(a, b): 
    """
    Berechnet die Intersection-over-Union zweier Bounding Boxes.
    Eingabeformat: [x1, y1, x2, y2]
    
    Rückgabe: IOU-Wert zwischen 0 und 1.
    """
    # Koordinaten der Überlappungsfläche
    x1 = max(a[0], b[0]); 
    y1 = max(a[1], b[1])
    x2 = min(a[2], b[2]); 
    y2 = min(a[3], b[3])

    # Fläche der Überlappung
    inter = max(0, x2 - x1) * max(0, y2 - y1)
     # Flächen der einzelnen Boxen
    area_a = (a[2]-a[0]) * (a[3]-a[1])
    area_b = (b[2]-b[0]) * (b[3]-b[1])
    # Fläche der Vereinigungsmenge (Gesamtfläche minus Schnittmenge)
    union = area_a + area_b - inter + 1e-9 # 1e-9 verhindert Division durch 0
    return inter / union

#Entfernt sich überlappende Boxen der Erkennung 
def nms(boxes, scores, iou_thr=0.5):
    """
    Non-Maximum-Suppression:
    Entfernt doppelte/überlappende Boxen. Behalte die Box mit dem höchsten Score.
    """
    if len(boxes) == 0: return [] #Wenn mehr als eine Box vorhanden ist 
    idxs = np.argsort(scores)[::-1] #sortieren nach dem höchsten Preis (höchste Konfidenz zuerst)
    keep = []
    while len(idxs):
        # Index der Box mit dem höchsten Score behalten
        i = idxs[0]; keep.append(i)
        # Wenn das die letzte Box ist -> fertig
        if len(idxs) == 1: break
        # Alle anderen Boxen prüfen 
        rest = idxs[1:]
        # IOU zwischen der besten Box und allen anderen berechnen
        ious = np.array([iou_xyxy(boxes[i], boxes[j]) for j in rest])
        # Nur Boxen behalten, deren IOU < Schwellwert ist
        idxs = rest[ious < iou_thr]
    return keep

#Alle Detections einsammeln vom Modell
def collect(model, frame, pick_names, device=None):
    """
    Führt die YOLO-Prediction aus und filtert die Ergebnisse.
    
    - model: YOLO-Modell
    - frame: aktuelles Kamerabild
    - pick_names: Menge der gewünschten Klassen
    """
    out_boxes, out_scores, out_labels = [], [], []
    # Prediction durchführen
    res = model.predict(frame, imgsz=IMG, conf=CONF, verbose=False, device=device)[0]
    # Falls keine Boxen vorhanden sind → leere Listen zurückgeben
    if res.boxes is None or len(res.boxes) == 0:
        return out_boxes, out_scores, out_labels
    names_map = model.names  # Mapping von Klassenindex → Klassenname

    # Für jede Detection die Daten extrahieren
    for b, c, s in zip(
        res.boxes.xyxy.cpu().numpy(), # Box-Koordinaten
        res.boxes.cls.cpu().numpy().astype(int),# Klassenindex
        res.boxes.conf.cpu().numpy() # Confidence
    ):
        raw = names_map.get(c, str(c)) # Roh-Label aus YOLO
        lab = to_canonical(raw) #aufruf zur normalisierung des Namens

        if lab in pick_names: #nur gewünschte Klassen behalten 
            out_boxes.append(b.tolist())
            out_scores.append(float(s))
            out_labels.append(lab) 
    return out_boxes, out_scores, out_labels

# Frames zeichen Rechtecken 
def draw(frame, boxes, scores, labels, color=(0,255,0)): 
    """
    Zeichnet Bounding Boxes + Labels + Confidence Scores in das Videobild.
    """
    for (x1,y1,x2,y2), sc, lab in zip(boxes, scores, labels):
        p1 = (int(x1), int(y1)); 
        p2 = (int(x2), int(y2))

        # Rechteck zeichnen
        cv2.rectangle(frame, p1, p2, color, 2)

        # Text vorbereiten
        txt = f"{lab} {sc:.2f}"

        # Textgröße berechnen
        (w,h), _ = cv2.getTextSize(txt, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)

         # Hintergrund für Text zeichnen
        cv2.rectangle(frame, (p1[0], max(0, p1[1]-h-6)), (p1[0]+w+6, p1[1]), color, -1)

        # Text schreiben
        cv2.putText(frame, txt, (p1[0]+3, max(0, p1[1]-5)), 
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0,0,0), 2, cv2.LINE_AA)

def main():
    base = YOLO(BASE_MODEL)
    custom = YOLO(CUSTOM_MODEL)

    # Kamera öffnen (0 = Standardkamera)
    cap = cv2.VideoCapture(0)  
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

    while True:
        ok, frame = cap.read()
        if not ok: break

        #Ergebnisse aus beiden Modellen holen
        b_boxes, b_scores, b_labels = collect(base, frame, USE_FROM_BASE, device=DEVICE)
        c_boxes, c_scores, c_labels = collect(custom, frame, USE_FROM_CUSTOM, device=DEVICE)

        #Alles in gemeinsame Arrays packen - zusammenführne 
        all_boxes  = np.array(b_boxes + c_boxes, dtype=float) if (b_boxes or c_boxes) else np.zeros((0,4))
        all_scores = np.array(b_scores + c_scores, dtype=float)
        all_labels = np.array(b_labels + c_labels, dtype=object)

        #Gemeinsame NMS ausführen
        keep = nms(all_boxes, all_scores, iou_thr=IOU_MERGE) if len(all_boxes) else []
        out = frame.copy()
        if len(keep):
            #Nur finale Boxen zeichnen, siehe Funktion oben 
            draw(out, all_boxes[keep], all_scores[keep], all_labels[keep], color=(0,255,0))
        #Bild anzeigen
        cv2.imshow("Dual YOLO — base: sink/toilet | custom: door+soap", out)
         # ESC drücken → Programm beenden
        if cv2.waitKey(1) & 0xFF == 27:  # Der ESC-Key (Escape) hat den ASCII-Code 27.
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
