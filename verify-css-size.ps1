# CSS Size Verification Script - Aufgabe 20
# Prüft die Größe der CSS-Datei nach dem Build

Write-Host "================================" -ForegroundColor Cyan
Write-Host "CSS Size Verification (Aufgabe 20)" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Check if dist folder exists
if (-not (Test-Path ".\dist")) {
    Write-Host "⚠️  dist/ folder not found. Running 'npm run build'..." -ForegroundColor Yellow
    npm run build
}

Write-Host ""
Write-Host "📊 CSS File Sizes:" -ForegroundColor Green
Write-Host ""

# Get all CSS files in dist
$cssFiles = Get-ChildItem -Path ".\dist\assets\*.css" -ErrorAction SilentlyContinue

if ($cssFiles.Count -eq 0) {
    Write-Host "❌ No CSS files found in dist/assets/" -ForegroundColor Red
    exit 1
}

$totalSize = 0
foreach ($file in $cssFiles) {
    $sizeKB = [math]::Round($file.Length / 1024, 2)
    $sizeBytes = $file.Length
    $totalSize += $sizeBytes
    
    Write-Host "  📄 $($file.Name)" -ForegroundColor White
    Write-Host "     Size: $sizeKB KB ($sizeBytes bytes)" -ForegroundColor Gray
    Write-Host ""
}

$totalSizeKB = [math]::Round($totalSize / 1024, 2)
Write-Host "📦 Total CSS Size: $totalSizeKB KB" -ForegroundColor Cyan
Write-Host ""

# Analyze optimization result
if ($totalSizeKB -lt 50) {
    Write-Host "✅ EXCELLENT! CSS is well-optimized (< 50 KB)" -ForegroundColor Green
    Write-Host "   → Tree-shaking worked perfectly" -ForegroundColor Green
    Write-Host "   → Expected: 35-50 KB with modular Bulma" -ForegroundColor Green
} elseif ($totalSizeKB -lt 100) {
    Write-Host "⚠️  MODERATE. CSS could be further optimized" -ForegroundColor Yellow
    Write-Host "   → Check if unused Bulma components are imported" -ForegroundColor Yellow
} else {
    Write-Host "❌ LARGE. CSS is not optimized" -ForegroundColor Red
    Write-Host "   → Verify that only modular components are imported" -ForegroundColor Red
}

Write-Host ""
Write-Host "📈 Expected Savings (vs Bulma CDN ~150 kB):" -ForegroundColor Cyan
$savings = [math]::Round((150 - $totalSizeKB) / 150 * 100, 1)
Write-Host "   → $savings% reduction in CSS file size" -ForegroundColor Cyan
Write-Host ""

Write-Host "🔍 Next Steps:" -ForegroundColor Gray
Write-Host "   1. Run: npm run dev" -ForegroundColor Gray
Write-Host "   2. Check browser DevTools > Network > CSS files" -ForegroundColor Gray
Write-Host "   3. Verify all styles load correctly" -ForegroundColor Gray
Write-Host ""
