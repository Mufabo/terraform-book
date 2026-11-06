#!/usr/bin/env bash
# Builds the book as an EPUB.
# usage: epub/build.sh [OUTPUT] [VERSION]
# Env: REPO_URL (base for relative links, default: this repo's main branch)
set -euo pipefail
cd "$(dirname "$0")/.."

OUTPUT="${1:-terraform-on-google-cloud.epub}"
VERSION="${2:-dev}"
REPO_URL="${REPO_URL:-https://github.com/Mufabo/terraform-book/blob/main}"

pandoc epub/metadata.yaml book/[0-9]*.md book/appendix-*.md \
  --from=markdown+smart \
  --to=epub3 \
  --output="$OUTPUT" \
  --toc --toc-depth=2 \
  --split-level=1 \
  --lua-filter=epub/links.lua \
  --metadata=repo_url:"$REPO_URL" \
  --metadata=date:"$(date -u +%Y-%m-%d)" \
  --metadata=version:"$VERSION" \
  --resource-path=book

echo "Built $OUTPUT ($VERSION)"
