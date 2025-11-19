#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
# The base device names for the partitions that will form the RAID array.
readonly TARGET_PARTITIONS=("nvme0n1p3" "nvme1n1p3" "nvme2n1p3")
# The name of the mdadm device to create.
readonly MD_DEVICE="/dev/md0"
# The RAID level to use.
readonly RAID_LEVEL=5

# --- Script ---
PARTUUID_PATHS=()

echo "--- Locating PARTUUIDs for target partitions ---"

for partition in "${TARGET_PARTITIONS[@]}"; do
  device_path="/dev/${partition}"

  # Check if the block device exists
  if [[ ! -b "$device_path" ]]; then
    echo "Error: Partition ${device_path} not found. Aborting." >&2
    exit 1
  fi

  # Get the PARTUUID for the current partition
  partuuid=$(lsblk -no PARTUUID "$device_path")

  if [[ -z "$partuuid" ]]; then
    echo "Error: Could not find PARTUUID for ${device_path}." >&2
    echo "Please ensure the disk is partitioned with GPT." >&2
    exit 1
  fi

  echo "Found ${device_path} -> ${partuuid}"
  PARTUUID_PATHS+=("/dev/disk/by-partuuid/${partuuid}")
done

echo ""
echo "--- Ready to create mdadm array ---"

# Check if we found all the required partitions
if [[ "${#PARTUUID_PATHS[@]}" -ne "${#TARGET_PARTITIONS[@]}" ]]; then
  echo "Error: Expected ${#TARGET_PARTITIONS[@]} partitions, but only found ${#PARTUUID_PATHS[@]}." >&2
  exit 1
fi

# Construct and display the command that will be run
# The --run flag is important to start the array immediately after creation
mdadm_cmd="mdadm --create ${MD_DEVICE} --level=${RAID_LEVEL} --raid-devices=${#TARGET_PARTITIONS[@]} --run ${PARTUUID_PATHS[*]}"

echo "The following command will be executed:"
echo "$mdadm_cmd"
echo ""
read -p "Do you want to proceed with creating the array? (y/N) " -n 1 -r
echo "" # Move to a new line

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "User aborted."
  exit 1
fi

# Execute the mdadm command with sudo
if command -v sudo &> /dev/null; then
  sudo bash -c "$mdadm_cmd"
else
  # Fallback for environments without sudo (like a root shell in the installer)
  bash -c "$mdadm_cmd"
fi


echo ""
echo "--- mdadm array ${MD_DEVICE} created successfully! ---"
echo "You can now proceed with creating the BTRFS filesystem on ${MD_DEVICE}."

