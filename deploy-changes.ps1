# Flowdometer Deployment Script
# Deploys all modified and new files to Salesforce org

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Flowdometer Deployment Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Salesforce CLI is available
try {
    $sfdxVersion = sfdx --version
    Write-Host "✓ Salesforce CLI found: $sfdxVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Salesforce CLI not found. Please install Salesforce CLI first." -ForegroundColor Red
    exit 1
}

# Check if org is authenticated
Write-Host ""
Write-Host "Checking org connection..." -ForegroundColor Yellow
try {
    $orgInfo = sfdx force:org:display --json | ConvertFrom-Json
    Write-Host "✓ Connected to org: $($orgInfo.result.username)" -ForegroundColor Green
} catch {
    Write-Host "✗ Not connected to a Salesforce org. Please run: sfdx force:auth:web:login" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Files to deploy:" -ForegroundColor Yellow
Write-Host "  - MetaDataUtilityCls.cls" -ForegroundColor White
Write-Host "  - PostInstallScript.cls" -ForegroundColor White
Write-Host "  - ListenerFlowController.cls" -ForegroundColor White
Write-Host "  - ListenerMasterConfigurationController.cls" -ForegroundColor White
Write-Host "  - ListenerMasterConfigControllerTest.cls" -ForegroundColor White
Write-Host "  - flowdometerUninstallHelper LWC" -ForegroundColor White
Write-Host "  - viewAllDashboards LWC (new)" -ForegroundColor White
Write-Host ""

# Deploy using source:deploy
Write-Host "Deploying to Salesforce org..." -ForegroundColor Yellow
Write-Host ""

$deployPath = "force-app/main/default/classes,force-app/main/default/lwc"

try {
    # Deploy with test execution
    sfdx force:source:deploy `
        -p $deployPath `
        -w 30 `
        --verbose
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "✓ Deployment Successful!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Verify PostInstallScript executed correctly" -ForegroundColor White
        Write-Host "  2. Test Type field functionality in flows" -ForegroundColor White
        Write-Host "  3. Verify error messages display correctly" -ForegroundColor White
        Write-Host "  4. Test new viewAllDashboards component" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "✗ Deployment Failed" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please review the errors above and fix any issues." -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host "✗ Deployment error: $_" -ForegroundColor Red
    exit 1
}

