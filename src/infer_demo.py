from ultralytics import YOLO

# Modell laden
model = YOLO("yolo11s.pt")

# Testbild auswerten
results = model("docs/sample.jpg")

# Ergebnisse anzeigen
results[0].show()
