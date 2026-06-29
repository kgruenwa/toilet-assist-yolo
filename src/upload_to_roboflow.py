from roboflow import Roboflow
import os
from dotenv import load_dotenv

load_dotenv()
api_key = os.getenv("ROBOFLOW_API_KEY")

rf = Roboflow(api_key=api_key)

workspace = rf.workspace("katharina-toilet-assist")
project = workspace.project("toilet-assist")

split = "train"
image_dir = "data/new_images"

for filename in os.listdir(image_dir):
    if filename.lower().endswith((".jpg", ".jpeg", ".png")):
        filepath = os.path.join(image_dir, filename)
        project.upload(filepath, split=split)
        print(f"✅ Uploaded: {filename}")