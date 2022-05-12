#!/usr/bin/env sh

set -e

trap cleanup ERR

iso_path="${1:?}"
cache_path="${PWD:?}/.cache"
mount_path="${cache_path}/mnt"
disk_path="${cache_path}/disk"
root_path="${cache_path}/rootfs"

log() {
    # Usage: log "message"
    printf '>>  %s\n' "$*"
}

cleanup() {
    # Usage: cleanup
    log "Unmounting path '${mount_path}'"
    umount "$mount_path"
}

prep() {
    if [ ! -d "$cache_path" ]; then
        log "Creating directory '$cache_path'"
        mkdir -p "$cache_path"
    fi

    if [ ! -d "$root_path" ]; then
        log "Creating directory '$root_path'"
        mkdir -p "$root_path"
    fi

    if [ ! -d "$disk_path" ]; then
        log "Creating directory '$disk_path'"
        mkdir -p "$disk_path"
    fi

    if [ ! -d "$mount_path" ]; then
        log "Creating directory '$mount_path'"
        mkdir -p "$mount_path"
    fi
}

image_unpack() {
    log "Mounting iso '${iso_path}' to path '${mount_path}'"
    mount -t iso9660 -o loop "$iso_path" "$mount_path"

    log "Entered directory '${mount_path}'"
    pushd "$mount_path"

    log "Unpacking to path '$disk_path'"
    tar cf - . | (cd "$disk_path"; tar xfp -)

    log "Leaving directory '${mount_path}'"
    popd

    cleanup

    log "Uncompressing squashfs image '${disk_path}/LiveOS/squashfs.img' to path '${root_path}'"
    unsquashfs -dest "${root_path}" "${disk_path}/LiveOS/squashfs.img"
}

image_repack() {
    log "Creating squashfs from path '${root_path}'"
    mksquashfs "${root_path}" "${cache_path}/squashfs.img" -noappend -always-use-fragments

    log "Overwritting existing squashfs image"
    mv -f "${cache_path}/squashfs.img" "${disk_path}/LiveOS/squashfs.img"

    log "Creating iso from path '${disk_path}'"
    mkisofs -o "${iso_path%%.iso}.remix.iso" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V "Custom Remix" "$disk_path"

    if [ -n "$SUDO_USER" ]; then
        log "Fixing permissions"
        chown ${SUDO_USER}:${SUDO_USER} "${iso_path%%.iso}.remix.iso"
    fi

    log "Created ${iso_path%%.iso}.remix.iso"
}

image_modify() {
    # todo
    true
}

main() {
    prep
    image_unpack
    image_modify
    image_repack
}

main
