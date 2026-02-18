# Flowdometer Package Content Visualizer
# Generates an HTML report showing what's in the package

$packageXmlPath = "manifest/package.xml"
$outputHtml = "package_contents_report.html"

Write-Host "Parsing package.xml..." -ForegroundColor Cyan

# Read and parse XML
[xml]$packageXml = Get-Content $packageXmlPath

# Extract all component types and members
$components = @{}
$totalCount = 0

foreach ($type in $packageXml.Package.types) {
    $typeName = $type.name
    $members = @($type.members | Where-Object { $_ -is [string] })
    
    if ($members.Count -gt 0) {
        $components[$typeName] = $members
        $totalCount += $members.Count
    }
}

# Generate HTML report
$html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Flowdometer Package Contents</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1 {
            color: #0070d2;
            border-bottom: 3px solid #0070d2;
            padding-bottom: 10px;
        }
        .summary {
            background: #f3f3f3;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .summary-item {
            display: inline-block;
            margin-right: 30px;
            font-size: 18px;
        }
        .summary-number {
            font-weight: bold;
            color: #0070d2;
            font-size: 24px;
        }
        .component-type {
            margin: 30px 0;
            border-left: 4px solid #0070d2;
            padding-left: 15px;
        }
        .component-type h2 {
            color: #333;
            margin-top: 0;
        }
        .count-badge {
            background: #0070d2;
            color: white;
            padding: 3px 10px;
            border-radius: 12px;
            font-size: 14px;
            margin-left: 10px;
        }
        .member-list {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 10px;
            margin-top: 10px;
        }
        .member-item {
            background: #f9f9f9;
            padding: 8px 12px;
            border-radius: 4px;
            border-left: 3px solid #0070d2;
        }
        .search-box {
            margin: 20px 0;
        }
        .search-box input {
            width: 100%;
            padding: 12px;
            font-size: 16px;
            border: 2px solid #ddd;
            border-radius: 5px;
        }
        .search-box input:focus {
            outline: none;
            border-color: #0070d2;
        }
        .api-version {
            color: #666;
            font-size: 14px;
            margin-top: 5px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th {
            background: #0070d2;
            color: white;
            padding: 12px;
            text-align: left;
        }
        td {
            padding: 10px;
            border-bottom: 1px solid #ddd;
        }
        tr:hover {
            background: #f9f9f9;
        }
    </style>
    <script>
        function searchComponents() {
            const searchTerm = document.getElementById('searchBox').value.toLowerCase();
            const types = document.querySelectorAll('.component-type');
            
            types.forEach(type => {
                const items = type.querySelectorAll('.member-item');
                let visibleCount = 0;
                
                items.forEach(item => {
                    const text = item.textContent.toLowerCase();
                    if (text.includes(searchTerm)) {
                        item.style.display = 'block';
                        visibleCount++;
                    } else {
                        item.style.display = 'none';
                    }
                });
                
                // Hide type section if no matches
                type.style.display = visibleCount > 0 ? 'block' : 'none';
            });
        }
    </script>
</head>
<body>
    <div class="container">
        <h1>📦 Flowdometer Package Contents</h1>
        <p class="api-version">API Version: $($packageXml.Package.version)</p>
        
        <div class="summary">
            <div class="summary-item">
                <div class="summary-number">$totalCount</div>
                <div>Total Components</div>
            </div>
            <div class="summary-item">
                <div class="summary-number">$($components.Count)</div>
                <div>Metadata Types</div>
            </div>
        </div>
        
        <div class="search-box">
            <input type="text" id="searchBox" placeholder="🔍 Search components..." onkeyup="searchComponents()">
        </div>
        
        <h2>Component Summary</h2>
        <table>
            <tr>
                <th>Metadata Type</th>
                <th>Count</th>
            </tr>
"@

# Add summary table
foreach ($type in $components.Keys | Sort-Object) {
    $count = $components[$type].Count
    $html += @"
            <tr>
                <td><strong>$type</strong></td>
                <td>$count</td>
            </tr>
"@
}

$html += @"
        </table>
        
        <h2>Detailed Component List</h2>
"@

# Add detailed sections for each type
foreach ($type in $components.Keys | Sort-Object) {
    $members = $components[$type] | Sort-Object
    $count = $members.Count
    
    $html += @"
        <div class="component-type">
            <h2>$type <span class="count-badge">$count</span></h2>
            <div class="member-list">
"@
    
    foreach ($member in $members) {
        $html += "                <div class='member-item'>$member</div>`n"
    }
    
    $html += @"
            </div>
        </div>
"@
}

$html += @"
    </div>
</body>
</html>
"@

# Write HTML file
$html | Out-File -FilePath $outputHtml -Encoding UTF8

Write-Host "`n✅ Report generated successfully!" -ForegroundColor Green
Write-Host "📄 Output: $outputHtml" -ForegroundColor Cyan
Write-Host "`nTotal Components: $totalCount" -ForegroundColor Yellow
Write-Host "Metadata Types: $($components.Count)" -ForegroundColor Yellow

# Open in browser
Start-Process $outputHtml

Write-Host "`n🌐 Opening report in browser..." -ForegroundColor Cyan
