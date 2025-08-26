#!/usr/bin/env bash
set -euo pipefail

# Import iOS AppIcon PNGs from a folder exported with names like:
#   Icon-iOS-Default-20x20@2x.png, Icon-iOS-Default-1024x1024@1x.png, etc.
# Maps them to this appiconset's filenames in Contents.json.

cd "$(dirname "$0")"

SRC_DIR="${1:-}"
VARIANT="${2:-Icon-iOS-Default}"

if [[ -z "$SRC_DIR" ]]; then
  echo "Usage: $0 <source-folder> [variant-name]" 1>&2
  echo "Example: $0 '/path/Icon Exports 2' Icon-iOS-Default" 1>&2
  exit 2
fi

if [[ ! -d "$SRC_DIR" ]]; then
  echo "Source folder not found: $SRC_DIR" 1>&2
  exit 3
fi

have_tool() { command -v "$1" >/dev/null 2>&1; }

# Prefer sips (macOS) or magick/convert for resizing when deriving 1x iPad icons
RESIZE_TOOL=""
if have_tool sips; then RESIZE_TOOL=sips; fi
if [[ -z "$RESIZE_TOOL" ]] && have_tool magick; then RESIZE_TOOL=magick; fi
if [[ -z "$RESIZE_TOOL" ]] && have_tool convert; then RESIZE_TOOL=convert; fi

copy_file() {
  local src_name="$1"; shift
  local dst_name="$1"; shift
  local src_path="$SRC_DIR/$src_name"
  if [[ -f "$src_path" ]]; then
    cp -f "$src_path" "$dst_name"
    echo "Copied $src_name -> $dst_name"
    return 0
  else
    return 1
  fi
}

resize_half() {
  local src_name="$1"; shift
  local dst_name="$1"; shift
  local src_path="$SRC_DIR/$src_name"
  if [[ ! -f "$src_path" ]]; then
    return 1
  fi
  case "$RESIZE_TOOL" in
    sips)
      # sips allows resizing to exact pixel dimensions; get size first
      local w h
      w=$(sips -g pixelWidth  "$src_path" | awk '/pixelWidth/ {print $2}')
      h=$(sips -g pixelHeight "$src_path" | awk '/pixelHeight/ {print $2}')
      # halve and round
      w=$(( (w+1)/2 ))
      h=$(( (h+1)/2 ))
      sips -s format png -z "$h" "$w" "$src_path" --out "$dst_name" >/dev/null
      ;;
    magick)
      magick "$src_path" -resize 50% -strip -colorspace sRGB "$dst_name"
      ;;
    convert)
      convert "$src_path" -resize 50% -strip -colorspace sRGB "$dst_name"
      ;;
    *)
      echo "No resize tool available to derive 1x icon from $src_name" 1>&2
      return 2
      ;;
  esac
  echo "Derived 1x from $src_name -> $dst_name"
}

# iPhone
copy_file "$VARIANT-20x20@2x.png"  "icon-20@2x.png"  || true
copy_file "$VARIANT-20x20@3x.png"  "icon-20@3x.png"  || true
copy_file "$VARIANT-29x29@2x.png"  "icon-29@2x.png"  || true
copy_file "$VARIANT-29x29@3x.png"  "icon-29@3x.png"  || true
copy_file "$VARIANT-40x40@2x.png"  "icon-40@2x.png"  || true
copy_file "$VARIANT-40x40@3x.png"  "icon-40@3x.png"  || true
copy_file "$VARIANT-60x60@2x.png"  "icon-60@2x.png"  || true
copy_file "$VARIANT-60x60@3x.png"  "icon-60@3x.png"  || true

# iPad 2x direct
copy_file "$VARIANT-20x20@2x.png"   "icon-20@2x~ipad.png" || true
copy_file "$VARIANT-29x29@2x.png"   "icon-29@2x~ipad.png" || true
copy_file "$VARIANT-40x40@2x.png"   "icon-40@2x~ipad.png" || true
copy_file "$VARIANT-76x76@2x.png"   "icon-76@2x.png"      || true
copy_file "$VARIANT-83.5x83.5@2x.png" "icon-83.5@2x.png"  || true

# iPad 1x derived from their 2x counterparts
resize_half "$VARIANT-20x20@2x.png"  "icon-20~ipad.png"  || true
resize_half "$VARIANT-29x29@2x.png"  "icon-29~ipad.png"  || true
resize_half "$VARIANT-40x40@2x.png"  "icon-40~ipad.png"  || true
resize_half "$VARIANT-76x76@2x.png"  "icon-76.png"       || true

# App Store marketing
copy_file "$VARIANT-1024x1024@1x.png" "icon-1024.png" || true

echo "Import complete from $SRC_DIR using variant $VARIANT"

