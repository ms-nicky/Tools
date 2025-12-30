import os
import random
import string
import time

BASE_DIR = "/24"          # folder target
INTERVAL = 1              # detik (atur sesuai kebutuhan)

os.makedirs(BASE_DIR, exist_ok=True)

def random_name(length=8):
    return ''.join(random.choices(string.ascii_lowercase + string.digits, k=length))

while True:
    filename = random_name() + ".txt"
    path = os.path.join(BASE_DIR, filename)

    # buat file
    with open(path, "w") as f:
        f.write(random_name(32))

    # hapus file
    os.remove(path)

    time.sleep(INTERVAL)
