import argparse
from pathlib import Path
from collections import defaultdict

import cv2
import numpy as np
import yaml
from ultralytics import YOLO


# Wichtig: Reihenfolge muss zu data.yaml passen
CLASSES = [
    "sink",
    "soap_dispenser",
    "toilet",
    "toilet_door_open",
    "toilet_door_closed",
    "flush",
]

CLASS2ID = {name: idx for idx, name in enumerate(CLASSES)}
ID2CLASS = {idx: name for name, idx in CLASS2ID.items()}

NORMALIZE = {
    "washbasin": "sink",
    "basin": "sink",
    "sink": "sink",

    "wc": "toilet",
    "toilet_bowl": "toilet",
    "toilet": "toilet",

    "soap-dispenser": "soap_dispenser",
    "soap": "soap_dispenser",
    "soap_dispenser": "soap_dispenser",

    "door_open": "toilet_door_open",
    "toilet-door-open": "toilet_door_open",
    "toilet_door_open": "toilet_door_open",

    "door_closed": "toilet_door_closed",
    "toilet-door-closed": "toilet_door_closed",
    "toilet_door_closed": "toilet_door_closed",

    "flush_button": "flush",
    "flush-handle": "flush",
    "flush_handle": "flush",
    "flush": "flush",
}

# Wie in deinem Dual-Modell:
USE_FROM_BASE = {"sink", "toilet"}
USE_FROM_CUSTOM = {
    "soap_dispenser",
    "toilet_door_open",
    "toilet_door_closed",
    "flush",
}


IMAGE_EXTENSIONS = [".jpg", ".jpeg", ".png", ".webp", ".bmp"]


def to_canonical(name: str) -> str:
    name = name.strip().lower().replace(" ", "_")
    return NORMALIZE.get(name, name)


def iou_xyxy(a, b) -> float:
    x1 = max(a[0], b[0])
    y1 = max(a[1], b[1])
    x2 = min(a[2], b[2])
    y2 = min(a[3], b[3])

    inter = max(0, x2 - x1) * max(0, y2 - y1)

    area_a = max(0, a[2] - a[0]) * max(0, a[3] - a[1])
    area_b = max(0, b[2] - b[0]) * max(0, b[3] - b[1])

    union = area_a + area_b - inter + 1e-9
    return inter / union


def nms(boxes, scores, labels, iou_thr=0.5):
    """
    Klassenweise NMS.
    Dadurch werden nur doppelte Boxen derselben Klasse entfernt.
    """
    if len(boxes) == 0:
        return []

    boxes = np.array(boxes)
    scores = np.array(scores)
    labels = np.array(labels)

    keep_all = []

    for label in sorted(set(labels)):
        idxs = np.where(labels == label)[0]
        idxs = idxs[np.argsort(scores[idxs])[::-1]]

        while len(idxs) > 0:
            current = idxs[0]
            keep_all.append(current)

            if len(idxs) == 1:
                break

            rest = idxs[1:]
            ious = np.array([iou_xyxy(boxes[current], boxes[j]) for j in rest])
            idxs = rest[ious < iou_thr]

    return keep_all


def load_data_yaml(data_yaml_path: str):
    with open(data_yaml_path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    base_path = Path(data.get("path", "."))
    val_path = Path(data["val"])

    if not val_path.is_absolute():
        val_path = base_path / val_path

    return val_path


def image_to_label_path(image_path: Path) -> Path:
    """
    Wandelt z. B.
    data/images/val/bild.jpg
    in
    data/labels/val/bild.txt
    um.
    """
    parts = list(image_path.parts)

    if "images" not in parts:
        raise ValueError(f"Bildpfad enthält keinen images-Ordner: {image_path}")

    idx = parts.index("images")
    parts[idx] = "labels"

    label_path = Path(*parts).with_suffix(".txt")
    return label_path


def yolo_label_to_xyxy(xc, yc, bw, bh, img_w, img_h):
    x1 = (xc - bw / 2) * img_w
    y1 = (yc - bh / 2) * img_h
    x2 = (xc + bw / 2) * img_w
    y2 = (yc + bh / 2) * img_h
    return [x1, y1, x2, y2]


def load_ground_truth(image_path: Path):
    img = cv2.imread(str(image_path))
    if img is None:
        raise ValueError(f"Bild konnte nicht gelesen werden: {image_path}")

    img_h, img_w = img.shape[:2]
    label_path = image_to_label_path(image_path)

    gts = []

    if not label_path.exists():
        return gts

    with open(label_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            values = line.split()
            cls_id = int(values[0])
            xc, yc, bw, bh = map(float, values[1:5])

            box = yolo_label_to_xyxy(xc, yc, bw, bh, img_w, img_h)

            gts.append({
                "class_id": cls_id,
                "box": box,
                "matched": False,
            })

    return gts


def collect_predictions(model, image, pick_names, imgsz, conf, device=None):
    boxes = []
    scores = []
    class_ids = []

    result = model.predict(
        image,
        imgsz=imgsz,
        conf=conf,
        verbose=False,
        device=device,
    )[0]

    if result.boxes is None or len(result.boxes) == 0:
        return boxes, scores, class_ids

    names_map = model.names

    for box, cls, score in zip(
        result.boxes.xyxy.cpu().numpy(),
        result.boxes.cls.cpu().numpy().astype(int),
        result.boxes.conf.cpu().numpy(),
    ):
        raw_name = names_map.get(int(cls), str(cls))
        label = to_canonical(raw_name)

        if label not in pick_names:
            continue

        if label not in CLASS2ID:
            continue

        boxes.append(box.tolist())
        scores.append(float(score))
        class_ids.append(CLASS2ID[label])

    return boxes, scores, class_ids


def collect_dual_predictions(base_model, custom_model, image_path, imgsz, conf, nms_iou, device=None):
    image = cv2.imread(str(image_path))

    if image is None:
        raise ValueError(f"Bild konnte nicht gelesen werden: {image_path}")

    base_boxes, base_scores, base_class_ids = collect_predictions(
        base_model,
        image,
        USE_FROM_BASE,
        imgsz,
        conf,
        device,
    )

    custom_boxes, custom_scores, custom_class_ids = collect_predictions(
        custom_model,
        image,
        USE_FROM_CUSTOM,
        imgsz,
        conf,
        device,
    )

    boxes = base_boxes + custom_boxes
    scores = base_scores + custom_scores
    class_ids = base_class_ids + custom_class_ids

    keep = nms(boxes, scores, class_ids, iou_thr=nms_iou)

    predictions = []

    for idx in keep:
        predictions.append({
            "class_id": class_ids[idx],
            "score": scores[idx],
            "box": boxes[idx],
            "image": str(image_path),
        })

    return predictions


def compute_ap(recall, precision):
    """
    AP-Berechnung mit Precision-Recall-Hüllkurve.
    """
    recall = np.concatenate(([0.0], recall, [1.0]))
    precision = np.concatenate(([0.0], precision, [0.0]))

    for i in range(len(precision) - 1, 0, -1):
        precision[i - 1] = max(precision[i - 1], precision[i])

    indices = np.where(recall[1:] != recall[:-1])[0]
    ap = np.sum((recall[indices + 1] - recall[indices]) * precision[indices + 1])

    return ap


def evaluate(all_predictions, all_ground_truths, iou_thr=0.5):
    """
    Berechnet Precision, Recall und mAP@0.5 über alle Klassen.
    """
    results = {}

    aps = []
    total_tp = 0
    total_fp = 0
    total_gt = 0

    for class_id, class_name in ID2CLASS.items():
        preds = [p for p in all_predictions if p["class_id"] == class_id]

        gt_by_image = {}
        gt_count = 0

        for image_path, gts in all_ground_truths.items():
            class_gts = [
                {
                    "box": gt["box"],
                    "matched": False,
                }
                for gt in gts
                if gt["class_id"] == class_id
            ]
            gt_by_image[image_path] = class_gts
            gt_count += len(class_gts)

        preds = sorted(preds, key=lambda x: x["score"], reverse=True)

        tp = np.zeros(len(preds))
        fp = np.zeros(len(preds))

        for i, pred in enumerate(preds):
            image_path = pred["image"]
            candidates = gt_by_image.get(image_path, [])

            best_iou = 0
            best_gt_idx = -1

            for gt_idx, gt in enumerate(candidates):
                current_iou = iou_xyxy(pred["box"], gt["box"])

                if current_iou > best_iou:
                    best_iou = current_iou
                    best_gt_idx = gt_idx

            if best_iou >= iou_thr and best_gt_idx >= 0 and not candidates[best_gt_idx]["matched"]:
                tp[i] = 1
                candidates[best_gt_idx]["matched"] = True
            else:
                fp[i] = 1

        if len(preds) > 0:
            tp_cum = np.cumsum(tp)
            fp_cum = np.cumsum(fp)

            recall_curve = tp_cum / (gt_count + 1e-9)
            precision_curve = tp_cum / (tp_cum + fp_cum + 1e-9)

            ap = compute_ap(recall_curve, precision_curve) if gt_count > 0 else 0.0
            precision = precision_curve[-1]
            recall = recall_curve[-1]
        else:
            ap = 0.0
            precision = 0.0
            recall = 0.0

        aps.append(ap)

        total_tp += int(tp.sum())
        total_fp += int(fp.sum())
        total_gt += gt_count

        results[class_name] = {
            "images": sum(
                1 for gts in all_ground_truths.values()
                if any(gt["class_id"] == class_id for gt in gts)
            ),
            "instances": gt_count,
            "precision": float(precision),
            "recall": float(recall),
            "ap50": float(ap),
        }

    overall_precision = total_tp / (total_tp + total_fp + 1e-9)
    overall_recall = total_tp / (total_gt + 1e-9)
    map50 = float(np.mean(aps))

    return results, {
        "precision": overall_precision,
        "recall": overall_recall,
        "map50": map50,
        "tp": total_tp,
        "fp": total_fp,
        "gt": total_gt,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base_model", default="yolo11s.pt")
    parser.add_argument("--custom_model", default="runs/detect/yolo11s_new_dataset_960/weights/best.pt")
    parser.add_argument("--data", default="data/data.yaml")
    parser.add_argument("--imgsz", type=int, default=960)
    parser.add_argument("--conf", type=float, default=0.25)
    parser.add_argument("--iou", type=float, default=0.5)
    parser.add_argument("--nms_iou", type=float, default=0.5)
    parser.add_argument("--device", default=None)
    args = parser.parse_args()

    val_dir = load_data_yaml(args.data)
    image_paths = sorted([
        path for path in val_dir.rglob("*")
        if path.suffix.lower() in IMAGE_EXTENSIONS
    ])

    if not image_paths:
        raise ValueError(f"Keine Val-Bilder gefunden in: {val_dir}")

    print(f"Val-Bilder: {len(image_paths)}")
    print(f"Base-Modell: {args.base_model}")
    print(f"Custom-Modell: {args.custom_model}")
    print(f"imgsz: {args.imgsz}, conf: {args.conf}, IoU: {args.iou}")

    base_model = YOLO(args.base_model)
    custom_model = YOLO(args.custom_model)

    all_predictions = []
    all_ground_truths = {}

    for image_path in image_paths:
        gts = load_ground_truth(image_path)
        all_ground_truths[str(image_path)] = gts

        preds = collect_dual_predictions(
            base_model,
            custom_model,
            image_path,
            imgsz=args.imgsz,
            conf=args.conf,
            nms_iou=args.nms_iou,
            device=args.device,
        )

        all_predictions.extend(preds)

    class_results, overall = evaluate(
        all_predictions,
        all_ground_truths,
        iou_thr=args.iou,
    )

    print("\n--- Dual-Modell Evaluation @ IoU 0.5 ---")
    print(f"{'Class':22s} {'Images':>8s} {'Instances':>10s} {'P':>8s} {'R':>8s} {'AP50':>8s}")

    for class_name, values in class_results.items():
        print(
            f"{class_name:22s} "
            f"{values['images']:8d} "
            f"{values['instances']:10d} "
            f"{values['precision']:8.3f} "
            f"{values['recall']:8.3f} "
            f"{values['ap50']:8.3f}"
        )

    print("\n--- Overall ---")
    print(f"Precision: {overall['precision']:.3f}")
    print(f"Recall:    {overall['recall']:.3f}")
    print(f"mAP@0.5:   {overall['map50']:.3f}")
    print(f"TP: {overall['tp']} | FP: {overall['fp']} | GT: {overall['gt']}")

    print("\nHinweis:")
    print("Diese Auswertung bewertet deine eigene Dual-Modell-Pipeline.")
    print("Die Werte sind nicht direkt identisch mit Ultralytics 'yolo detect val',")
    print("weil hier zwei Modelle kombiniert und eigene Filter/NMS angewendet werden.")


if __name__ == "__main__":
    main()