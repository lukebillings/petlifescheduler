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
# Columns with mean luminance below this are treated as simulator bezel and removed.
DARK_EDGE_MEAN_THRESHOLD="${DARK_EDGE_MEAN_THRESHOLD:-0.4}"

# Simulator captures often leave a dark vertical strip inside the image (not on the
# outer border), so -trim alone does not remove it.
chop_dark_edge_columns() {
  local image="$1"
  local gravity="$2"
  local max_chop="${3:-32}"
  local i=0

  while [[ "$i" -lt "$max_chop" ]]; do
    local edge_mean
    if [[ "$gravity" == "East" ]]; then
      edge_mean=$(magick "$image" -crop 1x0+$(( $(magick identify -format '%w' "$image") - 1 ))+0 +repage -format '%[fx:mean]' info:)
    else
      edge_mean=$(magick "$image" -crop 1x0+0+0 +repage -format '%[fx:mean]' info:)
    fi
    if awk -v m="$edge_mean" -v t="$DARK_EDGE_MEAN_THRESHOLD" 'BEGIN { exit (m < t) ? 0 : 1 }'; then
      magick "$image" -gravity "$gravity" -chop 1x0 +repage "$image"
      i=$((i + 1))
    else
      break
    fi
  done
}

process_image() {
  local input="$1"
  local output="$2"
  local crop_height_percent="${3:-}"
  local trimmed="${output%.png}_trimmed.png"

  magick "$input" \
    -bordercolor black -border 1x1 \
    -fuzz 6% -trim +repage \
    -shave 3%x0 \
    -type TrueColor -colorspace sRGB \
    "$trimmed"

  # Optional: keep top N% after trim (e.g. drop tab bar from full-screen captures).
  if [[ -n "$crop_height_percent" ]]; then
    magick "$trimmed" -crop "100%x${crop_height_percent}%+0+0" +repage "$trimmed"
  fi

  chop_dark_edge_columns "$trimmed" East
  chop_dark_edge_columns "$trimmed" West

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
  "paywall_preview_schedule|Screenshot_2026-05-20_at_16.29.47-645d2f0d-6399-43d1-b09f-274167beee57.png"
  "paywall_preview_logs|Screenshot_2026-05-20_at_16.31.01-6f834a2d-5269-4856-a3a2-cb0622b18766.png|55"
  "paywall_preview_documents|Screenshot_2026-05-20_at_15.24.50-686cddc9-5a2b-4096-a37b-0c0648efaf8a.png"
  "paywall_preview_weight|Screenshot_2026-05-20_at_15.25.39-3100f825-8cf3-4ec3-bbe3-68ee22e06081.png"
  "paywall_preview_vet|Screenshot_2026-05-20_at_15.25.59-42833bec-83f3-4642-a371-a3bcac3095db.png"
)

for job in "${JOBS[@]}"; do
  name="${job%%|*}"
  rest="${job#*|}"
  if [[ "$rest" == *"|"* ]]; then
    file="${rest%%|*}"
    crop_pct="${rest#*|}"
  else
    file="$rest"
    crop_pct=""
  fi
  src_path="${SRC}/${file}"
  if [[ ! -f "$src_path" ]]; then
    echo "Missing: $src_path" >&2
    exit 1
  fi
  out="${TMP}/${name}.png"
  if [[ -n "$crop_pct" ]]; then
    echo "Processing ${name} ← ${file} (crop top ${crop_pct}%)"
  else
    echo "Processing ${name} ← ${file}"
  fi
  process_image "$src_path" "$out" "$crop_pct"
  setup_imageset "$name" "$out"
done

echo "Done — paywall preview imagesets updated."
