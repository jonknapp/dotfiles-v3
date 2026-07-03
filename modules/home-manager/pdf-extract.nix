{ inputs, ... }:
{
  flake.modules.homeManager.pdf-extract =
    { pkgs, ... }:
    let
      # Use tessdata_best models (float LSTM) instead of nixpkgs' default
      # standard tessdata: ~1-3% better character accuracy on degraded scans
      # at the cost of slower recognition. osd.traineddata is required by
      # ocrmypdf's --rotate-pages (orientation & script detection).
      tessdataBest = {
        eng = pkgs.fetchurl {
          url = "https://github.com/tesseract-ocr/tessdata_best/raw/4.1.0/eng.traineddata";
          hash = "sha256-goCu0Hgv4nJXpo6hD+fvMkyg+Nhb0v0UXRwrVgvLZro=";
        };
        osd = pkgs.fetchurl {
          url = "https://github.com/tesseract-ocr/tessdata_best/raw/4.1.0/osd.traineddata";
          hash = "sha256-nPXVdvzEdWTxEmWEHlyoOQAefm84/396rPRtFalrAP8=";
        };
      };

      # ocrmypdf bundles tesseract, ghostscript, unpaper, pngquant and jbig2enc
      # via hardcoded store paths; the tesseract wrapper sets TESSDATA_PREFIX
      # itself. Provide only the tessdata_best models to keep the closure small.
      # (pkgs.ocrmypdf is toPythonApplication python3Packages.ocrmypdf, so the
      # tesseract argument must be overridden at the python-packages level.)
      ocrmypdf = pkgs.python3Packages.toPythonApplication (
        pkgs.python3Packages.ocrmypdf.override {
          tesseract = pkgs.tesseract5.override {
            tessdata = [
              tessdataBest.eng
              tessdataBest.osd
            ];
          };
        }
      );

      pythonEnv = pkgs.python3.withPackages (ps: [ ps.pymupdf4llm ]);

      pdf-extract = pkgs.writeShellApplication {
        name = "pdf-extract";
        runtimeInputs = [
          pythonEnv
          ocrmypdf
        ];
        text = ''
          # Usage: pdf-extract <file> [output.md]
          #
          # Extracts the content of a PDF, always producing two outputs:
          #   <output>.md              - structured markdown of the text content
          #   <output>-accessible.pdf  - searchable/accessible "sandwich PDF"
          #
          # Pipeline: ocrmypdf preprocesses scanned pages (deskew, clean,
          # rotation correction) and runs Tesseract, overlaying an invisible
          # text layer on the original scan. Pages that already contain text
          # are skipped (--skip-text), so digital PDFs pass through unchanged.
          # pymupdf4llm then converts the now-searchable PDF to markdown.

          if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
            printf "Usage: pdf-extract <file> [output.md]\n" >&2
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

          accessible_pdf="''${output_file%.md}-accessible.pdf"

          # Preprocess + OCR. --skip-text leaves pages with native text
          # untouched, so digital PDFs pass through unchanged.
          ocrmypdf \
            --skip-text \
            --deskew \
            --clean \
            --rotate-pages \
            --language eng \
            "$input_file" "$accessible_pdf"

          # The OCR'd PDF now has a native text layer on every page, so
          # pymupdf4llm can convert it directly with full layout analysis.
          python3 - "$accessible_pdf" "$output_file" <<'EOF'
          import sys
          import pathlib
          import pymupdf4llm

          accessible_pdf = sys.argv[1]
          output_path = pathlib.Path(sys.argv[2])

          md = pymupdf4llm.to_markdown(accessible_pdf)
          output_path.write_text(md, encoding="utf-8")
          print(f"Written: {output_path}")
          EOF

          printf "Written: %s\n" "$accessible_pdf"
        '';
      };
    in
    {
      home.packages = [ pdf-extract ];
    };
}
