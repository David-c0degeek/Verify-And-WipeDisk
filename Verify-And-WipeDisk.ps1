# Helper function to format bytes to GB
function Format-SizeGB ($bytes) {
    return "{0:N2}" -f ($bytes / 1GB)
}

# Step 1: Show all disks
Write-Host "`n=== Available Disks ===" -ForegroundColor Cyan
Get-Disk | Sort-Object Number | Format-Table -AutoSize -Property Number, FriendlyName, SerialNumber, Size, HealthStatus, OperationalStatus, PartitionStyle

# Step 2: Prompt for disk selection
Write-Host "`nEnter the disk number you want to verify and optionally wipe: " -NoNewline
$diskNumber = Read-Host

# Step 3: Validate disk exists
try {
    $disk = Get-Disk -Number $diskNumber -ErrorAction Stop
} catch {
    Write-Host "`n❌ Invalid disk number or disk not found." -ForegroundColor Red
    exit 1
}

# Step 4: Gather info
$partitions = Get-Partition -DiskNumber $diskNumber -ErrorAction SilentlyContinue
$volumes = Get-Volume | Where-Object {
    $_.ObjectId -match "Harddisk$diskNumber"
}

# Step 5: Show disk info
Write-Host "`n=== Disk Verification ===" -ForegroundColor Cyan
Write-Host "Disk Number: $($disk.Number)"
Write-Host "Friendly Name: $($disk.FriendlyName)"
Write-Host "Serial Number: $($disk.SerialNumber)"
Write-Host "Size: $(Format-SizeGB $disk.Size) GB"
Write-Host "Partition Style: $($disk.PartitionStyle)"
Write-Host "Operational Status: $($disk.OperationalStatus)"
Write-Host "Health Status: $($disk.HealthStatus)"

if (!$partitions) {
    Write-Host "`n✅ No partitions found. Disk is clean." -ForegroundColor Green
} else {
    Write-Host "`n⚠️ Partitions detected:" -ForegroundColor Yellow
    $partitions | Format-Table
}

if (!$volumes) {
    Write-Host "✅ No volumes found. Nothing is mounted." -ForegroundColor Green
} else {
    Write-Host "⚠️ Volumes detected:" -ForegroundColor Yellow
    $volumes | Format-Table
}

# Step 6: Ask if user wants to wipe the disk
$confirm = Read-Host "`nDo you want to securely wipe this disk (Clear-Disk + zero first 1GB)? Type YES to proceed"
if ($confirm -eq "YES") {
    try {
        Write-Host "`n⚠️ Wiping disk $diskNumber using Clear-Disk..." -ForegroundColor Red
        Clear-Disk -Number $diskNumber -RemoveData -Confirm:$false
        Write-Host "✅ Partition table cleared."

        # Try zeroing first 1GB using raw write
        try {
            Write-Host "Writing 1GB of zeroes to start of disk..." -ForegroundColor Yellow
            $stream = [System.IO.File]::OpenWrite("\\.\PhysicalDrive$diskNumber")
            $block = [byte[]]::new(1024 * 1024)
            for ($i = 0; $i -lt 1024; $i++) {
                $stream.Write($block, 0, $block.Length)
            }
            $stream.Close()
            Write-Host "✅ First 1GB overwritten with zeroes." -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed to write to \\.\PhysicalDrive$diskNumber. Checking if this is a USB disk..." -ForegroundColor Red

            # Try to detect if disk is USB
            try {
                $diskInterface = (Get-PnpDevice -PresentOnly | Where-Object {
                    $_.Class -eq "DiskDrive" -and $_.FriendlyName -like "*$($disk.FriendlyName)*"
                }).FriendlyName

                if ($diskInterface -match "USB") {
                    Write-Host "💡 Disk appears to be a USB device — raw writes are usually blocked." -ForegroundColor Yellow
                    $tryDiskpart = Read-Host "Do you want to use 'diskpart clean' to wipe this disk instead? Type YES to proceed"

                    if ($tryDiskpart -eq "YES") {
                        Write-Host "`n🧹 Running 'diskpart clean' on disk $diskNumber..." -ForegroundColor Yellow

                        $diskpartScript = @"
select disk $diskNumber
clean
"@
                        $diskpartScript | diskpart

                        Write-Host "✅ 'diskpart clean' completed. Partition table wiped." -ForegroundColor Green
                    } else {
                        Write-Host "❎ Skipped 'diskpart'. No overwrite was performed." -ForegroundColor Gray
                    }
                } else {
                    Write-Host "⚠️ Disk interface is not USB, but raw write still failed. Consider running 'diskpart' manually." -ForegroundColor Yellow
                }
            } catch {
                Write-Host "⚠️ Could not determine disk interface or run diskpart fallback. $_" -ForegroundColor DarkRed
            }
        }

        # --- POST-WIPE VERIFICATION ---
        Write-Host "`nVerifying wipe..." -ForegroundColor Cyan
        $disk = Get-Disk -Number $diskNumber
        $partitions = Get-Partition -DiskNumber $diskNumber -ErrorAction SilentlyContinue
        $volumes = Get-Volume | Where-Object {
            $_.ObjectId -match "Harddisk$diskNumber"
        }

        Write-Host "`n=== Post-Wipe Disk Status ===" -ForegroundColor Cyan
        Write-Host "Partition Style: $($disk.PartitionStyle)"
        Write-Host "Health Status: $($disk.HealthStatus)"
        Write-Host "Operational Status: $($disk.OperationalStatus)"

        if (!$partitions) {
            Write-Host "✅ No partitions found." -ForegroundColor Green
        } else {
            Write-Host "⚠️ Partitions detected (wipe may have failed):" -ForegroundColor Yellow
            $partitions | Format-Table
        }

        if (!$volumes) {
            Write-Host "✅ No volumes found." -ForegroundColor Green
        } else {
            Write-Host "⚠️ Volumes still present:" -ForegroundColor Yellow
            $volumes | Format-Table
        }

        # Read first 512 bytes to confirm zeroing
        Write-Host "`nReading first 512 bytes for zero check..." -ForegroundColor Cyan
        try {
            $file = [System.IO.File]::OpenRead("\\.\PhysicalDrive$diskNumber")
            $buffer = [byte[]]::new(512)
            $file.Read($buffer, 0, 512) | Out-Null
            $file.Close()
            $allZero = $buffer -eq 0

            if ($allZero -notcontains $false) {
                Write-Host "✅ First 512 bytes are all zero. Header successfully destroyed." -ForegroundColor Green
            } else {
                Write-Host "❌ First 512 bytes are not zero. Overwrite failed or incomplete." -ForegroundColor Red
            }
        } catch {
            Write-Host "⚠️ Could not read first 512 bytes (probably blocked on USB disk)." -ForegroundColor Yellow
        }

    } catch {
        Write-Host "`n❌ Wipe failed: $_" -ForegroundColor Red
    }
} else {
    Write-Host "`n❎ Wipe cancelled. No changes made to disk $diskNumber." -ForegroundColor Gray
}
