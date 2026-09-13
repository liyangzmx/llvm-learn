#!/usr/bin/env python3
"""Validate raw Vision pages and assemble lossless per-PDF text plus provenance."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
manifest_file = ROOT / "ocr/manifest.json"
previous_sources = {}
if manifest_file.exists():
    previous_sources = {item["pdf"]: item for item in json.loads(manifest_file.read_text())["sources"]}
SOURCES = {
    "insider-compiler-ch1": ("insider-compiler-ch1", 14),
    "insider-compiler-ch2-ch3": ("insider-compiler-ch2-ch3", 50),
    "insider-compiler-ch4": ("insider-compiler-ch4", 25),
    "insider-compiler-ch5-ch6": ("insider-compiler-ch5-ch6", 37),
    "insider-compiler-ch7-ch10": ("insider-compiler-ch7-ch10", 108),
    "insider-compiler-ch11-ch13": ("insider-compiler-ch11-ch13", 130),
    "insider-compiler-ch14-end": ("insider-compiler-ch14-end", 52),
}
CHAPTERS = {
    "1": {"source": "insider-compiler-ch1.pdf", "pdf_pages": [1, 14], "book_pages": [2, 15], "first_book_page_inferred": True},
    "2": {"source": "insider-compiler-ch2-ch3.pdf", "pdf_pages": [1, 9], "book_pages": [16, 24]},
    "3": {"source": "insider-compiler-ch2-ch3.pdf", "pdf_pages": [10, 50], "book_pages": [25, 65]},
    "4": {"source": "insider-compiler-ch4.pdf", "pdf_pages": [1, 25], "book_pages": [66, 90]},
    "5": {"source": "insider-compiler-ch5-ch6.pdf", "pdf_pages": [1, 16], "book_pages": [91, 106]},
    "6": {"source": "insider-compiler-ch5-ch6.pdf", "pdf_pages": [17, 37], "book_pages": [107, 127]},
    "7": {"source": "insider-compiler-ch7-ch10.pdf", "pdf_pages": [1, 17], "book_pages": [128, 144]},
    "8": {"source": "insider-compiler-ch7-ch10.pdf", "pdf_pages": [21, 26], "book_pages": [148, 153]},
    "9": {"source": "insider-compiler-ch7-ch10.pdf", "pdf_pages": [27, 80], "book_pages": [154, 207]},
    "10": {"source": "insider-compiler-ch7-ch10.pdf", "pdf_pages": [81, 108], "book_pages": [208, 235]},
    "11": {"source": "insider-compiler-ch11-ch13.pdf", "pdf_pages": [1, 31], "book_pages": [236, 266], "first_book_page_inferred": True},
    "12": {"source": "insider-compiler-ch11-ch13.pdf", "pdf_pages": [32, 48], "book_pages": [267, 283], "first_book_page_inferred": True},
    "13": {"source": "insider-compiler-ch11-ch13.pdf", "pdf_pages": [50, 130], "book_pages": [286, 366], "first_book_page_inferred": True},
    "14": {"source": "insider-compiler-ch14-end.pdf", "pdf_pages": [2, 25], "book_pages": [368, 391], "first_book_page_inferred": True},
    "15": {"source": "insider-compiler-ch14-end.pdf", "pdf_pages": [26, 48], "book_pages": [392, 414], "first_book_page_inferred": True},
}
SUPPLEMENTS = {
    "part2": {"file": "insider-compiler-part2.md", "source": "insider-compiler-ch7-ch10.pdf",
              "pdf_pages": [18, 20], "book_pages": [145, 147], "first_book_page_inferred": True,
              "note": "Part 2 divider/introduction; p145 has no printed page number."},
    "part3": {"file": "insider-compiler-part3.md", "source": "insider-compiler-ch11-ch13.pdf",
              "pdf_pages": [49, 49], "book_pages": [285, 285], "first_book_page_inferred": True,
              "note": "Unnumbered Part 3 divider/introduction; 285 inferred backward from chapter 13 (286 inferred, 287 printed). Book page 284 is not represented under this inference; whether it was blank cannot be confirmed from the scan."},
    "part4": {"file": "insider-compiler-part4.md", "source": "insider-compiler-ch14-end.pdf",
              "pdf_pages": [1, 1], "book_pages": [367, 367], "first_book_page_inferred": True,
              "note": "Unnumbered Part 4 divider/introduction; inferred from preceding p366 and following printed p369."},
    "appendix": {"file": "insider-compiler-appendix.md", "source": "insider-compiler-ch14-end.pdf",
                 "pdf_pages": [49, 52], "book_pages": [415, 418], "first_book_page_inferred": True,
                 "numbering_prefix": "A", "expected_listings": 1, "expected_figures": 0,
                 "expected_tables": 0, "expected_footnotes": 1,
                 "note": "Appendix: Other dialects. First page unnumbered; p415 inferred from adjacent printed pages. Final supplied book page is 418."},
}

CH1_REPLACEMENT = {
    "old_sha256_pdf": "4951c568a1ff637c6e05dfde1b50b9a24e35aece1d8d63aaa8a0621159dc7661",
    "new_sha256_pdf": "40e24cbf10d5f9303bdcfe8ca43dd7305105900c04a844e3dfd3baf1c7ff227c",
    "old_manifest": "issues/evidence/ch1/manifest-before-ch1.json",
    "old_content_retained_as": "pdf/insider-compiler-ch2-ch3.pdf",
    "note": "User replaced the duplicate chapters 2–3 scan with the actual 14-page chapter 1 scan on 2026-09-13. Old OCR remains under insider-compiler-ch2-ch3.",
}


def write_if_changed(path, text):
    """Keep existing files untouched when assembling identical content."""
    if not path.exists() or path.read_text() != text:
        path.write_text(text)


manifest = {"engine": "Apple Vision VNRecognizeTextRequest", "recognition_level": "accurate",
            "languages": ["zh-Hans", "en-US"], "language_correction": False,
            "render_scale": 3, "text_separator": "\\f\\n", "sources": [], "chapters": CHAPTERS,
            "supplements": SUPPLEMENTS}
for source, (canonical, count) in SOURCES.items():
    pdf = ROOT / "pdf" / (source + ".pdf")
    canonical_pdf = ROOT / "pdf" / (canonical + ".pdf")
    sha = hashlib.sha256(pdf.read_bytes()).hexdigest()
    assert sha == hashlib.sha256(canonical_pdf.read_bytes()).hexdigest(), source
    previous = previous_sources.get("pdf/" + source + ".pdf")
    if previous and previous["sha256_pdf"] != sha:
        # Allow only the recorded, explicitly requested chapter 1 replacement.
        assert source == "insider-compiler-ch1", f"Source PDF changed: {source}"
        assert previous["sha256_pdf"] == CH1_REPLACEMENT["old_sha256_pdf"]
        assert sha == CH1_REPLACEMENT["new_sha256_pdf"]
        archived = json.loads((ROOT / CH1_REPLACEMENT["old_manifest"]).read_text())
        assert previous == next(item for item in archived["sources"] if item["pdf"] == previous["pdf"])
        assert hashlib.sha256((ROOT / CH1_REPLACEMENT["old_content_retained_as"]).read_bytes()).hexdigest() == previous["sha256_pdf"]
        assert (ROOT / previous["aggregate_text"]).read_bytes() == (ROOT / "ocr/insider-compiler-ch2-ch3.txt").read_bytes()
        previous = None  # The new scan has its own OCR pages; keep all other guards.
    pages = []
    page_meta = []
    for n in range(1, count + 1):
        stem = ROOT / "ocr" / canonical / f"page-{n:03}"
        data = json.loads(stem.with_suffix(".json").read_text())
        raw = stem.with_suffix(".txt").read_text()
        assert data["pdf_page"] == n and data["total_pages"] == count
        assert data["source"] == canonical + ".pdf"
        assert raw == "\n".join(line["text"] for line in data["lines"]) + "\n"
        assert data["lines"], (source, n)
        pages.append(raw)
        page_meta.append({"pdf_page": n, "lines": len(data["lines"]), "characters": len(raw),
                          "sha256_text": hashlib.sha256(raw.encode()).hexdigest()})
        if previous:
            assert previous["pages"][n - 1]["sha256_text"] == page_meta[-1]["sha256_text"], \
                f"Raw OCR text changed: {source}, page {n}"
    write_if_changed(ROOT / "ocr" / (source + ".txt"), "\f\n".join(pages))
    entry = {"pdf": "pdf/" + source + ".pdf", "sha256_pdf": sha, "page_count": count,
             "raw_pages": "ocr/" + canonical, "aggregate_text": "ocr/" + source + ".txt",
             "pages": page_meta}
    if source != canonical:
        entry["duplicate_of"] = "pdf/" + canonical + ".pdf"
        entry["note"] = "Filename says chapter 1, but identical bytes contain chapters 2–3; chapter 1 is missing."
    if source == "insider-compiler-ch1":
        entry["replacement_history"] = CH1_REPLACEMENT
    manifest["sources"].append(entry)
write_if_changed(ROOT / "ocr" / "manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
unique_pages = sum(dict((canonical, count) for canonical, count in SOURCES.values()).values())
source_pages = sum(count for canonical, count in SOURCES.values())
print(f"Validated {unique_pages} unique pages / {source_pages} source-file pages; "
      f"assembled {len(SOURCES)} raw text files.")
