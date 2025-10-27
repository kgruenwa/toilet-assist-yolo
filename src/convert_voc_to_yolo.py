import argparse, os, xml.etree.ElementTree as ET
from pathlib import Path
from PIL import Image

# === Klassen-Definitionen (an XML-<name> anpassen!) ============================
CLASSES = ["sink", "soap_dispenser", "toilet", "toilet_door_open", "toilet_door_closed"]
CLASS2ID = {c: i for i, c in enumerate(CLASSES)}

ALIASES = {
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

SKIP_DIFFICULT = True  

IMG_EXTS = [".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tif", ".tiff"]

def voc_to_yolo_bbox(box, w, h):
    xmin, ymin, xmax, ymax = box
    x_c = (xmin + xmax) / 2.0
    y_c = (ymin + ymax) / 2.0
    bw = xmax - xmin
    bh = ymax - ymin
    return x_c / w, y_c / h, bw / w, bh / h

def normalize_name(name: str) -> str:
    n = name.strip().lower().replace(" ", "_")
    if n in ALIASES:
        n = ALIASES[n]
    return n

def convert_dir(xml_dir, img_dir, out_dir):
    xml_dir = Path(xml_dir)
    img_dir = Path(img_dir)
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    converted, skipped = 0, 0
    for xml in sorted(xml_dir.glob("*.xml")):
        try:
            root = ET.parse(xml).getroot()
        except Exception as e:
            print(f"⚠️  Konnte XML nicht lesen ({xml.name}): {e}")
            skipped += 1
            continue

        filename = root.findtext("filename") or (xml.stem + ".jpg")

        # passendes Bild suchen
        img_path = None
        stem = Path(filename).stem
        for ext in IMG_EXTS:
            p = img_dir / f"{stem}{ext}"
            if p.exists():
                img_path = p
                break
        if img_path is None:
            print(f"⚠️  Bild fehlt für {xml.name}")
            skipped += 1
            continue

        # Bildgröße
        try:
            with Image.open(img_path) as im:
                w, h = im.size
        except Exception:
            size = root.find("size")
            if size is None:
                print(f"⚠️  Keine Größe für {xml.name}")
                skipped += 1
                continue
            w = int(size.findtext("width"))
            h = int(size.findtext("height"))

        lines = []
        for obj in root.findall("object"):
            # optional schwierige überspringen
            if SKIP_DIFFICULT:
                diff = obj.findtext("difficult")
                if diff and diff.strip() in {"1", "true", "True"}:
                    continue

            name = normalize_name(obj.findtext("name") or "")
            if name not in CLASS2ID:
                print(f"⚠️  Unbekannte Klasse '{name}' in {xml.name} (übersprungen)")
                continue

            bnd = obj.find("bndbox")
            if bnd is None:
                continue
            xmin = float(bnd.findtext("xmin"))
            ymin = float(bnd.findtext("ymin"))
            xmax = float(bnd.findtext("xmax"))
            ymax = float(bnd.findtext("ymax"))

            x, y, bw, bh = voc_to_yolo_bbox((xmin, ymin, xmax, ymax), w, h)
            # clip (nur zur Sicherheit)
            x = max(0, min(1, x)); y = max(0, min(1, y))
            bw = max(0, min(1, bw)); bh = max(0, min(1, bh))

            cid = CLASS2ID[name]
            lines.append(f"{cid} {x:.6f} {y:.6f} {bw:.6f} {bh:.6f}")

        # nur schreiben, wenn es wirklich Labels gibt
        if lines:
            (out_dir / f"{img_path.stem}.txt").write_text("\n".join(lines))
            converted += 1
        else:
            # keine Objekte -> keine .txt (YOLO interpretiert sonst als „hintergrund“)
            converted += 1  # gezählt als verarbeitet, aber ohne Labeldatei

    print(f"✅ konvertiert (Dateien verarbeitet): {converted}, ⚠️ übersprungen: {skipped}")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--xml_dir", required=True, help="Ordner mit VOC-XMLs")
    ap.add_argument("--img_dir", required=True, help="Ordner mit Bildern")
    ap.add_argument("--out_dir", required=True, help="Zielordner für YOLO-TXT")
    args = ap.parse_args()
    convert_dir(args.xml_dir, args.img_dir, args.out_dir)
