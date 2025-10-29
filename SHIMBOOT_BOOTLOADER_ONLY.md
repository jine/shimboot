# Shimboot Bootloader-Only Build

> **Note**: This bootloader-only build mode was created with assistance from Claude 4.5 Sonnet (Anthropic AI) to streamline the Shimboot project for automated, non-interactive booting scenarios.

This document describes the bootloader-only build mode for Shimboot, which creates a minimal USB drive that automatically boots an existing Linux installation on your Chromebook's internal storage.

## Overview

The bootloader-only build removes all interactive menus and rootfs creation, producing a streamlined USB drive that:
- Automatically boots `/dev/mmcblk1p4` without user interaction
- Contains only the essential bootloader components (no Debian/Ubuntu/Alpine rootfs)
- Provides a minimal, non-interactive boot experience

## Use Cases

This build mode is ideal for:
- **Pre-configured systems**: When you already have a Linux installation on your Chromebook's internal storage
- **Dedicated boot drives**: Creating a simple USB stick that always boots the same partition
- **Automated deployments**: Scenarios where user interaction is not desired or possible
- **Minimal footprint**: When disk space on the USB drive is limited
- **Persistent Shimboot installations**: After using the standard Shimboot to install a Linux distribution (e.g., Debian) and copying it to the Chromebook's internal MMC storage with `dd`, this bootloader-only USB acts as a permanent boot key

### Common Workflow: From Shimboot to Bootloader-Only

A typical use case involves these steps:

1. **Initial Setup**: Use the standard Shimboot image to boot and install your preferred Linux distribution (Debian, Ubuntu, etc.) on the Chromebook
2. **Copy to Internal Storage**: Use `dd` to copy your configured Linux installation to the Chromebook's internal MMC storage (e.g., `/dev/mmcblk1p4`)
3. **Create Boot Key**: Build this bootloader-only USB drive to automatically boot your internal installation
4. **Automatic Booting**: With developer mode enabled, simply insert the USB key and the Chromebook will automatically boot your installed OS from internal storage - no manual intervention needed (no Ctrl+U required if USB boot priority is configured)

This workflow gives you:
- A full Linux installation running from fast internal storage
- A small, portable USB key that acts as a bootloader
- The ability to boot back into Chrome OS by simply removing the USB key
- No need to navigate menus or make selections on each boot

## What's Different?

### Removed Features
- Interactive OS selector menu
- Full rootfs building (`build_rootfs.sh` and `patch_rootfs.sh` replaced with minimal dummy rootfs)
- Support for Debian, Ubuntu, and Alpine full installations
- LUKS encryption options
- Desktop environment selection
- ChromeOS boot support

### Modified Components

1. **bootloader/bin/bootstrap.sh**
   - Automatically boots `/dev/mmcblk1p4` on startup
   - No user prompts or menu system
   - Direct boot without partition scanning

2. **build.sh**
   - Requires standard 3 arguments: `output_path`, `shim_path`, and `rootfs_dir`
   - Uses minimal rootfs created by `create_minimal_rootfs.sh`
   - Creates full 4-partition structure (required by ChromeOS kernel)

3. **build_complete.sh**
   - Removed rootfs-related parameters (`desktop`, `distro`, `release`, `luks`, etc.)
   - Calls `create_minimal_rootfs.sh` instead of `build_rootfs.sh`
   - Reduced dependencies (no `debootstrap`, `cryptsetup`, or `qemu-user-static`)

4. **create_minimal_rootfs.sh**
   - Creates a tiny (~1MB) dummy rootfs with basic directory structure
   - Satisfies ChromeOS kernel's 4-partition requirement
   - Contains only essential skeleton (no actual OS or utilities)

5. **image_utils.sh**
   - Simplified `create_partitions()` and `populate_partitions()` (removed LUKS)
   - Adds dummy `factory_install.sh` script to prevent ChromeOS factory installer errors
   - Maintains full 4-partition shimboot structure

## Build Instructions

### Prerequisites

Minimal dependencies required:
```bash
wget python3 unzip zip git cpio binwalk pcregrep cgpt mkfs.ext4 mkfs.ext2 fdisk lz4 pv
```

On Debian/Ubuntu, install with:
```bash
sudo apt-get install wget python3 unzip zip cpio binwalk pcregrep cgpt kmod pv lz4 -y
```

### Building the Bootloader-Only Image

#### Option 1: Complete Build (Downloads shim automatically)
```bash
sudo ./build_complete.sh <board_name> arch=<arch>
```

Example:
```bash
sudo ./build_complete.sh dedede arch=amd64
```

**Note:** The first build will download the Chrome OS shim image (~4GB). This is cached in `./data/shim_<board>.bin`, so subsequent builds for the same board will be instant. You may see a binwalk warning during extraction - this is normal and can be ignored.

#### Option 2: Manual Build (Using existing shim)
```bash
sudo ./build.sh <output_path> <shim_path> arch=<arch>
```

Example:
```bash
sudo ./build.sh shimboot_dedede.bin shim_dedede.bin arch=amd64
```

### Arguments

**build_complete.sh:**
- `board_name` - Chrome OS board name (e.g., `dedede`, `octopus`, `nissa`)
- `arch` - CPU architecture: `amd64` (default) or `arm64`
- `quiet` - Suppress progress indicators (optional)
- `compress_img` - Compress final image into a zip file (optional)
- `data_dir` - Custom working directory (optional, defaults to `./data`)

**build.sh:**
- `output_path` - Path for the output disk image
- `shim_path` - Path to the Chrome OS RMA shim image
- `rootfs_dir` - Path to the minimal rootfs directory (created by `create_minimal_rootfs.sh`)
- `arch` - CPU architecture: `amd64` (default) or `arm64`
- `quiet` - Suppress progress indicators (optional)

## Target Partition

The bootloader is currently hardcoded to boot `/dev/mmcblk1p4`. To change this:

1. Edit `bootloader/bin/bootstrap.sh`
2. Find the line: `local target="/dev/mmcblk1p4"`
3. Change to your desired partition (e.g., `/dev/mmcblk0p3`)
4. Rebuild the image

### Common Chromebook Partition Devices

- `/dev/mmcblk0` - Internal eMMC storage (most common)
  - `/dev/mmcblk0p1`, `/dev/mmcblk0p2`, etc.
- `/dev/mmcblk1` - SD card or secondary storage
  - `/dev/mmcblk1p1`, `/dev/mmcblk1p2`, etc.
- `/dev/nvme0n1` - NVMe storage (some newer models)
  - `/dev/nvme0n1p1`, `/dev/nvme0n1p2`, etc.
- `/dev/sda` - USB or SATA storage
  - `/dev/sda1`, `/dev/sda2`, etc.

## Image Structure

The bootloader-only image contains 4 partitions (full shimboot structure):

1. **Partition 1**: 1MB stateful partition (contains dummy `factory_install.sh`)
2. **Partition 2**: 32MB Chrome OS kernel
3. **Partition 3**: 20MB bootloader partition
4. **Partition 4**: ~1MB minimal dummy rootfs (skeleton filesystem)

**Why 4 partitions?** The ChromeOS kernel expects the full shimboot partition layout. Without partition 4, the kernel detects the USB as an installation source and shows "Factory installation aborted" errors. The minimal rootfs satisfies this requirement while keeping the image small.

Total size: ~100MB (compared to several GB for a full Shimboot image)

## Booting the Image

1. Flash the image to a USB drive:
   ```bash
   sudo dd if=shimboot_<board>.bin of=/dev/sdX bs=4M status=progress
   ```
   Replace `/dev/sdX` with your USB drive device.

2. Enable developer mode on your Chromebook (if not already enabled):
   - Turn off the Chromebook
   - Press `Esc + Refresh + Power`
   - At the recovery screen, press `Ctrl + D`
   - Confirm and wait for developer mode setup

3. Insert the USB drive and reboot

4. At the developer mode screen, press `Ctrl + U` to boot from USB

5. The bootloader will automatically boot your Linux installation on `/dev/mmcblk1p4`

### Automatic Boot (No Ctrl+U Required)

Once you've successfully booted with `Ctrl + U` a few times, the Chromebook may remember the USB boot preference. In developer mode, some Chromebooks will automatically attempt to boot from USB if present, making the boot process completely automatic:

1. Insert the bootloader USB key
2. Power on or reboot the Chromebook
3. Wait for the developer mode screen (may show briefly)
4. The system automatically boots your internal Linux installation

This makes the USB key function as a true "boot key" - insert it to boot Linux, remove it to boot Chrome OS.

## Troubleshooting

### "WARNING: One or more files failed to extract" during build
- This is a normal binwalk warning when extracting the Chrome OS kernel
- The important components (kernel and initramfs) extract successfully
- You can safely ignore this warning - it won't affect the bootloader

### "Factory installation aborted" error
- This means the ChromeOS kernel couldn't find the expected 4-partition structure
- Ensure you're using the latest build scripts that create the minimal rootfs
- The image must have all 4 partitions, even if partition 4 is just a dummy

### Boot fails with "mounting rootfs failed"
- Verify the target partition exists and contains a valid Linux rootfs
- Check if the partition path is correct for your device
- Ensure the filesystem is supported (ext4, ext3, ext2)

### Wrong partition is being booted
- Edit `bootloader/bin/bootstrap.sh` to change the target partition
- Rebuild the image with the new bootstrap script

### USB drive not recognized
- Ensure developer mode is enabled
- Try a different USB port
- Verify the image was written correctly with `dd`

### LUKS encrypted partition won't boot
- The bootloader-only build doesn't include `cryptsetup`
- You'll need to add it manually to `bootloader/bin/`
- Modify `bootstrap.sh` to prompt for the encryption password

## Reverting to Standard Shimboot

To return to the full interactive Shimboot with rootfs support:

1. Checkout the original version from git:
   ```bash
   git remote add upstream https://github.com/ading2210/shimboot.git
   git fetch upstream
   git checkout upstream/main
   ```

2. Or for the bootloader-only fork:
   ```bash
   git checkout main
   git reset --hard origin/main
   ```

3. Or manually restore the modified files from the repository

## Technical Details

### Boot Process

1. Chrome OS kernel loads from partition 2
2. Kernel checks for 4-partition shimboot structure (partitions 1-4 on USB)
3. Kernel extracts and runs the patched initramfs (bootloader from partition 3)
4. `bootloader/bin/bootstrap.sh` executes as init (PID 1)
5. Bootstrap script skips menu and directly mounts `/dev/mmcblk1p4` (internal storage) as `/newroot`
6. Script moves `/sys`, `/proc`, `/dev` to newroot
7. `pivot_root` switches to the new rootfs
8. Control transfers to `/sbin/init` in the target partition on internal storage

**Note:** Partition 4 on the USB contains a dummy minimal rootfs that is never actually booted - it exists only to satisfy the ChromeOS kernel's partition structure requirements.

### Dependencies Not Required

Compared to standard Shimboot, the bootloader-only build doesn't need:
- `debootstrap` - No rootfs creation
- `cryptsetup` - No LUKS encryption support
- `qemu-user-static` - No cross-architecture chroot needed
- `depmod` - No kernel module management
- `findmnt` - No complex mount detection

## Contributing

If you encounter issues or have improvements for the bootloader-only build:
1. Open an issue on the [Shimboot fork repository](https://github.com/jine/shimboot)
2. Submit a pull request with your changes
3. Include "bootloader-only" in the title for clarity

Original Shimboot project: [ading2210/shimboot](https://github.com/ading2210/shimboot)

## License

This modification maintains the same GPLv3 license as the original Shimboot project.
