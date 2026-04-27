from ultralytics import YOLO

YOLO("yolo11s.pt").export(format="coreml", imgsz=640, nms=True)
YOLO("../runs/detect/train10/weights/best.pt").export(format="coreml", imgsz=640, nms=True)