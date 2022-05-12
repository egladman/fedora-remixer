#!/usr/bin/env sh

set -e

trap cleanup ERR

# REMIXER_OUTPUT_DIR
# REMIXER_SQUASHFS_COMPRESSION

iso_path="${1:?}"
iso_squashfs_prefix=LiveOS
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

    log "Uncompressing squashfs image '${disk_path}/${REMIXER_ISO_SQUASHFS_PREFIX:-$iso_squashfs_prefix}/squashfs.img' to path '${root_path}'"
    unsquashfs -dest "${root_path}" "${disk_path}/${REMIXER_ISO_SQUASHFS_PREFIX:-$iso_squashfs_prefix}/squashfs.img"
}

image_repack() {
    log "Creating squashfs from path '${root_path}'"
    mksquashfs "${root_path}" "${cache_path}/squashfs.img" -noappend -always-use-fragments -comp ${REMIXER_SQUASHFS_COMPRESSION:-xz}

    log "Overwritting existing squashfs image"
    mv -f "${cache_path}/squashfs.img" "${disk_path}/${REMIXER_ISO_SQUASHFS_PREFIX:-$iso_squashfs_prefix}/squashfs.img"

    iso_custom_path="$(basename "${iso_path%%.iso}.remix.iso")"
    if [ -n "$REMIXER_OUTPUT_DIR" ]; then # Save the remixed iso the same parent dir
        iso_custom_path="${REMIXER_OUTPUT_DIR}/${iso_custom_path}"
    fi

    log "Creating iso from path '${disk_path}'"
    mkisofs -o "$iso_custom_path" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V "Custom Remix" "$disk_path"

    if [ -n "$SUDO_USER" ]; then
        log "Fixing permissions"
        chown ${SUDO_USER}:${SUDO_USER} "$iso_custom_path"
    fi

    log "Created iso '$iso_custom_path'"
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
