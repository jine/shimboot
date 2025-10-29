#!/bin/bash

# Create a minimal dummy rootfs for bootloader-only build
# This satisfies the shimboot structure requirements

rootfs_dir="$1"

mkdir -p "$rootfs_dir"
mkdir -p "$rootfs_dir/bin"
mkdir -p "$rootfs_dir/sbin"
mkdir -p "$rootfs_dir/etc"
mkdir -p "$rootfs_dir/proc"
mkdir -p "$rootfs_dir/sys"
mkdir -p "$rootfs_dir/dev"
mkdir -p "$rootfs_dir/tmp"
mkdir -p "$rootfs_dir/root"

# Create a minimal init that just sleeps
cat > "$rootfs_dir/sbin/init" << 'EOF'
#!/bin/sh
# Dummy init - this rootfs is never actually booted
echo "This is a dummy rootfs and should never be reached"
sleep infinity
EOF

chmod +x "$rootfs_dir/sbin/init"

echo "Minimal rootfs created at $rootfs_dir"
