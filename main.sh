#!/usr/bin/env sh

set -e

trap cleanup ERR

# RMX_OUTPUT_DIR
# RMX_LIVE_PREFIX
# RMX_SQUASHFS_COMPRESSION
# RMX_ANSIBLE_TAGS

RMX_LIVE_PREFIX="${RMX_LIVE_PREFIX:-LiveOS}"
RMX_ANSIBLE_TAGS="${RMX_ANSIBLE_TAGS:-core}"

iso_path="${1:?}"
iso_label="$(isoinfo -d -i "$iso_path" | sed -n 's/Volume id: //p')"
ansible_path="${PWD:?}/ansible"
cache_path="${PWD:?}/.cache"
mount_path="${cache_path}/mnt"
disk_path="${cache_path}/disk" # Extracted iso contents
squashfs_root_path="${cache_path}/squashfs" # Uncompressed squashfs
root_path="${cache_path}/rootfs"

skip_unpack=0

log() {
    # Usage: log "message"
    printf '>>  %s\n' "$*"
}

cleanup() {
    # Usage: cleanup
    log "Cleaning up"
    umount "$mount_path" || true
    umount "$root_path" || true

    rm -f "${root_path}/etc/resolv.conf"
}

prep() {
    if [ -d "$root_path" -a -s "$root_path" ]; then
        skip_unpack=1
    fi

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

post() {
    if [ -z "$SUDO_USER" ]; then
        return
    fi

    log "Fixing permissions for path '${cache_path}'"
    chown ${SUDO_USER}:${SUDO_USER} "$cache_path" "$root_path"
}

image_unpack() {
    if [ $skip_unpack -eq 1 ]; then
        log "Skipping unpacking"
        return
    fi

    log "Mounting iso '${iso_path}' to path '${mount_path}'"
    mount -t iso9660 -o loop "$iso_path" "$mount_path"

    log "Entering directory '${mount_path}'"
    pushd "$mount_path"

    log "Unpacking to path '$disk_path'"
    tar cf - . | (cd "$disk_path"; tar xfp -)

    log "Leaving directory '${mount_path}'"
    popd

    log "Unmounting path '${mount_path}'"
    umount "$mount_path"

    log "Uncompressing squashfs image '${disk_path}/${RMX_LIVE_PREFIX}/squashfs.img' to path '${squashfs_root_path}'"
    unsquashfs -dest "${squashfs_root_path}" "${disk_path}/${RMX_LIVE_PREFIX}/squashfs.img"

    log "Mounting rootfs image '${squashfs_root_path}/${RMX_LIVE_PREFIX}/rootfs.img' to path '${root_path}'"
    mount -o loop "${squashfs_root_path}/${RMX_LIVE_PREFIX}/rootfs.img" "$root_path"
}

image_repack() {
    # Mounted in previous step
    log "Unmounting path '${root_path}'"
    umount "$root_path" || true

    log "Creating squashfs from path '${root_path}'"
    mksquashfs "${squashfs_root_path}" "${cache_path}/squashfs.img" -noappend -always-use-fragments -comp ${RMX_SQUASHFS_COMPRESSION:-xz}

    log "Overwritting existing squashfs image"
    mv -f "${cache_path}/squashfs.img" "${disk_path}/${RMX_LIVE_PREFIX}/squashfs.img"

    iso_custom_path="$(basename "${iso_path%%.iso}.remix.iso")"
    if [ -n "$RMX_OUTPUT_DIR" ]; then # Save the remixed iso the same parent dir
        iso_custom_path="${RMX_OUTPUT_DIR}/${iso_custom_path}"
    fi

    # FIXME
    # Dracut will throw an error during boot, because it expects the original iso label i.e, Fedora-WS-Live-<major>-<minor>-<patch>
    # For now we'll duplicate the source iso label

    log "Creating iso from path '${disk_path}'"
    mkisofs -o "$iso_custom_path" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -R -V "$iso_label" "$disk_path"

    if [ -n "$SUDO_USER" ]; then
        log "Fixing permissions for path '${iso_custom_path}'"
        chown ${SUDO_USER}:${SUDO_USER} "$iso_custom_path"
    fi

    log "Created iso '$iso_custom_path'"
}

image_modify() {
    log "Entering directory '${ansible_path}'"
    pushd "$ansible_path"

    # FIXME
    # Remove rsync dependency

    # Allows the chroot to resolve DNS
    log "Duplicating host resolv.conf to path '${root_path}/etc/resolv.conf'"
    rsync -L --verbose /etc/resolv.conf "${root_path}/etc/"


    if [ -n "$SUDO_USER" ]; then
        # This is necessary since we're running the script as root, and the
        # ansible looks for modules/collections in the current user's home.
        # Run the following to learn more:
        #   ansible-config dump | grep DEFAULT_MODULE_PATH
        #   ansible-config dump | grep COLLECTION_PATHS
        log "Overriding Ansible default paths for modules and collections"
        export ANSIBLE_LIBRARY="/home/${SUDO_USER}/.ansible/plugins/modules:/usr/share/ansible/plugins/modules"
        export ANSIBLE_COLLECTIONS_PATHS="/home/${SUDO_USER}/.ansible/collections:/usr/share/ansible/collections"
    fi

    log "Running ansible"
    ansible-playbook --connection=chroot --inventory "${root_path}," --tags "${RMX_ANSIBLE_TAGS}" site.yml

    log "Removing path '${root_path}/etc/resolv.conf'"
    rm -f "${root_path}/etc/resolv.conf"

    log "Leaving directory '${ansible_path}'"
    popd
}

main() {
    prep
    image_unpack
    image_modify
    image_repack
    post
}

main
