# Helper function to format bytes to GB
function Format-SizeGB ($bytes) {
    return "{0:N2}" -f ($bytes / 1GB)
}

# Step 1: Show all disks
Write-Host "`n=== Available Disks ===" -ForegroundColor Cyan
Get-Disk | Sort-Object Number | Format-Table -AutoSize Number FriendlyName SerialNumber Size HealthStatus OperationalStatus PartitionStyle

# Step 2: Prompt for disk selection
$diskNumber = Read-Host "`nEnter the disk number you want to verify and optionally wipe"

# Step 3: Validate disk exists
try {
    $disk = Get-Disk -Number $diskNumber -ErrorAction Stop
} catch {
    Write-Host "`n❌ Invalid disk number or disk not found." -ForegroundColor Red
    exit 1
}

# Step 4: Gather info
$partitions = Get-Partition -DiskNumber $diskNumber -ErrorAction SilentlyContinue
$volumes = Get-Volume -DiskNumber $diskNumber -ErrorAction SilentlyContinue

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

        Write-Host "Writing 1GB of zeroes to start of disk..." -ForegroundColor Yellow
        $stream = [System.IO.File]::OpenWrite("\\.\PhysicalDrive$diskNumber")
        $block = [byte[]]::new(1024 * 1024)  # 1MB buffer
        for ($i = 0; $i -lt 1024; $i++) {
            $stream.Write($block, 0, $block.Length)
        }
        $stream.Close()
        Write-Host "✅ First 1GB overwritten with zeroes." -ForegroundColor Green

        # --- POST-WIPE VERIFICATION ---
        Write-Host "`nVerifying wipe..." -ForegroundColor Cyan
        $disk = Get-Disk -Number $diskNumber
        $partitions = Get-Partition -DiskNumber $diskNumber -ErrorAction SilentlyContinue
        $volumes = Get-Volume -DiskNumber $diskNumber -ErrorAction SilentlyContinue

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
        Write-Host "`n❌ Wipe failed: $_" -ForegroundColor Red
    }
} else {
    Write-Host "`n❎ Wipe cancelled. No changes made to disk $diskNumber." -ForegroundColor Gray
}
