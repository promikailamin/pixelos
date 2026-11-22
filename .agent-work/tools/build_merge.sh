#!/usr/bin/env bash
# Reproducible assembly of the merged veux fastboot ROM package.
# Run from: /home/runner/work/pixelos/pixelos
#
# This script assembles official firmware/flash-structure + custom system
# images into a merged package and REBUILDS super.img from the custom
# logical partitions using lpmake (Android SDK).
#
# Firmware/bootloader/modem/gpt/rawprogram/firehose stay OFFICIAL
# (hardware-specific, must match the device).
# Logical partitions (system/vendor/product/system_ext) and the physical
# boot/vendor_boot/dtbo/vbmeta images are taken from the CUSTOM ROM.
#
# Requires in PATH: lpmake (from AOSP system/tools/lpmake) and fastboot
# (android-tools). See ensure_tools() below.
#
# Output: .agent-work/outputs/veux_merged_fastboot_rom/
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/.agent-work/outputs/veux_merged_fastboot_rom"
TMP="$ROOT/.agent-work/tmp"

OFF_IMG="$TMP/work/official_extract/veux_global_images_OS1.0.12.0.TKCMIXM_13.0/images"
OFF_TOP="$TMP/work/official_extract/veux_global_images_OS1.0.12.0.TKCMIXM_13.0"
CUS_IMG="$TMP/work/custom_extract/extracted_payload"

SUPER_IMG="$OUT/images/super.img"
# Physical super partition size (bytes). official super unsparses to ~8.5 GiB.
SUPER_SIZE="${SUPER_SIZE:-9126805504}"
METADATA_SIZE="${METADATA_SIZE:-65536}"

# Logical partition sizes (bytes). These MUST match the official super.img
# layout. Override via env vars or edit the defaults below. Extract them from
# the official super.img with `lpunpack` (AOSP) before building.
SUPER_SYSTEM_SIZE="${SUPER_SYSTEM_SIZE:-4294967296}"     # 4 GiB
SUPER_VENDOR_SIZE="${SUPER_VENDOR_SIZE:-2147483648}"     # 2 GiB
SUPER_PRODUCT_SIZE="${SUPER_PRODUCT_SIZE:-1073741824}"   # 1 GiB
SUPER_SYSTEM_EXT_SIZE="${SUPER_SYSTEM_EXT_SIZE:-536870912}"  # 512 MiB

# --- tool checks -----------------------------------------------------------
ensure_tools() {
    local missing=0
    for tool in lpmake fastboot; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "ERROR: '$tool' not found in PATH." >&2
            missing=1
        fi
    done
    if [ "$missing" -ne 0 ]; then
        echo "Install android-tools (fastboot) and provide a prebuilt lpmake" >&2
        echo "  (build from AOSP system/tools/lpmake). lpmake/lpunpack are needed." >&2
        exit 1
    fi
}

# --- pick image: prefer custom, fall back to official ---------------------
pick_img() {
    # pick_img <name> : echoes path to custom image if present, else official
    local name="$1"
    if [ -f "$CUS_IMG/$name" ]; then
        echo "$CUS_IMG/$name"
    elif [ -f "$OFF_IMG/$name" ]; then
        echo "$OFF_IMG/$name"
    else
        echo ""
    fi
}

# --- detect logical partition sizes from official super (lpunpack) ---------
detect_sizes() {
    # If lpunpack is available, try to read logical partition sizes from the
    # official super.img and export them for lpmake.
    if ! command -v lpunpack >/dev/null 2>&1; then
        return 0
    fi
    local src
    src="$(pick_img "super.img")"
    if [ -z "$src" ] || [ ! -f "$src" ]; then
        return 0
    fi
    local workdir
    workdir="$(mktemp -d)"
    if lpunpack "$src" "$workdir" >/dev/null 2>&1; then
        for part in system vendor product system_ext; do
            if [ -f "$workdir/$part.img" ]; then
                local sz
                sz="$(stat -c %s "$workdir/$part.img")"
                case "$part" in
                    system) export SUPER_SYSTEM_SIZE="$sz" ;;
                    vendor) export SUPER_VENDOR_SIZE="$sz" ;;
                    product) export SUPER_PRODUCT_SIZE="$sz" ;;
                    system_ext) export SUPER_SYSTEM_EXT_SIZE="$sz" ;;
                esac
            fi
        done
    fi
    rm -rf "$workdir"
}

# ---------------------------------------------------------------------------
ensure_tools
detect_sizes

echo "super partition size : $SUPER_SIZE"
echo "system size          : $SUPER_SYSTEM_SIZE"
echo "vendor size          : $SUPER_VENDOR_SIZE"
echo "product size         : $SUPER_PRODUCT_SIZE"
echo "system_ext size      : $SUPER_SYSTEM_EXT_SIZE"

rm -rf "$OUT"
mkdir -p "$OUT/images"

echo "[1/5] Copying OFFICIAL firmware + flash structure (kept official)"
cp "$OFF_IMG"/abl.elf "$OFF_IMG"/tz.mbn "$OFF_IMG"/rpm.mbn "$OFF_IMG"/devcfg.mbn \
   "$OFF_IMG"/hyp.mbn "$OFF_IMG"/xbl_config.elf "$OFF_IMG"/NON-HLOS.bin \
   "$OFF_IMG"/Core_NON-HLOS.bin "$OFF_IMG"/BTFM.bin "$OFF_IMG"/dspso.bin \
   "$OFF_IMG"/imagefv.elf "$OFF_IMG"/featenabler.mbn "$OFF_IMG"/qupv3fw.elf \
   "$OFF_IMG"/prog_firehose_ddr.elf "$OFF_IMG"/prog_firehose_lite.elf "$OUT/images/"

cp "$OFF_IMG"/gpt_main*.bin "$OFF_IMG"/gpt_both*.bin "$OFF_IMG"/gpt_backup*.bin "$OFF_IMG"/gpt_empty*.bin "$OUT/images/"
cp "$OFF_IMG"/rawprogram*.xml "$OFF_IMG"/patch*.xml "$OFF_IMG"/crclist.txt "$OFF_IMG"/sparsecrclist.txt "$OUT/images/"

echo "[2/5] Copying physical partition images (custom preferred, official fallback)"
for img in boot.img vendor_boot.img dtbo.img vbmeta.img vbmeta_system.img rescue.img cust.img; do
    src="$(pick_img "$img")"
    if [ -n "$src" ]; then
        cp "$src" "$OUT/images/$img"
        echo "  $img <- $(basename "$(dirname "$src")")"
    else
        echo "  $img <- SKIPPED (not present in official or custom)"
    fi
done

echo "[3/5] Copying CUSTOM logical partition images (extracted from payload)"
for img in system.img vendor.img product.img system_ext.img; do
    cp "$CUS_IMG/$img" "$OUT/images/custom_$img"
    echo "  custom_$img"
done

echo "[4/5] Rebuilding super.img from custom logical partitions (lpmake)"
lpmake \
    --metadata-size "$METADATA_SIZE" \
    --super-name super \
    --super-partition-size "$SUPER_SIZE" \
    --partition system:$SUPER_SYSTEM_SIZE:"$OUT/images/custom_system.img" \
    --partition vendor:$SUPER_VENDOR_SIZE:"$OUT/images/custom_vendor.img" \
    --partition product:$SUPER_PRODUCT_SIZE:"$OUT/images/custom_product.img" \
    --partition system_ext:$SUPER_SYSTEM_EXT_SIZE:"$OUT/images/custom_system_ext.img" \
    --output "$SUPER_IMG" \
    --sparse
echo "  super.img built -> $SUPER_IMG"
du -h "$SUPER_IMG"

echo "[5/5] Copying package metadata"
cp "$OFF_TOP"/misc.txt "$OFF_TOP"/anti_version.txt "$OFF_TOP"/elf_path.txt "$OUT/" 2>/dev/null || true

echo "Merge package assembled at $OUT"
du -sh "$OUT"
