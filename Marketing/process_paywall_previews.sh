#!/usr/bin/env bash
# Process raw UI screenshots into paywall carousel assets:
# trim bezels, place on light grey card (secondarySystemBackground), round card corners.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${PET_PAYWALL_SRC:-/Users/lukebillings/.cursor/projects/Users-lukebillings-code-lukebillings-PetSchedule/assets}"
ASSETS="${ROOT}/PetSchedule/Resources/Assets.xcassets"

if [[ ! -d "$SRC" ]]; then
  echo "Source assets folder not found: $SRC" >&2
  exit 1
fi

# Matches iOS `secondarySystemBackground` (light) — same fill as paywall plan cards.
CARD_BG="${CARD_BG:-#F2F2F7}"
CARD_PADDING="${CARD_PADDING:-14}"
CORNER_RADIUS="${CORNER_RADIUS:-16}"

process_image() {
  local input="$1"
  local output="$2"
  local trimmed="${output%.png}_trimmed.png"

  magick "$input" \
    -bordercolor black -border 1x1 \
    -fuzz 6% -trim +repage \
    -shave 3%x0 \
    -type TrueColor -colorspace sRGB \
    "$trimmed"

  local content_w content_h canvas_w canvas_h
  content_w=$(magick identify -format '%w' "$trimmed")
  content_h=$(magick identify -format '%h' "$trimmed")
  canvas_w=$((content_w + 2 * CARD_PADDING))
  canvas_h=$((content_h + 2 * CARD_PADDING))

  magick -size "${canvas_w}x${canvas_h}" "xc:${CARD_BG}" \
    "$trimmed" -geometry "+${CARD_PADDING}+${CARD_PADDING}" -composite \
    \( +clone -alpha extract \
       -draw "fill black rectangle 0,0 %[fx:w],%[fx:h]" \
       -fill white -draw "roundrectangle 0,0 %[fx:w-1],%[fx:h-1] ${CORNER_RADIUS},${CORNER_RADIUS}" \
    \) -alpha off -compose CopyOpacity -composite \
    -type TrueColor -colorspace sRGB \
    "$output"

  rm -f "$trimmed"
}

setup_imageset() {
  local name="$1"
  local png="$2"
  local dir="${ASSETS}/${name}.imageset"
  mkdir -p "$dir"
  cp "$png" "${dir}/${name}.png"
  cat > "${dir}/Contents.json" <<EOF
{
  "images" : [
    {
      "filename" : "${name}.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

declare -a JOBS=(
  "paywall_preview_schedule|Screenshot_2026-05-20_at_15.25.01-677052ed-f643-411a-acba-98e9a1822f52.png"
  "paywall_preview_logs|Screenshot_2026-05-20_at_15.25.08-713e33d6-e49b-4eb0-845b-87ddca3b3c49.png"
  "paywall_preview_documents|Screenshot_2026-05-20_at_15.24.50-686cddc9-5a2b-4096-a37b-0c0648efaf8a.png"
  "paywall_preview_weight|Screenshot_2026-05-20_at_15.25.39-3100f825-8cf3-4ec3-bbe3-68ee22e06081.png"
  "paywall_preview_vet|Screenshot_2026-05-20_at_15.25.59-42833bec-83f3-4642-a371-a3bcac3095db.png"
)

for job in "${JOBS[@]}"; do
  name="${job%%|*}"
  file="${job##*|}"
  src_path="${SRC}/${file}"
  if [[ ! -f "$src_path" ]]; then
    echo "Missing: $src_path" >&2
    exit 1
  fi
  out="${TMP}/${name}.png"
  echo "Processing ${name} ← ${file}"
  process_image "$src_path" "$out"
  setup_imageset "$name" "$out"
done

echo "Done — paywall preview imagesets updated."
