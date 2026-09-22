#!/bin/bash
# Run prepare/initramfs in the ARM builder and finish in the native builder.
# Bind the repository at /repo; root is a disposable unsquashfs extraction.
set -euo pipefail
cd /repo
work=/repo/build/hp-thinkpad
root=$work/t14-bootdiag-root
stage=$work/t14-bootdiag-stage
package=omarchy-hw-snapdragon-early-experimental-0.3-1-any.pkg.tar.xz
mirror=$root/var/cache/omarchy/mirror/offline

case ${1:?prepare, initramfs or finish} in
prepare)
    [[ -d $root/usr && ! -e $stage && -f $work/repo/$package ]]
    mkdir -p "$stage"
    cp -a "$work/native-final-t14-power/iso/boot/grub/grub.cfg" "$stage/grub.cfg"
    sed -i 's/quiet splash initramfs_async=0/rootdelay=30 console=tty0 loglevel=6 disablehooks=plymouth dragon.bootdiag=1 initramfs_async=0/' "$stage/grub.cfg"
    # mkarchiso removes /boot before packing its live root. Restore matching inputs.
    tar -xf "$mirror/linux-aarch64-7.2.6-1-aarch64.pkg.tar.xz" -C "$root" boot/Image boot/dtbs/qcom
    install -Dm755 configs/aarch64/customize_airootfs.sh "$root/root/customize_airootfs.sh"
    install -Dm755 configs/aarch64/live-uki.sh "$root/root/live-uki.sh"
    cp "$work/repo/$package" "$mirror/"
    mv "$mirror/omarchy-hw-snapdragon-early-experimental-0.2-1-any.pkg.tar.xz" "$stage/"
    ;;
initramfs)
    [[ $(uname -m) == aarch64 ]]
    repo-add "$mirror/offline.db.tar.gz" "$mirror/$package"
    mkdir -p "$root/var/lib/pacman/sync"
    cp -L "$mirror/offline.db" "$root/var/lib/pacman/sync/offline.db"
    # Suppress only the automatic initramfs transaction hook: customize runs it once.
    mask=$root/etc/pacman.d/hooks/90-mkinitcpio-install.hook
    [[ ! -e $mask && ! -L $mask ]]
    mkdir -p "${mask%/*}"
    ln -s /dev/null "$mask"
    trap 'rm -f "$mask"' EXIT
    "$root/usr/bin/arch-chroot" "$root" pacman -U --noconfirm "/var/cache/omarchy/mirror/offline/$package"
    rm "$mask"
    trap - EXIT
    "$root/usr/bin/arch-chroot" "$root" /root/customize_airootfs.sh
    "$root/usr/bin/arch-chroot" "$root" pacman -Q > "$stage/pkglist.aarch64.txt"
    "$root/usr/bin/arch-chroot" "$root" lsinitcpio /boot/initramfs-linux-aarch64.img > "$stage/initramfs-contents.txt"
    mv "$root/boot" "$stage/boot"
    mkdir -m755 "$root/boot"
    touch "$stage/initramfs-ready"
    ;;
finish)
    [[ -e $stage/initramfs-ready && ! -e $stage/airootfs.sfs ]]
    output=/repo/release/omarchy-dragon-t14-bootdiag-2026.09.21-aarch64.iso
    [[ ! -e $output ]]
    # Preserve the original Dragon compression and offline-package treatment.
    mksquashfs "$root" "$stage/airootfs.sfs" -noappend -comp xz -Xbcj arm -b 1M \
        -action 'uncompressed@subpathname(var/cache/omarchy/mirror/offline)'
    (cd "$stage" && sha512sum airootfs.sfs > airootfs.sha512)
    xorriso -indev /repo/release/omarchy-dragon-t14-power-2026.09.21-aarch64.iso \
        -outdev "$output" -boot_image any replay -volume_date uuid 2026092116355200 \
        -map "$stage/airootfs.sfs" /arch/aarch64/airootfs.sfs \
        -map "$stage/airootfs.sha512" /arch/aarch64/airootfs.sha512 \
        -map "$stage/boot/initramfs-linux-aarch64.img" /arch/boot/aarch64/initramfs-linux-aarch64.img \
        -map "$stage/boot/omarchy-live.efi" /arch/boot/aarch64/omarchy-live.efi \
        -map "$stage/grub.cfg" /boot/grub/grub.cfg \
        -map "$stage/pkglist.aarch64.txt" /arch/pkglist.aarch64.txt
    chown 1000:1000 "$output"
    ;;
*) exit 2 ;;
esac
