# Fedora Remixer

Fedora remix builder written in Ansible and POSIX shell. Fork and modify the
ansible playbooks to your heart's content.

## Dependencies

- squashfs-tools
- mkisofs
- ansible

## Build

```
sudo ./main.sh <path/to/iso>
```

*Note:* Elevated privileges are required since we're using chroots, and mounting loop devices.

## Cleanup

```
sudo rm -rf .cache
```

## Example

```
wget https://download.fedoraproject.org/pub/fedora/linux/releases/36/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-36-1.5.iso
sudo ./main.sh Fedora-Workstation-Live-x86_64-36-1.5.iso
```

*Note:* File `Fedora-Workstation-Live-x86_64-36-1.5.remix.iso` will be written to the working directory. This behavior can be overridden by setting environment variable `REMIXER_OUTPUT_DIR`.
