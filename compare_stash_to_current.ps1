# Script to compare stashed changes with current clean version
# This will identify which files differ and summarize differences

$stashName = "stash@{0}"
$reportPath = "stash_comparison_report.txt"
$diffSummaryPath = "stash_differences_summary.csv"

Write-Host "Comparing stashed changes with current version..." -ForegroundColor Green

# Get list of files in stash
$stashFiles = git stash show --name-only $stashName 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Could not read stash. Trying alternative method..." -ForegroundColor Red
    $stashFiles = git stash show --name-only 2>&1
}

if ($LASTEXITCODE -ne 0 -or $stashFiles.Count -eq 0) {
    Write-Host "No stash found or stash is empty." -ForegroundColor Yellow
    exit
}

$results = @()
$identicalCount = 0
$differentCount = 0
$newFilesCount = 0

foreach ($filePath in $stashFiles) {
    if ([string]::IsNullOrWhiteSpace($filePath)) { continue }
    
    $filePath = $filePath.Trim()
    
    # Skip .history files - they're VSCode history and not important
    if ($filePath -like ".history/*") {
        continue
    }
    
    # Check if file exists in current version
    $existsInCurrent = Test-Path $filePath
    
    if (-not $existsInCurrent) {
        # New file in stash
        $results += [PSCustomObject]@{
            File = $filePath
            Status = "NEW_IN_STASH"
            Difference = "File exists in stash but not in current version"
            LinesChanged = "N/A"
            IsLegacy = ($filePath -like "*\classes\*.cls" -and $filePath -notlike "*\classes\*\*.cls")
        }
        $newFilesCount++
        Write-Host "  [NEW] New file in stash: $filePath" -ForegroundColor Cyan
        continue
    }
    
    # Get the file content from stash using git show
    # Use proper escaping for PowerShell with stash@{0}
    $stashRef = 'stash@{0}:' + $filePath
    $stashContent = & git show $stashRef 2>&1
    $stashExitCode = $LASTEXITCODE
    
    if ($stashExitCode -ne 0) {
        # If git show fails, try with quotes around the whole reference
        $stashContent = & git show "stash@{0}:$filePath" 2>&1
        $stashExitCode = $LASTEXITCODE
    }
    
    if ($stashExitCode -ne 0) {
        # If still failing, try to extract from diff for new files
        $diffOutput = git stash show -p $stashName -- "$filePath" 2>&1
        if ($diffOutput -match '^\+\+\+.*dev/null' -or $diffOutput -match '^\+\+\+.*\/dev\/null') {
            # This is a new file, extract all added lines
            $stashLines = $diffOutput | Where-Object { 
                $_ -match '^\+(?!\+{2}|\@)' 
            } | ForEach-Object { 
                $_.Substring(1) 
            }
            $stashContent = $stashLines -join "`n"
        } else {
            # Can't extract, skip this file
            Write-Host "  [WARN] Could not extract stash content for: $filePath" -ForegroundColor Yellow
            continue
        }
    }
    
    # Get current version
    $currentContent = Get-Content $filePath -Raw -ErrorAction SilentlyContinue
    if ($null -eq $currentContent) { $currentContent = "" }
    
    # Normalize line endings
    $stashNormalized = $stashContent -replace "`r`n", "`n" -replace "`r", "`n"
    $currentNormalized = $currentContent -replace "`r`n", "`n" -replace "`r", "`n"
    
    if ($stashNormalized -eq $currentNormalized) {
        $identicalCount++
        Write-Host "  [OK] Identical: $filePath" -ForegroundColor Gray
    } else {
        $differentCount++
        
        # Calculate line differences
        $stashLines = ($stashNormalized -split "`n").Count
        $currentLines = ($currentNormalized -split "`n").Count
        $lineDiff = $stashLines - $currentLines
        
        # Get a brief summary of differences
        $stashLinesArray = $stashNormalized -split "`n"
        $currentLinesArray = $currentNormalized -split "`n"
        
        $diffSummary = ""
        $maxCompare = [Math]::Min($stashLinesArray.Count, $currentLinesArray.Count)
        for ($i = 0; $i -lt $maxCompare; $i++) {
            if ($stashLinesArray[$i] -ne $currentLinesArray[$i]) {
                $diffSummary = "First difference at line $($i+1)"
                break
            }
        }
        
        if ($stashLines -ne $currentLines) {
            $diffSummary += " | Stash: $stashLines lines, Current: $currentLines lines"
        }
        
        # Check if it's a legacy duplicate
        $isLegacy = $false
        if ($filePath -like "force-app\main\default\classes\*.cls" -and 
            $filePath -notlike "force-app\main\default\classes\*\*.cls") {
            $className = Split-Path $filePath -Leaf
            $newLocation = "force-app\main\default\classes\controllers\$className"
            if (Test-Path $newLocation) {
                $isLegacy = $true
            }
        }
        
        $results += [PSCustomObject]@{
            File = $filePath
            Status = "DIFFERENT"
            Difference = $diffSummary
            LinesChanged = $lineDiff
            IsLegacy = $isLegacy
            StashLines = $stashLines
            CurrentLines = $currentLines
        }
        
        $statusIcon = if ($isLegacy) { "[LEGACY]" } else { "[DIFF]" }
        Write-Host "  $statusIcon Different: $filePath" -ForegroundColor Yellow
        Write-Host "      $diffSummary" -ForegroundColor DarkYellow
    }
}

# Generate report
$report = @"
STASH COMPARISON REPORT
=======================
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Stash: $stashName

SUMMARY
-------
Total Files in Stash: $($stashFiles.Count)
[OK] Identical Files: $identicalCount (can be discarded)
[DIFF] Different Files: $differentCount (need review)
[NEW] New Files in Stash: $newFilesCount (not in current version)

"@

# Add detailed differences
$report += "`nFILES WITH DIFFERENCES`n"
$report += "=" * 50 + "`n`n"

$differentFiles = $results | Where-Object { $_.Status -eq "DIFFERENT" }
$newFiles = $results | Where-Object { $_.Status -eq "NEW_IN_STASH" }

if ($differentFiles.Count -gt 0) {
    $report += "Modified Files ($($differentFiles.Count)):`n`n"
    foreach ($file in $differentFiles) {
        $legacyNote = if ($file.IsLegacy) { " [LEGACY DUPLICATE]" } else { "" }
        $report += "[MODIFIED] $($file.File)$legacyNote`n"
        $report += "   Status: $($file.Status)`n"
        $report += "   Difference: $($file.Difference)`n"
        $report += "   Lines: Stash=$($file.StashLines), Current=$($file.CurrentLines), Diff=$($file.LinesChanged)`n`n"
    }
}

if ($newFiles.Count -gt 0) {
    $report += "`nNew Files in Stash ($($newFiles.Count)):`n`n"
    foreach ($file in $newFiles) {
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
Write-Host "[NEW] New Files: $newFilesCount files (not in current)" -ForegroundColor Cyan
Write-Host "`nReports saved:" -ForegroundColor Cyan
Write-Host "  - $reportPath" -ForegroundColor White
Write-Host "  - $diffSummaryPath" -ForegroundColor White

