# Script to compare backup files with current clean version
# Uses actual files found in backup directory

$backupDir = "backup_recent_changes_20251119_165706"
$manifest = Import-Csv "$backupDir\backup_manifest.csv"

# Get all actual files in backup directory (excluding report files)
$backupFiles = Get-ChildItem "$backupDir" -Recurse -File | Where-Object { 
    $_.Name -notlike "*.csv" -and 
    $_.Name -notlike "*REPORT*.txt" -and 
    $_.Name -notlike "*SUMMARY*.txt" 
}

Write-Host "Found $($backupFiles.Count) actual files in backup directory" -ForegroundColor Cyan
Write-Host "Comparing with current version..." -ForegroundColor Cyan
Write-Host ""

$identicalFiles = @()
$differentFiles = @()
$missingFiles = @()

$processed = 0
foreach ($backupFile in $backupFiles) {
    # Get relative path from backup directory
    $relativePath = $backupFile.FullName.Replace((Resolve-Path $backupDir).Path + "\", "")
    
    # Find corresponding entry in manifest
    $manifestEntry = $manifest | Where-Object { 
        $_.OriginalPath -eq $relativePath -or 
        $_.BackupPath -like "*$relativePath" 
    } | Select-Object -First 1
    
    # Determine current file path
    $currentPath = $relativePath
    
    # Check if current file exists
    if (-not (Test-Path $currentPath)) {
        $missingFiles += [PSCustomObject]@{
            Path = $currentPath
            BackupPath = $backupFile.FullName
            Reason = "File doesn't exist in current version"
            LastModified = if ($manifestEntry) { $manifestEntry.LastModified } else { "Unknown" }
        }
        continue
    }
    
    # Compare files using hash
    try {
        $backupHash = (Get-FileHash $backupFile.FullName -Algorithm MD5 -ErrorAction Stop).Hash
        $currentHash = (Get-FileHash $currentPath -Algorithm MD5 -ErrorAction Stop).Hash
        
        if ($backupHash -eq $currentHash) {
            $identicalFiles += [PSCustomObject]@{
                Path = $currentPath
                LastModified = if ($manifestEntry) { $manifestEntry.LastModified } else { "Unknown" }
            }
        } else {
            # Files are different - get diff summary
            try {
                $diffOutput = git diff --no-index --stat "$($backupFile.FullName)" "$currentPath" 2>&1 | Out-String
                $diffContent = git diff --no-index "$($backupFile.FullName)" "$currentPath" 2>&1 | Out-String
                
                # Count lines changed (excluding diff headers)
                $linesAdded = ($diffContent -split "`n" | Where-Object { $_ -match "^\+(?!\+{3})" }).Count
                $linesRemoved = ($diffContent -split "`n" | Where-Object { $_ -match "^\-(?!-{3})" }).Count
                
                # Extract summary line
                $summaryLine = ($diffOutput -split "`n" | Where-Object { $_ -match "^\s+\d+" } | Select-Object -First 1)
                if (-not $summaryLine -or $summaryLine -match "error") {
                    $summaryLine = "Files differ (binary or large file)"
                }
                
                $differentFiles += [PSCustomObject]@{
                    Path = $currentPath
                    BackupPath = $backupFile.FullName
                    LastModified = if ($manifestEntry) { $manifestEntry.LastModified } else { "Unknown" }
                    LinesAdded = $linesAdded
                    LinesRemoved = $linesRemoved
                    DiffSummary = $summaryLine.Trim()
                }
            } catch {
                # If git diff fails, files are still different
                $differentFiles += [PSCustomObject]@{
                    Path = $currentPath
                    BackupPath = $backupFile.FullName
                    LastModified = if ($manifestEntry) { $manifestEntry.LastModified } else { "Unknown" }
                    LinesAdded = "?"
                    LinesRemoved = "?"
                    DiffSummary = "Files differ (unable to calculate diff: $($_.Exception.Message))"
                }
            }
        }
    } catch {
        Write-Warning "Error comparing $currentPath : $_"
    }
    
    $processed++
    if ($processed % 20 -eq 0) {
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
Total Files in Backup Directory: $($backupFiles.Count)
Files Processed: $processed
Identical Files (can discard): $($identicalFiles.Count)
Different Files (keep): $($differentFiles.Count)
Missing Files (not in current version): $($missingFiles.Count)

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

