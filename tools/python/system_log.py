import datetime
import os

LOG_PATH = os.path.join(os.path.dirname(__file__), "data", "logs", "system.log")

def log(msg):
    timestamp = datetime.datetime.now().strftime("[%Y-%m-%d %H:%M:%S]")
    with open(LOG_PATH, "a", encoding="utf-8") as f:
        f.write(f"{timestamp} {msg}\n")
