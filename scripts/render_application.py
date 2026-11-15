"""Render an application markdown file to A4 HTML and PDF (local, no external deps)."""
import html
import re
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

CSS = """
*{box-sizing:border-box}
body{margin:0;background:#eee;color:#111;font-family:"Microsoft YaHei","PingFang SC",sans-serif}
article{background:#fff;width:210mm;min-height:297mm;padding:14mm 15mm;font-size:10.5pt;line-height:1.5}
h1{font-size:17pt;margin:0 0 10px}
h2{font-size:12pt;margin:14px 0 6px}
p{margin:0 0 7px}
ul,ol{margin:0 0 8px;padding-left:20px}
li{margin:0 0 4px}
table{border-collapse:collapse;width:100%;margin:6px 0 10px;font-size:9.5pt}
th,td{border:1px solid #999;padding:3px 5px;text-align:left;vertical-align:top}
th{background:#f0f0f0}
code{font-family:Consolas,monospace;font-size:9pt;background:#f4f4f4;padding:0 2px}
a{color:#064b85;text-decoration:none}
@page{size:A4;margin:0}
@media print{body{background:#fff}article{width:auto;min-height:0;padding:0}}
"""


def inline(text: str) -> str:
    text = html.escape(text, quote=False)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', text)
    return text


def convert(md: str) -> str:
    lines = md.splitlines()
    out, para, i = [], [], 0
    while i < len(lines):
        line = lines[i]
        if line.startswith("|"):
            block = []
            while i < len(lines) and lines[i].startswith("|"):
                block.append(lines[i])
                i += 1
            rows = [[c.strip() for c in r.strip().strip("|").split("|")] for r in block]
            rows = [r for r in rows if not all(set(c) <= set("-: ") for c in r)]
            out.append("<table>")
            for n, row in enumerate(rows):
                tag = "th" if n == 0 else "td"
                out.append("<tr>" + "".join(f"<{tag}>{inline(c)}</{tag}>" for c in row) + "</tr>")
            out.append("</table>")
            continue
        if re.match(r"^\d+\.\s", line):
            items = []
            while i < len(lines) and re.match(r"^\d+\.\s", lines[i]):
                items.append(re.sub(r"^\d+\.\s", "", lines[i]))
                i += 1
            out.append("<ol>" + "".join(f"<li>{inline(x)}</li>" for x in items) + "</ol>")
            continue
        if line.startswith("- "):
            items = []
            while i < len(lines) and lines[i].startswith("- "):
                items.append(lines[i][2:])
                i += 1
            out.append("<ul>" + "".join(f"<li>{inline(x)}</li>" for x in items) + "</ul>")
            continue
        if line.startswith("# "):
            out.append(f"<h1>{inline(line[2:])}</h1>")
        elif line.startswith("## "):
            out.append(f"<h2>{inline(line[3:])}</h2>")
        elif line.strip():
            para.append(line)
        else:
            if para:
                out.append("<p>" + "<br>".join(inline(x.rstrip()) for x in para) + "</p>")
                para = []
        i += 1
    if para:
        out.append("<p>" + "<br>".join(inline(x.rstrip()) for x in para) + "</p>")
    body = "\n".join(out)
    return f'<!doctype html><html lang="zh-CN"><meta charset="UTF-8"><title>RootCover 项目申报书</title><style>{CSS}</style><article>{body}</article></html>'


def main() -> None:
    src = Path(sys.argv[1])
    html_path = Path(sys.argv[2])
    pdf_path = Path(sys.argv[3])
    html_path.write_text(convert(src.read_text(encoding="utf-8")), encoding="utf-8")
    with sync_playwright() as p:
        try:
            browser = p.chromium.launch(headless=True)
        except Exception:
            browser = None
            for channel in ("chrome", "msedge"):
                try:
                    browser = p.chromium.launch(headless=True, channel=channel)
                    break
                except Exception:
                    continue
            if browser is None:
                raise
        page = browser.new_page()
        page.goto(html_path.resolve().as_uri())
        page.pdf(path=str(pdf_path), format="A4", print_background=True,
                 margin={"top": "14mm", "bottom": "14mm", "left": "15mm", "right": "15mm"})
        browser.close()
    print(f"html={html_path} pdf={pdf_path}")


if __name__ == "__main__":
    main()
