# Script to remove Flowdometer__ namespace prefixes from Apex classes
# This makes source code "packaging org ready" for 2GP migration

$ErrorActionPreference = "Stop"

# Get all .cls files
$classFiles = Get-ChildItem -Path "force-app\main\default\classes" -Filter "*.cls" -Recurse

$totalReplacements = 0

foreach ($file in $classFiles) {
    $content = Get-Content $file.FullName -Raw
    $originalContent = $content
    
    # Replace Flowdometer__ namespace prefix
    # This regex avoids matching within comments
    $content = $content -replace '(?<!//.*)\bFlowdometer__', ''
    
    if ($content -ne $originalContent) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        $totalReplacements++
        Write-Host "Updated: $($file.FullName)" -ForegroundColor Green
    }
}

Write-Host "`nTotal files updated: $totalReplacements" -ForegroundColor Cyan
Write-Host "Namespace cleanup complete!" -ForegroundColor Green
