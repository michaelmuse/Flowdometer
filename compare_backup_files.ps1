# Script to compare backup files with current clean version
# Identifies identical files (can discard) and different files (need to keep)

$backupDir = "backup_recent_changes_20251119_165706"
$manifest = Import-Csv "$backupDir\backup_manifest.csv"

$identicalFiles = @()
$differentFiles = @()
$missingFiles = @()
$backupMissingFiles = @()

Write-Host "Comparing $($manifest.Count) files..." -ForegroundColor Cyan
Write-Host ""

$processed = 0
foreach ($item in $manifest) {
    $backupPath = $item.BackupPath
    $originalPath = $item.OriginalPath
    
    # Fix backup path (remove leading .\ if present)
    if ($backupPath -like ".\*") {
        $backupPath = $backupPath.Substring(2)
    }
    $backupPath = Join-Path (Get-Location) $backupPath
    
    # Skip legacy duplicate files - we'll handle those separately
    if ($item.IsLegacy -eq "True") {
        continue
    }
    
    # Check if backup file exists
    if (-not (Test-Path $backupPath)) {
        $backupMissingFiles += [PSCustomObject]@{
            Path = $originalPath
            BackupPath = $backupPath
            Reason = "Backup file doesn't exist"
        }
        continue
    }
    
    # Check if current file exists
    if (-not (Test-Path $originalPath)) {
        $missingFiles += [PSCustomObject]@{
            Path = $originalPath
            BackupPath = $backupPath
            Reason = "File doesn't exist in current version"
            LastModified = $item.LastModified
        }
        continue
    }
    
    # Compare files using hash
    try {
        $backupHash = (Get-FileHash $backupPath -Algorithm MD5 -ErrorAction Stop).Hash
        $currentHash = (Get-FileHash $originalPath -Algorithm MD5 -ErrorAction Stop).Hash
        
        if ($backupHash -eq $currentHash) {
            $identicalFiles += [PSCustomObject]@{
                Path = $originalPath
                LastModified = $item.LastModified
            }
        } else {
            # Files are different - get diff summary
            try {
                $diffOutput = git diff --no-index --stat "$backupPath" "$originalPath" 2>&1 | Out-String
                $diffContent = git diff --no-index "$backupPath" "$originalPath" 2>&1 | Out-String
                
                # Count lines changed (excluding diff headers)
                $linesAdded = ($diffContent -split "`n" | Where-Object { $_ -match "^\+(?!\+{3})" }).Count
                $linesRemoved = ($diffContent -split "`n" | Where-Object { $_ -match "^\-(?!-{3})" }).Count
                
                # Extract summary line
                $summaryLine = ($diffOutput -split "`n" | Where-Object { $_ -match "^\s+\d+" } | Select-Object -First 1)
                if (-not $summaryLine) {
                    $summaryLine = "Files differ (binary or large file)"
                }
                
                $differentFiles += [PSCustomObject]@{
                    Path = $originalPath
                    BackupPath = $backupPath
                    LastModified = $item.LastModified
                    LinesAdded = $linesAdded
                    LinesRemoved = $linesRemoved
                    DiffSummary = $summaryLine.Trim()
                }
            } catch {
                # If git diff fails, files are still different
                $differentFiles += [PSCustomObject]@{
                    Path = $originalPath
                    BackupPath = $backupPath
                    LastModified = $item.LastModified
                    LinesAdded = "?"
                    LinesRemoved = "?"
                    DiffSummary = "Files differ (unable to calculate diff)"
                }
            }
        }
    } catch {
        Write-Warning "Error comparing $originalPath : $_"
    }
    
    $processed++
    if ($processed % 50 -eq 0) {
        Write-Host "  Processed $processed files..." -ForegroundColor Gray
    }
}

# Generate report
$report = @"
BACKUP COMPARISON REPORT
========================
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Backup Directory: $backupDir

SUMMARY
-------
Total Files in Backup: $($manifest.Count)
Files Processed: $processed
Identical Files (can discard): $($identicalFiles.Count)
Different Files (keep): $($differentFiles.Count)
Missing Files (not in current version): $($missingFiles.Count)
Backup Files Missing: $($backupMissingFiles.Count)

IDENTICAL FILES (Safe to Discard)
----------------------------------
These files are identical to the current version and can be safely removed from backup:

$($identicalFiles | ForEach-Object { "  - $($_.Path)" } | Out-String)

DIFFERENT FILES (Keep - Need Review)
------------------------------------
These files have differences and should be reviewed:

$($differentFiles | ForEach-Object { 
    "  - $($_.Path)`n    Modified: $($_.LastModified)`n    Changes: +$($_.LinesAdded) / -$($_.LinesRemoved) lines`n    Summary: $($_.DiffSummary)`n" 
} | Out-String)

MISSING FILES (Not in Current Version)
---------------------------------------
These files were in the backup but don't exist in the current clean version:

$($missingFiles | ForEach-Object { "  - $($_.Path) ($($_.Reason))" } | Out-String)

BACKUP FILES MISSING
--------------------
These files were listed in manifest but don't exist in backup directory:

$($backupMissingFiles | ForEach-Object { "  - $($_.Path)" } | Out-String)

"@

# Save report
$report | Out-File "$backupDir\COMPARISON_REPORT.txt" -Encoding UTF8

# Save detailed CSV
if ($differentFiles.Count -gt 0) {
    $differentFiles | Export-Csv "$backupDir\DIFFERENT_FILES.csv" -NoTypeInformation
}
if ($identicalFiles.Count -gt 0) {
    $identicalFiles | Export-Csv "$backupDir\IDENTICAL_FILES.csv" -NoTypeInformation
}
if ($missingFiles.Count -gt 0) {
    $missingFiles | Export-Csv "$backupDir\MISSING_FILES.csv" -NoTypeInformation
}

Write-Host ""
Write-Host $report -ForegroundColor Cyan
Write-Host "`nDetailed reports saved to:" -ForegroundColor Green
Write-Host "  - $backupDir\COMPARISON_REPORT.txt" -ForegroundColor Yellow
if ($differentFiles.Count -gt 0) {
    Write-Host "  - $backupDir\DIFFERENT_FILES.csv" -ForegroundColor Yellow
}
if ($identicalFiles.Count -gt 0) {
    Write-Host "  - $backupDir\IDENTICAL_FILES.csv" -ForegroundColor Yellow
}
if ($missingFiles.Count -gt 0) {
    Write-Host "  - $backupDir\MISSING_FILES.csv" -ForegroundColor Yellow
}
