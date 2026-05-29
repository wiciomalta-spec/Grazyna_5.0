import sys
import os

try:
    import ensurepip
    ensurepip.bootstrap()
    print("✅ ensurepip OK")
except Exception as e:
    print(f"⚠️ ensurepip failed: {e}")
