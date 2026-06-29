from pathlib import Path
from ultralytics import YOLO

MODEL_PATH = "runs/detect/train10/weights/best.pt"
DATA_YAML = "data/data.yaml"

def main():
    model_path = Path(MODEL_PATH)

    if not model_path.exists():
        raise FileNotFoundError(f"Modell nicht gefunden: {model_path}")

    model = YOLO(str(model_path))

    metrics = model.val(
        data=DATA_YAML,
        imgsz=640,
        conf=0.001,
        iou=0.5,
        split="val",
        plots=True,
        save_json=True
    )

    print("Precision:", metrics.box.mp)
    print("Recall:", metrics.box.mr)
    print("mAP@0.5:", metrics.box.map50)
    print("mAP@0.5:0.95:", metrics.box.map)

if __name__ == "__main__":
    main()