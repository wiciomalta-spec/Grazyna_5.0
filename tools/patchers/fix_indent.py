from pathlib import Path
import re

p = Path(r"E:\Grazyna_5.0\main.py")
code = p.read_text(encoding="utf-8")

# usuń rozwalone messagebox blokowe wywołania
code = re.sub(
    r'# messagebox\.show\w+\([\s\S]*?\)',
    'print("[GUI REMOVED]")',
    code
)

# usuń wiszące linie typu "    \"text\""
code = re.sub(r'^\s*".*"\s*,?\s*$', '', code, flags=re.MULTILINE)

p.write_text(code, encoding="utf-8")

print("✅ indentation fixed")
