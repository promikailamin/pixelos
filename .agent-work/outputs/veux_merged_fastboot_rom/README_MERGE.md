# Merged Fastboot ROM - Redmi Note 11 Pro 5G (veux)

## Source ROMs
- **Official ROM** (firmware + structure): `veux_global_images_OS1.0.12.0.TKCMIXM_13.0_global_cda1240a45.tgz`
  - Xiaomi/HyperOS fastboot (MSMDownload/firehose) package, Android 13
  - Version: OS1.0.12.0.TKCMIXM (Global)
- **Custom ROM**: Google Drive `1M2JtqUxlRHQA10OKCjaSRTaHjmCT00Ec`
  - OTA payload (`payload.bin`), extracted with `payload_dumper`

## What was merged
The merge keeps the **official ROM's firmware / flash structure** and takes the **custom ROM's system images**:

| Component | Source | Notes |
|-----------|--------|-------|
| bootloader, modem, abl, tz, rpm, devcfg, hyp, xbl, qupfw, NON-HLOS, Core_NON-HLOS, ... | OFFICIAL | Hardware-specific firmware; must stay official |
| gpt partition table, rawprogram/patch XML, prog_firehose ELFs | OFFICIAL | Flash instructions for MSMDownload/fastboot |
| boot.img, vendor_boot.img, dtbo.img, vbmeta.img, vbmeta_system.img, rescue.img, cust.img | OFFICIAL | Verified-boot chain kept official |
| system.img, vendor.img, product.img, system_ext.img | CUSTOM | Extracted from custom `payload.bin` |
| misc.txt, anti_version.txt | OFFICIAL | Package metadata |

## What is NOT included / what still must be done
1. **`super.img` is NOT rebuilt.** On veux (Virtual A/B, dynamic partitions), `system`, `vendor`, `product`, `system_ext` live *inside* `super.img`. This package provides them as separate `custom_*.img` files. You must rebuild `super.img` with `lpmake` (Android SDK) using the custom images and the official partition sizes, then place it in `images/`.
   - `lpmake` is not installed in this runner; it was not available via apt.
2. **`userdata.img` is intentionally excluded.** Flashing it would overwrite user data. Wipe userdata via fastboot instead.
3. **`custom_boot.img` / `custom_dtbo.img` are provided as alternatives.** The package uses OFFICIAL `boot.img`, `dtbo.img`, `vbmeta.img`, `vbmeta_system.img` to keep the verified-boot chain consistent with the official firmware.

## CRITICAL SAFETY WARNINGS — READ BEFORE FLASHING
- **This merged ROM is UNTESTED. It was built in a CI runner and has NOT been flashed to a real device.** Flashing it may soft-brick (bootloop) or hard-brick your Redmi Note 11 Pro 5G.
- **AVB / Verified Boot:** The custom `system`/`vendor` images are NOT signed with Xiaomi's keys, and the custom `vbmeta.img`/`vbmeta_system.img` extracted from the payload are stubs (8 KB / 4 KB). Flashing this on a **locked bootloader with AVB enforced will FAIL to boot**. You must have an **unlocked bootloader** and disable AVB verification (e.g. `fastboot --disable-verity --disable-verification flash vbmeta ...` or flash a disabled-vbmeta), otherwise the device will refuse to boot.
- **Version mismatch:** The official ROM is HyperOS OS1.0.12.0.TKCMIXM (Android 13). The custom ROM's base version is unknown. Mixing system/vendor from different builds can cause bootloops, broken IMEI, camera, fingerprint, or widevine.
- **Have a recovery plan:** Know how to enter EDL / fastbootd and re-flash the official stock ROM before attempting anything.
- **Do not flash this on a daily-driver device unless you accept the risk of losing the device.**

## How to finish the merge (manual, on a Linux PC with Android SDK)
1. Install `android-tools` (fastboot) and `lpmake` (from AOSP / android-sdk).
2. Determine official super logical partition sizes (system/vendor/product/system_ext) from the official `super.img` (e.g. `lpunpack`).
3. `lpmake --metadata-size ... --super-name super --partition system:size:custom_system.img --partition vendor:size:custom_vendor.img --partition product:size:custom_product.img --partition system_ext:size:custom_system_ext.img --output super.img`
4. Copy the new `super.img` into `images/`, replacing the official one.
5. Flash with fastboot (unlocked bootloader, AVB disabled), then wipe userdata/cache/metadata.

## Extraction notes
- Official `super.img` unsparsed to 9,126,805,504 bytes (~8.5 GiB logical).
- Custom `payload.bin` extracted with `payload_dumper` → system/vendor/product/system_ext/boot/dtbo/vbmeta.
- Device: Redmi Note 11 Pro 5G (veux / peux), Snapdragon 695 (SM6375), Virtual A/B, dynamic partitions, super partition ~8 GB.
