from ultralytics import YOLO

# Dein trainiertes Modell laden
m = YOLO("runs/detect/train10/weights/best.pt")
print(m.names)
print(m.ckpt_path)  


# Testbild auswerten
results = m("docs/WC_5.11.2025.jpg")

# Ergebnisse anzeigen
results[0].show()
