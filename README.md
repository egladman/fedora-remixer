# Fedora Remixer

Fedora remix builder written in Ansible and POSIX shell. Fork and modify the
ansible playbook to your heart's content.

## Dependencies

- squashfs-tools
- mkisofs
- ansible

## Setup

```
ansible-galaxy install -r ansible/requirements.yml
```

## Build

*Note:* Elevated privileges are required since we're using chroots, and mounting loop devices.

| Environment Variable     | Description                                        | Default Value | Available Values                   |
|--------------------------|----------------------------------------------------|---------------|------------------------------------|
| RMX_OUTPUT_DIR           | Directory to save built iso                        | `""`          |                                    |
| RMX_LIVE_PREFIX          | Directory where squashfs and rootfs `.img` reside  | `LiveOS`      |                                    |
| RMX_SQUASHFS_COMPRESSION | Compression type used by `mksquashfs`              | `xz`          | `gzip`, `lzma`, `lzo`, `lz4`, `xz` |
| RMX_ANSIBLE_TAGS         | Custom image be specifying additional ansible tags | `core`        | `core`, `core,devel`               |

### Gnome

#### Core

```
sudo ./main.sh <path/to/iso>
```

#### Devel

```
sudo RMX_ANSIBLE_TAGS="core,devel" ./main.sh <path/to/iso>
```

### i3

#### Core

```
sudo RMX_ANSIBLE_TAGS="core,i3" ./main.sh <path/to/iso>
```

#### Devel

```
sudo RMX_ANSIBLE_TAGS="core,i3,devel" ./main.sh <path/to/iso>
```

### Sway

#### Core

```
sudo RMX_ANSIBLE_TAGS="core,sway" ./main.sh <path/to/iso>
```

#### Devel

```
sudo RMX_ANSIBLE_TAGS="core,sway,devel" ./main.sh <path/to/iso>
```

## Cleanup

```
sudo rm -rf .cache
```

## Example

```
wget https://download.fedoraproject.org/pub/fedora/linux/releases/36/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-36-1.5.iso
sudo ./main.sh Fedora-Workstation-Live-x86_64-36-1.5.iso
```

*Note:* File `Fedora-Workstation-Live-x86_64-36-1.5.remix.iso` will be written to the working directory.

## Troubleshooting

1. `rm: cannot remove '.cache/rootfs': Device or resource busy`

  ```
  sudo umount .cache/rootfs
  ```

2. To manually mount the `rootfs.img` run the following. It is automatically unmounted when the script exits:

  ```
  sudo mount -o loop .cache/squashfs/LiveOS/rootfs.img .cache/rootfs
  ```
