#!/usr/bin/env bash
# ---------------------------------------------------------------------------- #
# build_docs.sh
#
# Regenerates docs/ from the markdown sources. docs/ is the GitHub Pages site
# and is GENERATED - never edit the HTML by hand.
#
#   ./build_docs.sh
#
# Requires pandoc. On Windows, RStudio ships one; the script finds it.
#
# WHY THIS EXISTS. Until October 2026 the .md and .html sat side by side in
# the same folder, and keeping them in step relied on someone remembering to
# re-run pandoc after every edit. They drifted. Splitting source from output
# and regenerating from one script removes the discipline problem; the CI
# workflow then runs this and fails if the committed docs/ differ.
# ---------------------------------------------------------------------------- #
set -euo pipefail

cd "$(dirname "$0")"

# ---- find pandoc ----------------------------------------------------------- #
if command -v pandoc >/dev/null 2>&1; then
    PANDOC=pandoc
elif [ -x "/c/Program Files/RStudio/resources/app/bin/quarto/bin/tools/pandoc.exe" ]; then
    PANDOC="/c/Program Files/RStudio/resources/app/bin/quarto/bin/tools/pandoc.exe"
else
    echo "pandoc not found. Install it, or add it to PATH." >&2
    exit 1
fi
echo "using: $PANDOC"

SRC="functions/readme"
OUT="docs"
mkdir -p "$OUT"
cp _style.css "$OUT/_style.css" 2>/dev/null || true

render () {   # render <input.md> <output.html> <title>
    "$PANDOC" "$1" -o "$2" \
        --standalone --embed-resources --css="$OUT/_style.css" \
        --toc --toc-depth=3 --mathml \
        --metadata title="$3"
    echo "  -> $2"
}

# ---- the function documentation -------------------------------------------- #
render "$SRC/01_eiod_build_cutoffs.md"   "$OUT/01_eiod_build_cutoffs.html"   "01 - the reference dataset, and exactly how exact it is"
render "$SRC/02_eiod_demogroup.md"       "$OUT/02_eiod_demogroup.html"       "02 - eiod_demogroup: the eight age-sex groups"
render "$SRC/03_eiod_absolute.md"        "$OUT/03_eiod_absolute.html"        "03 - eiod_absolute: Table 3 absolute threshold metrics"
render "$SRC/04_eiod_relative.md"        "$OUT/04_eiod_relative.html"        "04 - eiod_relative: Tables 4a-4g relative benchmarks"
render "$SRC/05_eiod_composites.md"      "$OUT/05_eiod_composites.html"      "05 - eiod_hesd and eiod_hdlei: Tables 5a and 5b"
render "$SRC/06_eiod_infrastructure.md"  "$OUT/06_eiod_infrastructure.html"  "06 - helper, loader, batch wrappers and input QC"

# ---- the repository-level pages -------------------------------------------- #
render "README.md"           "$OUT/readme.html"          "eiod - Intake EIOD metrics for Stata"
render "NEWS.md"             "$OUT/news.html"            "eiod - changelog"

# ---- the landing page ------------------------------------------------------ #
render "docs/index.md" "$OUT/index.html" "eiod - Intake EIOD metrics for Stata"

echo "docs/ rebuilt."
