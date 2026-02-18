# Script to remove Flowdometer__ namespace prefixes from ALL metadata
# This makes source code "packaging org ready" for 2GP migration

$ErrorActionPreference = "Stop"

$totalReplacements = 0

# Get all metadata files to process
$metadataFiles = @()
$metadataFiles += Get-ChildItem -Path "force-app\main\default\flows" -Filter "*.flow-meta.xml" -Recurse
$metadataFiles += Get-ChildItem -Path "force-app\main\default\matchingRules" -Filter "*.matchingRule-meta.xml" -Recurse  
$metadataFiles += Get-ChildItem -Path "force-app\main\default\duplicateRules" -Filter "*.duplicateRule-meta.xml" -Recurse

Write-Host "Processing $($metadataFiles.Count) metadata files..." -ForegroundColor Cyan

foreach ($file in $metadataFiles) {
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    
    # Replace Flowdometer__ namespace prefix in XML
    $content = $content -replace 'Flowdometer__', ''
    
    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        $totalReplacements++
        Write-Host "Updated: $($file.Name)" -ForegroundColor Green
    }
}

Write-Host "`nTotal files updated: $totalReplacements" -ForegroundColor Cyan
Write-Host "Namespace cleanup complete!" -ForegroundColor Green
