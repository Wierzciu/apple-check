#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

SRC="AppIcon.svg"
if [[ ! -f "$SRC" ]]; then
  echo "Missing $SRC. Place your source SVG as AppIcon.svg." 1>&2
  exit 1
fi

# Pick an available renderer: magick, convert, or rsvg-convert
TOOL=""
if command -v magick >/dev/null 2>&1; then
  TOOL="magick"
elif command -v convert >/dev/null 2>&1; then
  TOOL="convert"
elif command -v rsvg-convert >/dev/null 2>&1; then
  TOOL="rsvg-convert"
else
  cat <<EOF 1>&2
No SVG renderer found.
Please install one of:
  - ImageMagick (brew install imagemagick)
  - librsvg (brew install librsvg)
Then re-run this script.
EOF
  exit 2
fi

BG_COLOR="${BG_COLOR:-white}"
# Flatten all icons by default to avoid alpha-channel errors in Xcode/App Store
FLATTEN_ALL="${FLATTEN_ALL:-true}"

render() {
  local px="$1"; shift
  local out="$1"; shift
  case "$TOOL" in
    magick)
      magick -background none "$SRC" -resize "${px}x${px}" -strip -colorspace sRGB "$out"
      ;;
    convert)
      convert -background none "$SRC" -resize "${px}x${px}" -strip -colorspace sRGB "$out"
      ;;
    rsvg-convert)
      rsvg-convert -w "$px" -h "$px" "$SRC" -o "$out"
      ;;
  esac
}

# Render without alpha by compositing onto a solid background (default white)
render_flat() {
  local px="$1"; shift
  local out="$1"; shift
  case "$TOOL" in
    magick)
      magick -size "${px}x${px}" canvas:"${BG_COLOR}" "$SRC" -resize "${px}x${px}" -gravity center -compose over -composite -alpha off -strip -colorspace sRGB "$out"
      ;;
    convert)
      convert -size "${px}x${px}" xc:"${BG_COLOR}" "$SRC" -resize "${px}x${px}" -gravity center -compose over -composite -alpha off -strip -colorspace sRGB "$out"
      ;;
    rsvg-convert)
      tmp="$(mktemp -t appicon.XXXXXX.png)"
      rsvg-convert -w "$px" -h "$px" "$SRC" -o "$tmp"
      if command -v magick >/dev/null 2>&1; then
        magick -size "${px}x${px}" canvas:"${BG_COLOR}" "$tmp" -gravity center -compose over -composite -alpha off -strip -colorspace sRGB "$out"
      elif command -v convert >/dev/null 2>&1; then
        convert -size "${px}x${px}" xc:"${BG_COLOR}" "$tmp" -gravity center -compose over -composite -alpha off -strip -colorspace sRGB "$out"
      else
        mv "$tmp" "$out"
      fi
      rm -f "$tmp" 2>/dev/null || true
      ;;
  esac
}

echo "Generating iPhone icons..."
if [[ "$FLATTEN_ALL" == "true" ]]; then
  render_flat 40  icon-20@2x.png
  render_flat 60  icon-20@3x.png
  render_flat 58  icon-29@2x.png
  render_flat 87  icon-29@3x.png
  render_flat 80  icon-40@2x.png
  render_flat 120 icon-40@3x.png
  render_flat 120 icon-60@2x.png
  render_flat 180 icon-60@3x.png
else
  render 40  icon-20@2x.png
  render 60  icon-20@3x.png
  render 58  icon-29@2x.png
  render 87  icon-29@3x.png
  render 80  icon-40@2x.png
  render 120 icon-40@3x.png
  render 120 icon-60@2x.png
  render 180 icon-60@3x.png
fi

echo "Generating iPad icons..."
if [[ "$FLATTEN_ALL" == "true" ]]; then
  render_flat 20  icon-20~ipad.png
  render_flat 40  icon-20@2x~ipad.png
  render_flat 29  icon-29~ipad.png
  render_flat 58  icon-29@2x~ipad.png
  render_flat 40  icon-40~ipad.png
  render_flat 80  icon-40@2x~ipad.png
  render_flat 76  icon-76.png
  render_flat 152 icon-76@2x.png
  render_flat 167 icon-83.5@2x.png
else
  render 20  icon-20~ipad.png
  render 40  icon-20@2x~ipad.png
  render 29  icon-29~ipad.png
  render 58  icon-29@2x~ipad.png
  render 40  icon-40~ipad.png
  render 80  icon-40@2x~ipad.png
  render 76  icon-76.png
  render 152 icon-76@2x.png
  render 167 icon-83.5@2x.png
fi

echo "Generating App Store (marketing) icon (no alpha)..."
render_flat 1024 icon-1024.png

# Clean up any extraneous PNGs not referenced by Contents.json
echo "Cleaning up extraneous PNGs..."
expected_files=(
  "icon-20@2x.png" "icon-20@3x.png"
  "icon-29@2x.png" "icon-29@3x.png"
  "icon-40@2x.png" "icon-40@3x.png"
  "icon-60@2x.png" "icon-60@3x.png"
  "icon-20~ipad.png" "icon-20@2x~ipad.png"
  "icon-29~ipad.png" "icon-29@2x~ipad.png"
  "icon-40~ipad.png" "icon-40@2x~ipad.png"
  "icon-76.png" "icon-76@2x.png"
  "icon-83.5@2x.png" "icon-1024.png"
)

shopt -s nullglob
for f in *.png; do
  keep=false
  for e in "${expected_files[@]}"; do
    if [[ "$f" == "$e" ]]; then
      keep=true
      break
    fi
  done
  if [[ "$keep" == false ]]; then
    rm -f -- "$f"
  fi
done
shopt -u nullglob

echo "All icons generated and cleaned."

echo "Done. Verify there is no transparency per App Store rules."
