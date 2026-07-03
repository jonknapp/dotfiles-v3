{ inputs, ... }:
{
  flake.modules.homeManager.to-markdown =
    { pkgs, ... }:
    let
      tesseract = pkgs.tesseract.override { enableLanguages = [ "eng" ]; };

      pythonEnv = pkgs.python3.withPackages (ps: [ ps.pymupdf4llm ]);

      to-markdown = pkgs.writeShellApplication {
        name = "to-markdown";
        runtimeInputs = [
          pythonEnv
          tesseract
        ];
        text = ''
          # Usage: to-markdown [--accessible] <file> [output.md]
          #
          # Converts a file to a markdown document containing the parsed text content.
          # Uses pymupdf4llm for PDF parsing, with Tesseract OCR for scanned/image PDFs.
          #
          # --accessible  Also write a searchable PDF alongside the markdown. For
          #               image-only pages an invisible text layer is overlaid on top
          #               of the original scan (a "sandwich PDF"), making the file
          #               selectable and accessible without altering its appearance.

          accessible=0
          if [ "''${1:-}" = "--accessible" ]; then
            accessible=1
            shift
          fi

          if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
            printf "Usage: to-markdown [--accessible] <file> [output.md]\n" >&2
            exit 1
          fi

          input_file="$1"

          if [ ! -f "$input_file" ]; then
            printf "Error: file not found: %s\n" "$input_file" >&2
            exit 1
          fi

          # Default output path: replace extension with .md, or append .md
          if [ "$#" -eq 2 ]; then
            output_file="$2"
          else
            output_file="''${input_file%.*}.md"
            if [ "$output_file" = "$input_file" ]; then
              output_file="$input_file.md"
            fi
          fi

          # Derive the accessible PDF path: same stem, suffix -accessible.pdf
          accessible_file="''${output_file%.md}-accessible.pdf"

          # Point pymupdf4llm's Tesseract integration at the Nix-built tessdata
          export TESSDATA_PREFIX="${tesseract}/share/tessdata"

          python3 - "$input_file" "$output_file" "$accessible_file" "$accessible" <<'EOF'
import sys
import pathlib
import pymupdf
import pymupdf4llm

input_path    = pathlib.Path(sys.argv[1])
output_path   = pathlib.Path(sys.argv[2])
acc_path      = pathlib.Path(sys.argv[3])
want_acc      = sys.argv[4] == "1"

doc = pymupdf.open(str(input_path))

# get_textpage_ocr() returns a TextPage — it does NOT mutate the page.
# pymupdf4llm v0.3.4 has no textpage= or force_ocr= parameter, so we
# cannot inject the OCR TextPage into to_markdown(). Instead:
#   - for pages with native text, let to_markdown() handle them normally
#     by passing a single-page document slice
#   - for image-only pages, call get_textpage_ocr(dpi=300, full=True),
#     extract the text from that TextPage directly, and wrap it in plain
#     markdown ourselves
#
# When --accessible is requested we also write a "sandwich PDF": for each
# image-only page the OCR word bounding boxes are used to place invisible
# text (render_mode=3) behind the original scan, producing a file that is
# visually identical but fully selectable/searchable.

parts = []
for pno in range(doc.page_count):
    page = doc[pno]
    native_text = page.get_text().strip()

    if native_text:
        # Native text layer present: use to_markdown for layout/table support
        single = pymupdf.open()
        single.insert_pdf(doc, from_page=pno, to_page=pno)
        parts.append(pymupdf4llm.to_markdown(single))
        single.close()
    else:
        # Image-only page: OCR via Tesseract at 300 DPI and use the
        # returned TextPage directly (discarding it would produce no text)
        print(f"Page {pno + 1}: no native text, running Tesseract OCR...", file=sys.stderr)
        tp = page.get_textpage_ocr(language="eng", dpi=300, full=True)
        text = page.get_text(textpage=tp).strip()
        if text:
            parts.append(text + "\n\n")
        else:
            print(f"Page {pno + 1}: OCR produced no text", file=sys.stderr)

        if want_acc:
            # Overlay invisible text at each word's position so the PDF
            # becomes selectable without changing its visual appearance.
            # render_mode=3: no fill, no stroke (PDF spec text render mode 3)
            # overlay=False: text layer sits behind the image content
            words = page.get_text("words", textpage=tp)
            for (x0, y0, x1, y1, word, *_) in words:
                page.insert_text(
                    pymupdf.Point(x0, y1),  # insert_text uses the baseline point
                    word,
                    fontsize=(y1 - y0) * 0.8,
                    render_mode=3,
                    overlay=False,
                )

md = "".join(parts)
output_path.write_text(md, encoding="utf-8")
print(f"Written: {output_path}")

if want_acc:
    doc.save(str(acc_path), garbage=4, deflate=True)
    print(f"Written: {acc_path}")
EOF
        '';
      };
    in
    {
      home.packages = [ to-markdown ];
    };
}
