"""Extract report generator from chat transcript, run it, and export PDF."""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TRANSCRIPT = Path(
    r"C:\Users\dell\.cursor\projects\c-Users-dell-StudioProjects-talentmesh"
    r"\agent-transcripts\3822b266-3d88-43a9-8497-451f6db0ce71"
    r"\3822b266-3d88-43a9-8497-451f6db0ce71.jsonl"
)
GENERATOR = ROOT / "scripts" / "generate_talentmesh_report.py"
DOCS = ROOT / "docs"


def extract_script() -> str:
    line = TRANSCRIPT.read_text(encoding="utf-8").splitlines()[0]
    data = json.loads(line)
    text = data["message"]["content"][0]["text"]
    text = re.sub(r"^<user_query>\n?", "", text)
    text = re.sub(r"\n\nclaude burda kaldı.*$", "", text, flags=re.DOTALL)

    footer = """# ── SAVE ─────────────────────────────────────────────────────────────────────
from pathlib import Path
from docx2pdf import convert

base_dir = Path(__file__).resolve().parent.parent / "docs"
base_dir.mkdir(parents=True, exist_ok=True)
output_path = str(base_dir / "TalentMesh_SE_Project_Report.docx")
doc.save(output_path)
print("Saved:", output_path)

pdf_path = str(base_dir / "TalentMesh_SE_Project_Report.pdf")
print("Converting to PDF via Microsoft Word...")
convert(output_path, pdf_path)
print("Saved PDF:", pdf_path)
"""

    text = re.sub(
        r'output_path = "/mnt/user-data/outputs/TalentMesh_SE_Project_Report\.docx"\s*'
        r"doc\.save\(output_path\)\s*"
        r'print\(f"Saved: \{output_path\}"\)\s*$',
        lambda _m: footer.strip(),
        text,
        flags=re.DOTALL,
    )
    return text


def main() -> int:
    script = extract_script()
    GENERATOR.parent.mkdir(parents=True, exist_ok=True)
    GENERATOR.write_text(script, encoding="utf-8")
    print(f"Wrote {GENERATOR} ({len(script)} chars)")

    result = subprocess.run([sys.executable, str(GENERATOR)], check=False)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
