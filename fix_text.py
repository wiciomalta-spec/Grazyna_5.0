from pathlib import Path
import re

p = Path(r"E:\Grazyna_5.0\main.py")
code = p.read_text(encoding="utf-8")

# zamień linie bez # na komentarz (heurystyka)
code = re.sub(
    r'^(?!#|def |class |import |from |if |for |while |return |try |except |with ).+:.+$',
    lambda m: "# " + m.group(0),
    code,
    flags=re.MULTILINE
)

p.write_text(code, encoding="utf-8")

print("✅ text converted to comments")
