from roboflow import Roboflow
import os
from dotenv import load_dotenv

# .env laden
load_dotenv()
api_key = os.getenv("ROBOFLOW_API_KEY")

# Initialisieren
rf = Roboflow(api_key=api_key)

# Deinen Workspace & Projekt eintragen (z. B. von roboflow.com/<workspace>/<project>)
workspace = rf.workspace("katharina-toilet-assist")
project = workspace.project("toilet-assist")

# Optional: Welcher Datensatz-Split
split = "train"

# Alle Bilder im Ordner hochladen
image_dir = "data/images/train"

for filename in os.listdir(image_dir):
    if filename.lower().endswith((".jpg", ".jpeg", ".png")):
        filepath = os.path.join(image_dir, filename)
        upload = project.upload(filepath, split=split)
        print(f"✅ Uploaded: {filename}")
