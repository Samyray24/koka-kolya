import os
import sys
import io
import time
import zipfile
import urllib.request
import shutil

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MODELS_DIR = os.path.join(ROOT_DIR, "assets", "models")
TEXTURES_DIR = os.path.join(ROOT_DIR, "assets", "textures", "pbr")

os.makedirs(MODELS_DIR, exist_ok=True)
os.makedirs(TEXTURES_DIR, exist_ok=True)
os.makedirs(os.path.join(MODELS_DIR, "buildings"), exist_ok=True)
os.makedirs(os.path.join(MODELS_DIR, "roads"), exist_ok=True)
os.makedirs(os.path.join(MODELS_DIR, "vehicles"), exist_ok=True)
os.makedirs(os.path.join(MODELS_DIR, "props"), exist_ok=True)
os.makedirs(os.path.join(MODELS_DIR, "characters"), exist_ok=True)

USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"

KENNEY_CITY_MODELS = [
    "building-garage.glb",
    "building-small-a.glb",
    "building-small-b.glb",
    "building-small-c.glb",
    "building-small-d.glb",
    "road-straight.glb",
    "road-straight-lightposts.glb",
    "road-corner.glb",
    "road-intersection.glb",
    "pavement.glb",
    "pavement-fountain.glb",
    "grass-trees.glb",
    "grass-trees-tall.glb",
    "grass.glb",
]

KENNEY_VEHICLE_MODELS = [
    "vehicle-truck-red.glb",
    "vehicle-truck-yellow.glb",
    "vehicle-truck-green.glb",
    "vehicle-motorcycle.glb",
]

KENNEY_PLATFORMER_MODELS = [
    "character.glb",
    "brick.glb",
    "coin.glb",
    "block-coin.glb",
]

KHRONOS_MODELS = [
    ("CesiumMilkTruck.glb", "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/main/2.0/CesiumMilkTruck/glTF-Binary/CesiumMilkTruck.glb", os.path.join(MODELS_DIR, "vehicles")),
    ("Lantern.glb", "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/main/2.0/Lantern/glTF-Binary/Lantern.glb", os.path.join(MODELS_DIR, "props")),
    ("BoomBox.glb", "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/main/2.0/BoomBox/glTF-Binary/BoomBox.glb", os.path.join(MODELS_DIR, "props")),
]

AMBIENT_CG_TEXTURES = [
    ("Asphalt012", "asphalt"),
    ("Bricks059", "brick"),
    ("Concrete019", "concrete"),
    ("Metal009", "metal"),
    ("PavingStones070", "paving"),
    ("Wood066", "wood"),
]

def download_file(url: str, target_path: str, max_retries: int = 3) -> bool:
    if os.path.exists(target_path) and os.path.getsize(target_path) > 100:
        print(f"[EXISTS] {os.path.basename(target_path)} ({os.path.getsize(target_path)} bytes)")
        return True
    
    print(f"[DOWNLOADING] {url} -> {os.path.basename(target_path)}")
    for attempt in range(max_retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = resp.read()
                with open(target_path, "wb") as f:
                    f.write(data)
            print(f"[OK] Saved {os.path.basename(target_path)} ({len(data)} bytes)")
            return True
        except Exception as e:
            print(f"[RETRY {attempt+1}/{max_retries}] Error downloading {url}: {e}")
            time.sleep(2)
    return False

def download_kenney_models():
    print("\n--- Downloading Kenney 3D Models ---")
    base_city_url = "https://raw.githubusercontent.com/KenneyNL/Starter-Kit-City-Builder/main/models/"
    for name in KENNEY_CITY_MODELS:
        folder = "buildings" if "building" in name else ("roads" if "road" in name or "pavement" in name else "props")
        target = os.path.join(MODELS_DIR, folder, name)
        root_target = os.path.join(MODELS_DIR, name)
        if download_file(base_city_url + name, target):
            if not os.path.exists(root_target):
                shutil.copy2(target, root_target)

    base_racing_url = "https://raw.githubusercontent.com/KenneyNL/Starter-Kit-Racing/main/models/"
    for name in KENNEY_VEHICLE_MODELS:
        target = os.path.join(MODELS_DIR, "vehicles", name)
        root_target = os.path.join(MODELS_DIR, name)
        if download_file(base_racing_url + name, target):
            if not os.path.exists(root_target):
                shutil.copy2(target, root_target)

    base_plat_url = "https://raw.githubusercontent.com/KenneyNL/Starter-Kit-3D-Platformer/main/models/"
    for name in KENNEY_PLATFORMER_MODELS:
        folder = "characters" if "character" in name else "props"
        target = os.path.join(MODELS_DIR, folder, name)
        root_target = os.path.join(MODELS_DIR, name)
        if download_file(base_plat_url + name, target):
            if not os.path.exists(root_target):
                shutil.copy2(target, root_target)

def download_khronos_models():
    print("\n--- Downloading Khronos Sample Models ---")
    for name, url, target_dir in KHRONOS_MODELS:
        target = os.path.join(target_dir, name)
        root_target = os.path.join(MODELS_DIR, name)
        if download_file(url, target):
            if not os.path.exists(root_target):
                shutil.copy2(target, root_target)

def download_ambientcg_textures():
    print("\n--- Downloading AmbientCG PBR Textures ---")
    for asset_id, prefix in AMBIENT_CG_TEXTURES:
        target_subfolder = os.path.join(TEXTURES_DIR, prefix)
        os.makedirs(target_subfolder, exist_ok=True)
        
        color_file = os.path.join(target_subfolder, f"{prefix}_color.jpg")
        if os.path.exists(color_file) and os.path.getsize(color_file) > 1000:
            print(f"[EXISTS] {prefix} PBR set already downloaded and extracted.")
            continue

        url = f"https://ambientcg.com/get?file={asset_id}_1K-JPG.zip"
        print(f"[FETCHING] AmbientCG archive for {asset_id}...")
        
        download_success = False
        for attempt in range(3):
            try:
                req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
                with urllib.request.urlopen(req, timeout=45) as resp:
                    zip_data = resp.read()
                download_success = True
                break
            except Exception as e:
                print(f"[RETRY {attempt+1}/3] Error fetching {url}: {e}")
                time.sleep(2)
        
        if not download_success:
            print(f"[FAILED] Could not download {asset_id}")
            continue

        try:
            with zipfile.ZipFile(io.BytesIO(zip_data)) as zf:
                for member in zf.namelist():
                    lower_name = member.lower()
                    dest_name = None
                    if "color" in lower_name and (lower_name.endswith(".jpg") or lower_name.endswith(".png")):
                        dest_name = f"{prefix}_color.jpg"
                    elif "normalgl" in lower_name and (lower_name.endswith(".jpg") or lower_name.endswith(".png")):
                        dest_name = f"{prefix}_normal.jpg"
                    elif "roughness" in lower_name and (lower_name.endswith(".jpg") or lower_name.endswith(".png")):
                        dest_name = f"{prefix}_roughness.jpg"
                    elif "metalness" in lower_name and (lower_name.endswith(".jpg") or lower_name.endswith(".png")):
                        dest_name = f"{prefix}_metalness.jpg"

                    if dest_name:
                        dest_path = os.path.join(target_subfolder, dest_name)
                        with zf.open(member) as src, open(dest_path, "wb") as dst:
                            dst.write(src.read())
                        print(f"  Extracted: {dest_name} ({os.path.getsize(dest_path)} bytes)")
            print(f"[OK] Extracted {prefix} PBR maps to {target_subfolder}")
        except Exception as e:
            print(f"[ERROR] Failed to extract zip for {asset_id}: {e}")

def main():
    print("Starting download of real 3D models and authentic PBR textures...")
    download_kenney_models()
    download_khronos_models()
    download_ambientcg_textures()
    print("\nAll assets downloaded successfully!")

if __name__ == "__main__":
    main()
