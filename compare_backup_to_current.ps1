# Script to compare backup files with current clean version
# Identifies files that differ and summarizes differences

$backupDir = "backup_recent_changes_20251119_165706"
$manifestPath = Join-Path $backupDir "backup_manifest.csv"
$reportPath = "backup_comparison_report.txt"
$diffSummaryPath = "backup_differences_summary.csv"

Write-Host "Comparing backup files with current version..." -ForegroundColor Green

# Read manifest
$manifest = Import-Csv $manifestPath
$results = @()
$identicalCount = 0
$differentCount = 0
$missingCount = 0

foreach ($item in $manifest) {
    # Fix backup path - remove leading .\ if present
    $backupPath = $item.BackupPath -replace '^\.\\', ''
    if (-not [System.IO.Path]::IsPathRooted($backupPath)) {
        $backupPath = Join-Path (Get-Location).Path $backupPath
    }
    
    $originalPath = $item.OriginalPath
    $currentPath = $originalPath
    
    # Skip if backup file doesn't exist
    if (-not (Test-Path $backupPath)) {
        Write-Host "  [WARN] Backup file missing: $backupPath" -ForegroundColor Yellow
        continue
    }
    
    # Check if current file exists
    if (-not (Test-Path $currentPath)) {
        $results += [PSCustomObject]@{
            File = $originalPath
            Status = "MISSING_IN_CURRENT"
            Difference = "File exists in backup but not in current version"
            LinesChanged = "N/A"
            IsLegacy = $item.IsLegacy
        }
        $missingCount++
        Write-Host "  ❌ Missing in current: $originalPath" -ForegroundColor Red
        continue
    }
    
    # Compare files
    $backupContent = Get-Content $backupPath -Raw -ErrorAction SilentlyContinue
    $currentContent = Get-Content $currentPath -Raw -ErrorAction SilentlyContinue
    
    if ($null -eq $backupContent) { $backupContent = "" }
    if ($null -eq $currentContent) { $currentContent = "" }
    
    # Normalize line endings for comparison
    $backupNormalized = $backupContent -replace "`r`n", "`n" -replace "`r", "`n"
    $currentNormalized = $currentContent -replace "`r`n", "`n" -replace "`r", "`n"
    
    if ($backupNormalized -eq $currentNormalized) {
        $identicalCount++
        Write-Host "  ✅ Identical: $originalPath" -ForegroundColor Gray
    } else {
        $differentCount++
        
        # Calculate line differences
        $backupLines = ($backupNormalized -split "`n").Count
        $currentLines = ($currentNormalized -split "`n").Count
        $lineDiff = $backupLines - $currentLines
        
        # Get a brief summary of differences (first few unique lines)
        $backupLinesArray = $backupNormalized -split "`n"
        $currentLinesArray = $currentNormalized -split "`n"
        
        # Find first difference
        $diffSummary = ""
        $maxCompare = [Math]::Min($backupLinesArray.Count, $currentLinesArray.Count)
        for ($i = 0; $i -lt $maxCompare; $i++) {
            if ($backupLinesArray[$i] -ne $currentLinesArray[$i]) {
                $diffSummary = "First difference at line $($i+1)"
                break
            }
        }
        
        if ($backupLines -ne $currentLines) {
            $diffSummary += " | Backup: $backupLines lines, Current: $currentLines lines"
        }
        
        $results += [PSCustomObject]@{
            File = $originalPath
            Status = "DIFFERENT"
            Difference = $diffSummary
            LinesChanged = $lineDiff
            IsLegacy = $item.IsLegacy
            BackupLines = $backupLines
            CurrentLines = $currentLines
        }
        
        $statusIcon = if ($item.IsLegacy -eq "True") { "[LEGACY]" } else { "[MODIFIED]" }
        Write-Host "  $statusIcon Different: $originalPath" -ForegroundColor Yellow
        Write-Host "      $diffSummary" -ForegroundColor DarkYellow
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
Total Files Compared: $($manifest.Count)
✅ Identical Files: $identicalCount (can be discarded)
📝 Different Files: $differentCount (need review)
❌ Missing in Current: $missingCount (new files in backup)

"@

# Add detailed differences
$report += "`nFILES WITH DIFFERENCES`n"
$report += "=" * 50 + "`n`n"

$differentFiles = $results | Where-Object { $_.Status -ne "MISSING_IN_CURRENT" -and $_.Status -eq "DIFFERENT" }
$missingFiles = $results | Where-Object { $_.Status -eq "MISSING_IN_CURRENT" }

if ($differentFiles.Count -gt 0) {
    $report += "Modified Files ($($differentFiles.Count)):`n`n"
    foreach ($file in $differentFiles) {
        $legacyNote = if ($file.IsLegacy -eq "True") { " [LEGACY DUPLICATE]" } else { "" }
        $report += "[MODIFIED] $($file.File)$legacyNote`n"
        $report += "   Status: $($file.Status)`n"
        $report += "   Difference: $($file.Difference)`n"
        $report += "   Lines: Backup=$($file.BackupLines), Current=$($file.CurrentLines), Diff=$($file.LinesChanged)`n`n"
    }
}

if ($missingFiles.Count -gt 0) {
    $report += "`nNew Files in Backup ($($missingFiles.Count)):`n`n"
    foreach ($file in $missingFiles) {
        $report += "[NEW] $($file.File)`n"
        $report += "   $($file.Difference)`n`n"
    }
}

# Save report
$report | Out-File $reportPath -Encoding UTF8

# Save CSV summary
$results | Export-Csv $diffSummaryPath -NoTypeInformation

Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "COMPARISON COMPLETE" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "[OK] Identical: $identicalCount files (can be discarded)" -ForegroundColor Green
Write-Host "[DIFF] Different: $differentCount files (need review)" -ForegroundColor Yellow
Write-Host "[NEW] Missing: $missingCount files (new in backup)" -ForegroundColor Red
Write-Host "`nReports saved:" -ForegroundColor Cyan
Write-Host "  - $reportPath" -ForegroundColor White
Write-Host "  - $diffSummaryPath" -ForegroundColor White

