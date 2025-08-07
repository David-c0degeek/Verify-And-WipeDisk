# Verify-And-WipeDisk.ps1

A **PowerShell script** for safely and securely verifying and wiping disks on Windows systems. Designed for reusability, safety, and ease of use, this script allows you to:

- View all connected disks and key details
- Interactively select a disk to inspect and optionally wipe
- Clear the partition table (`Clear-Disk`)
- Overwrite the first 1GB with zeroes (destroys headers like LUKS)
- Perform a post-wipe verification to confirm the disk is clean

---

## 🛡️ Use Cases

- Preparing encrypted drives (e.g. LUKS on Unraid) for **RMA**
- Securely wiping disks without full-disk overwriting
- Validating that disks have **no partitions, volumes, or data remnants**
- Quickly destroying boot sectors, partition tables, and headers

---

## 🧰 Requirements

- **Windows 10/11**
- PowerShell (v5+)
- Must run as **Administrator**
- Disk must be **directly attached** (USB or internal)

---

## 🚀 How to Use

1. Download `Verify-And-WipeDisk.ps1`
2. **Right-click → Run with PowerShell as Administrator**
3. Follow on-screen prompts:

   - View all connected disks
   - Enter disk number to inspect
   - Confirm if you want to wipe it
   - Script will:
     - Clear partition table
     - Zero first 1GB
     - Verify no partitions, volumes
     - Confirm first 512 bytes are zeroed

## ⚡ Quick Start (Remote Run)

Run the script directly from PowerShell (must be run as Administrator):

```powershell
irm https://raw.githubusercontent.com/David-c0degeek/Verify-And-WipeDisk/main/Verify-And-WipeDisk.ps1 | iex
```
---

## ⚠️ Warnings

- This script **permanently deletes data**. There is **no undo**.
- Always **double-check the disk number** before confirming.
- Does **not** wipe the full drive (only clears partition table + 1GB).

---

## 🔒 Security Note

This script is ideal for wiping **LUKS-encrypted drives** (e.g. from Unraid). Overwriting the LUKS header and partition table renders the data unrecoverable even with advanced tools.

---

## 📝 License

MIT License. Use at your own risk.
