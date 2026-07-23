# KernelSU Next + SUSFS for Poco F5 (marble)

Flashable AnyKernel3 package providing KernelSU Next and SUSFS support for Poco F5 (marble).

### Recommended Recovery:

[OrangeFox Recovery Project (OFRP)](https://github.com/Ctapchuk/android_device_xiaomi_marble-OFRP/releases/download/2025-02-15/OFRP-R11.1_7_RECOVERY-Beta-marble.img)

### Flashing Instructions

1. Reboot to OrangeFox Recovery.
2. Flash the latest `ksun_susfs-marble-YYYY.MM.DD.zip` matching your ROM build date.

For AOSPA-based ROMs flash `aospa-ksun_susfs-marble-YYYY.MM.DD.zip`.

Examples:

- InfinityX 2026-06-09 → `ksun_susfs-marble-2026.06.09.zip`
- AxionOS 2026-06-09 → `ksun_susfs-marble-2026.06.09.zip`
- AOSPA 2026-07-15 → `aospa-ksun_susfs-marble-2026.07.15.zip`
- Neoteric 2026-07-20 → `aospa-ksun_susfs-marble-2026.07.20.zip`

Always use the kernel package corresponding to your ROM's build date.

3. Reboot to System.

## Supported ROMs

- InfinityX (Official)
- AxionOS (Official)
- AOSPA / Paranoid Android
- Neoteric OS

## Downloads

Download the latest release from the [Releases](../../releases) section.

## CI Actions

This repository uses GitHub Actions to build flashable kernel zips.

1. Go to the [Actions](../../actions) tab.
2. Select **Build Marble Kernel** from the workflow list.
3. Click **Run workflow** and fill in the options:

| Option | Description |
|--------|-------------|
| **Kernel source** | `aosp-pablo` for AOSP-based ROMs, `aospa-pablo` for AOSPA-based ROMs |
| **Source ref** | Leave empty to use preset default branch, or enter a branch/tag/commit to test |
| **Toolchain** | Leave as `auto` (uses preset's recommended toolchain) |
| **Build: ALL managers** | Check to build all 4 managers at once |
| **Enable SUSFS** | Leave checked (default), uncheck to build without SUSFS |
| **Create draft release** | Check to auto-create a draft GitHub Release with all ZIPs |

4. Click **Run workflow** to start the build.
5. Download the built ZIPs from the completed run's **Artifacts** section, or publish the draft release.

## Credits

- [KernelSU Next Team](https://github.com/KernelSU-Next/KernelSU-Next)
- [SUSFS Developers](https://gitlab.com/simonpunk/susfs4ksu/-/tree/gki-android12-5.10?ref_type=heads)
- [osm0sis (AnyKernel3)](https://github.com/osm0sis/AnyKernel3)
- [LineageOS](https://github.com/LineageOS)
- [ParanoidAndroid](https://github.com/AOSPA)
- [jinetty](https://github.com/jinetty)
- [mohdakil2426](https://github.com/mohdakil2426)
## Maintainer

PabloEscobar

## Disclaimer

- Flash at your own risk.
- Always keep a backup of your current boot and vendor_boot images.
- Iam not responsible for any damage, data loss, or bootloops caused by flashing this package.
