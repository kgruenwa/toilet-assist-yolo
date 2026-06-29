from ultralytics import YOLO

model = YOLO("runs/detect/yolo11s_new_dataset_960/weights/best.pt")

model.export(
    format="coreml",
    imgsz=960,
    nms=True
)