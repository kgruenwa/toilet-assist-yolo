#!/bin/bash

echo "=== Vorhersage mit TRAINED MODEL ==="
yolo predict model="runs/detect/train10/weights/best.pt" source="docs" imgsz=960 conf=0.15 name=trained --save

echo "=== Vorhersage mit BASE MODEL ==="
yolo predict model="yolo11s.pt" source="docs" imgsz=960 conf=0.15 name=base --save

echo "✅ Fertig! Ergebnisse gespeichert unter:"
echo "   runs/detect/trained/"
echo "   runs/detect/base/"


