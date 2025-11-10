import cv2
import numpy as np
from ultralytics import YOLO

# ---- Modelle ----
BASE_MODEL = "yolo11s.pt"                             # nur sink/toilet
CUSTOM_MODEL = "runs/detect/train10/weights/best.pt"  # trainiertes Modell
IMG = 640
CONF = 0.25
IOU_MERGE = 0.5
DEVICE = None 

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

USE_FROM_BASE   = {"sink", "toilet"}
USE_FROM_CUSTOM = {"soap_dispenser", "toilet_door_open", "toilet_door_closed"}

def to_canonical(name: str) -> str:
    return NORMALIZE.get(name, name)

def iou_xyxy(a, b):
    x1 = max(a[0], b[0]); y1 = max(a[1], b[1])
    x2 = min(a[2], b[2]); y2 = min(a[3], b[3])
    inter = max(0, x2 - x1) * max(0, y2 - y1)
    area_a = (a[2]-a[0]) * (a[3]-a[1])
    area_b = (b[2]-b[0]) * (b[3]-b[1])
    union = area_a + area_b - inter + 1e-9
    return inter / union

def nms(boxes, scores, iou_thr=0.5):
    if len(boxes) == 0: return []
    idxs = np.argsort(scores)[::-1]
    keep = []
    while len(idxs):
        i = idxs[0]; keep.append(i)
        if len(idxs) == 1: break
        rest = idxs[1:]
        ious = np.array([iou_xyxy(boxes[i], boxes[j]) for j in rest])
        idxs = rest[ious < iou_thr]
    return keep

def collect(model, frame, pick_names, device=None):
    out_boxes, out_scores, out_labels = [], [], []
    res = model.predict(frame, imgsz=IMG, conf=CONF, verbose=False, device=device)[0]
    if res.boxes is None or len(res.boxes) == 0:
        return out_boxes, out_scores, out_labels
    names_map = model.names  
    for b, c, s in zip(res.boxes.xyxy.cpu().numpy(),
                       res.boxes.cls.cpu().numpy().astype(int),
                       res.boxes.conf.cpu().numpy()):
        raw = names_map.get(c, str(c))
        lab = to_canonical(raw)
        if lab in pick_names:
            out_boxes.append(b.tolist())
            out_scores.append(float(s))
            out_labels.append(lab) 
    return out_boxes, out_scores, out_labels

def draw(frame, boxes, scores, labels, color=(0,255,0)):
    for (x1,y1,x2,y2), sc, lab in zip(boxes, scores, labels):
        p1 = (int(x1), int(y1)); p2 = (int(x2), int(y2))
        cv2.rectangle(frame, p1, p2, color, 2)
        txt = f"{lab} {sc:.2f}"
        (w,h), _ = cv2.getTextSize(txt, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 2)
        cv2.rectangle(frame, (p1[0], max(0, p1[1]-h-6)), (p1[0]+w+6, p1[1]), color, -1)
        cv2.putText(frame, txt, (p1[0]+3, max(0, p1[1]-5)),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0,0,0), 2, cv2.LINE_AA)

def main():
    base = YOLO(BASE_MODEL)
    custom = YOLO(CUSTOM_MODEL)
    cap = cv2.VideoCapture(0)  
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

    while True:
        ok, frame = cap.read()
        if not ok: break

        b_boxes, b_scores, b_labels = collect(base, frame, USE_FROM_BASE, device=DEVICE)
        c_boxes, c_scores, c_labels = collect(custom, frame, USE_FROM_CUSTOM, device=DEVICE)

        all_boxes  = np.array(b_boxes + c_boxes, dtype=float) if (b_boxes or c_boxes) else np.zeros((0,4))
        all_scores = np.array(b_scores + c_scores, dtype=float)
        all_labels = np.array(b_labels + c_labels, dtype=object)

        keep = nms(all_boxes, all_scores, iou_thr=IOU_MERGE) if len(all_boxes) else []
        out = frame.copy()
        if len(keep):
            draw(out, all_boxes[keep], all_scores[keep], all_labels[keep], color=(0,255,0))

        cv2.imshow("Dual YOLO — base: sink/toilet | custom: door+soap", out)
        if cv2.waitKey(1) & 0xFF == 27:  # ESC
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
