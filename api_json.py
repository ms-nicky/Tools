import requests
import base64
import json
import time
import hashlib
import os
from datetime import datetime

# ================= CONFIG =================
API_URL = "https://nekobot.xyz/api/image?type=ass"

# KEY JSON YANG BERISI URL IMAGE
IMAGE_KEY = "message"

# Repo penyimpan URL (JSON only)
GITHUB_REPO = "ms-nicky/anime-db"
JSON_PATH = "nsfw/ass.json"

# Upload server
UPLOAD_API = "https://upload1.nickystore.biz.id/api/upload"

TOKEN_URL = "https://pastebin.com/raw/GJsjAp1r"

INTERVAL = 0
# =========================================

# === LOCAL SEEN OTOMATIS IKUT JSON_PATH ===
BASE_PATH, _ = os.path.splitext(JSON_PATH)
LOCAL_SEEN = BASE_PATH + ".seen.json"

# pastikan folder ada
os.makedirs(os.path.dirname(LOCAL_SEEN), exist_ok=True)


def log(msg):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}", flush=True)


def load_seen():
    try:
        with open(LOCAL_SEEN, "r") as f:
            return json.load(f)
    except:
        return {}


def save_seen(data):
    with open(LOCAL_SEEN, "w") as f:
        json.dump(data, f, indent=2)


def gh_headers(token):
    return {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json"
    }


def fetch_image_url():
    r = requests.get(API_URL, timeout=15)
    r.raise_for_status()

    data = r.json()
    if IMAGE_KEY not in data:
        raise KeyError(f"Key '{IMAGE_KEY}' tidak ditemukan di response")

    return data[IMAGE_KEY]


def gh_get_json(headers):
    api = f"https://api.github.com/repos/{GITHUB_REPO}/contents/{JSON_PATH}"
    r = requests.get(api, headers=headers)

    if r.status_code == 200:
        raw = base64.b64decode(r.json()["content"]).decode()
        return json.loads(raw), r.json()["sha"]

    return [], None


def gh_put_json(data, headers, message):
    api = f"https://api.github.com/repos/{GITHUB_REPO}/contents/{JSON_PATH}"

    payload = {
        "message": message,
        "content": base64.b64encode(
            json.dumps(data, indent=2).encode()
        ).decode()
    }

    r = requests.get(api, headers=headers)
    if r.status_code == 200:
        payload["sha"] = r.json()["sha"]

    r = requests.put(api, headers=headers, json=payload)
    r.raise_for_status()


def download_img(url):
    r = requests.get(url, timeout=20)
    r.raise_for_status()
    return r.content


def upload_to_server(img_bytes, filename):
    files = {
        "file": (filename, img_bytes)
    }
    r = requests.post(UPLOAD_API, files=files, timeout=30)
    r.raise_for_status()

    data = r.json()
    if "url" not in data:
        raise ValueError("Response upload tidak ada field 'url'")

    return data["url"]


def main():
    log("START")

    seen = load_seen()

    token = requests.get(TOKEN_URL, timeout=10).text.strip()
    headers = gh_headers(token)

    # 1️⃣ ambil URL image dari API
    img_url = fetch_image_url()
    log(f"Image URL: {img_url}")

    if img_url in seen:
        log("Duplicate URL, skip")
        return

    # 2️⃣ download image
    img = download_img(img_url)
    log("Download OK")

    filename = hashlib.md5(img_url.encode()).hexdigest()[:10] + ".jpg"

    # 3️⃣ upload ke server
    uploaded_url = upload_to_server(img, filename)
    log(f"Uploaded: {uploaded_url}")

    # 4️⃣ update JSON di GitHub
    content, _ = gh_get_json(headers)
    content.append({
        "url": uploaded_url
    })

    gh_put_json(
        content,
        headers,
        "add meme image"
    )

    # 5️⃣ mark seen (pakai URL asli API)
    seen[img_url] = True
    save_seen(seen)

    log("DONE")


if __name__ == "__main__":
    while True:
        try:
            main()
        except Exception as e:
            log(f"ERROR: {e}")

        time.sleep(INTERVAL)