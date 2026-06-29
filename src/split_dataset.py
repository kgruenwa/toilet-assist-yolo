from pathlib import Path
import random
import shutil

# Quelle: hier liegen alte + neue gelabelte Daten zusammen
SOURCE_DIR = Path("data/all_labeled")

# Zielordner
TRAIN_IMAGE_DIR = Path("data/images/train")
VAL_IMAGE_DIR = Path("data/images/val")
TRAIN_LABEL_DIR = Path("data/labels/train")
VAL_LABEL_DIR = Path("data/labels/val")

VAL_RATIO = 0.2
IMAGE_EXTENSIONS = [".jpg", ".jpeg", ".png"]

for directory in [TRAIN_IMAGE_DIR, VAL_IMAGE_DIR, TRAIN_LABEL_DIR, VAL_LABEL_DIR]:
    directory.mkdir(parents=True, exist_ok=True)

images = [
    path for path in SOURCE_DIR.iterdir()
    if path.suffix.lower() in IMAGE_EXTENSIONS
]

labeled_images = []

for image_path in images:
    label_path = SOURCE_DIR / f"{image_path.stem}.txt"

    if label_path.exists():
        labeled_images.append(image_path)
    else:
        print(f"⚠️ Kein Label gefunden: {image_path.name}")

random.seed(42)
random.shuffle(labeled_images)

val_count = max(1, int(len(labeled_images) * VAL_RATIO))
val_images = set(labeled_images[:val_count])
train_images = set(labeled_images[val_count:])

def copy_pair(image_path: Path, image_target_dir: Path, label_target_dir: Path):
    label_path = SOURCE_DIR / f"{image_path.stem}.txt"

    shutil.copy2(image_path, image_target_dir / image_path.name)
    shutil.copy2(label_path, label_target_dir / label_path.name)

for image_path in train_images:
    copy_pair(image_path, TRAIN_IMAGE_DIR, TRAIN_LABEL_DIR)

for image_path in val_images:
    copy_pair(image_path, VAL_IMAGE_DIR, VAL_LABEL_DIR)

print("Fertig.")
print(f"Quelle: {SOURCE_DIR}")
print(f"Train: {len(train_images)} Bilder")
print(f"Val: {len(val_images)} Bilder")