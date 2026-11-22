#!/usr/bin/env bash
# Reproducible assembly of the merged veux fastboot ROM package.
# Run from: /home/runner/work/pixelos/pixelos
#
# This script COPIES official firmware/structure + custom system images
# into a merged package. It does NOT rebuild super.img (requires lpmake).
#
# Output: .agent-work/outputs/veux_merged_fastboot_rom/
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/.agent-work/outputs/veux_merged_fastboot_rom"
TMP="$ROOT/.agent-work/tmp"

OFF_IMG="$TMP/work/official_extract/veux_global_images_OS1.0.12.0.TKCMIXM_13.0/images"
CUS_IMG="$TMP/work/custom_extract/extracted_payload"

rm -rf "$OUT"
mkdir -p "$OUT/images"

cp "$OFF_IMG"/boot.img "$OFF_IMG"/vendor_boot.img "$OFF_IMG"/dtbo.img \
   "$OFF_IMG"/vbmeta.img "$OFF_IMG"/vbmeta_system.img "$OFF_IMG"/rescue.img \
   "$OFF_IMG"/cust.img "$OUT/images/"

cp "$OFF_IMG"/abl.elf "$OFF_IMG"/tz.mbn "$OFF_IMG"/rpm.mbn "$OFF_IMG"/devcfg.mbn \
   "$OFF_IMG"/hyp.mbn "$OFF_IMG"/xbl_config.elf "$OFF_IMG"/NON-HLOS.bin \
   "$OFF_IMG"/Core_NON-HLOS.bin "$OFF_IMG"/BTFM.bin "$OFF_IMG"/dspso.bin \
   "$OFF_IMG"/imagefv.elf "$OFF_IMG"/featenabler.mbn "$OFF_IMG"/qupv3fw.elf \
   "$OFF_IMG"/prog_firehose_ddr.elf "$OFF_IMG"/prog_firehose_lite.elf "$OUT/images/"

cp "$OFF_IMG"/gpt_main*.bin "$OFF_IMG"/gpt_both*.bin "$OFF_IMG"/gpt_backup*.bin "$OFF_IMG"/gpt_empty*.bin "$OUT/images/"
cp "$OFF_IMG"/rawprogram*.xml "$OFF_IMG"/patch*.xml "$OFF_IMG"/crclist.txt "$OFF_IMG"/sparsecrclist.txt "$OUT/images/"

cp "$CUS_IMG"/system.img "$OUT/images/custom_system.img"
cp "$CUS_IMG"/vendor.img "$OUT/images/custom_vendor.img"
cp "$CUS_IMG"/product.img "$OUT/images/custom_product.img"
cp "$CUS_IMG"/system_ext.img "$OUT/images/custom_system_ext.img"
cp "$CUS_IMG"/boot.img "$OUT/images/custom_boot.img"
cp "$CUS_IMG"/dtbo.img "$OUT/images/custom_dtbo.img"

OFF_TOP="$TMP/work/official_extract/veux_global_images_OS1.0.12.0.TKCMIXM_13.0"
cp "$OFF_TOP"/misc.txt "$OFF_TOP"/anti_version.txt "$OFF_TOP"/elf_path.txt "$OUT/" 2>/dev/null || true

echo "Merge package assembled at $OUT"
du -sh "$OUT"
