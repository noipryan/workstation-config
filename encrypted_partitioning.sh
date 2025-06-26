#!/usr/bin/env bash

# Stop on error
set -e

DISK=$(lsblk -o NAME,TYPE | grep -v zram | awk '$2=="disk" {print "/dev/"$1}')

#DISK=$1

MAPPER="/dev/mapper/fedora"

if [[ "$DISK" == *"nvme"* ]]; then

  PART="${DISK}p"

else

  PART=$DISK

fi

# Undo any previous changes.
# This allows me to re-run the script many times over
set +e
umount -R /mnt
cryptsetup close "${MAPPER}"
vgchange -an
set -e

echo "Partitoning encrypted UEFI Disk"

echo "Erasing all partitions on ${DISK}"
wipefs -a $DISK

#echo "Erasing mbr with dd"
#dd if=/dev/zero of=$DISK bs=1M count=1

echo "Creating GPT partition table"
parted -s $DISK -- mklabel gpt

echo "Creating ESP partition"
parted -s $DISK -- mkpart ESP fat32 1MiB 600MiB
parted -s $DISK -- set 1 boot on

sleep 1

mkfs.fat -F32 -n EFI "${PART}1"

echo "Creating boot partition"
parted -s $DISK -- mkpart boot 600MiB 1600MiB

sleep 1

mkfs.ext4 -L boot "${PART}2"

echo "Creating Data partition"
parted -s $DISK -- mkpart fedora 1600MiB 100%

sleep 1

# Create encrypted volume
echo "Creating encrypted volume"
cryptsetup -y -v -q luksFormat "${PART}3"
cryptsetup open "${PART}3" fedora

# Format encrypted volume to btrfs

echo "Formating ${MAPPER} to BTRFS"
mkfs.btrfs -f -L fedora "${MAPPER}"

sleep 2

echo "Creating btrfs subvolumes"
mount "${MAPPER}" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
umount /mnt

sleep 2

echo "Mounting boot and btrfs subvolumes for installation"
mount -o noatime,compress=zstd:1,subvol=@ ${MAPPER} /mnt
mkdir -p /mnt/{boot/efi,home}
mount /dev/disk/by-label/boot /mnt/boot
sleep 1
mount /dev/disk/by-label/EFI /mnt/boot/efi
sleep 1
mount -o compress=zstd:1,subvol=@home ${MAPPER} /mnt/home

echo "Partitioned GPT disk and mounted to /mnt for installation"
