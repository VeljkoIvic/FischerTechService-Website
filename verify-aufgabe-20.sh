#!/bin/bash
# Aufgabe 20: Minification Verification Script
# Verifies that modular Sass and CSS minification work correctly

echo "======================================"
echo "Aufgabe 20: Minification Verification"
echo "======================================"
echo ""

# Check if dist folder exists
if [ ! -d "dist" ]; then
    echo "⚠️  dist/ folder not found. Building project..."
    npm run build
    echo ""
fi

# Check CSS files
echo "📊 CSS File Analysis:"
echo ""

for css_file in dist/_astro/*.css; do
    if [ -f "$css_file" ]; then
        size_bytes=$(stat --format=%s "$css_file")
        size_kb=$(echo "scale=2; $size_bytes / 1024" | bc)
        filename=$(basename "$css_file")
        
        echo "  📄 $filename"
        echo "     Size: ${size_kb} KB ($size_bytes bytes)"
        
        # Check if minified (no newlines or multiple spaces)
        if grep -q $'\n' "$css_file"; then
            echo "     Status: ⚠️  NOT MINIFIED (contains newlines)"
        else
            echo "     Status: ✅ MINIFIED (single line)"
        fi
        
        # Show first 100 characters
        first_chars=$(head -c 100 "$css_file")
        echo "     Preview: ${first_chars:0:80}..."
        echo ""
    fi
done

# Analysis
echo "🔍 Minification Status:"
echo ""

if [ -f "src/assets/style.scss" ]; then
    if grep -q '@forward "bulma/sass' src/assets/style.scss; then
        echo "  ✅ Modular Sass (@forward directives found)"
    else
        echo "  ❌ Modular Sass (@forward directives NOT found)"
    fi
fi

if grep -q 'outputStyle.*compressed' astro.config.mjs; then
    echo "  ✅ CSS Minification enabled (outputStyle: compressed)"
else
    echo "  ❌ CSS Minification NOT enabled"
fi

if [ -f "package.json" ] && grep -q '"sass-embedded"' package.json; then
    echo "  ✅ sass-embedded installed"
else
    echo "  ⚠️  sass-embedded may not be installed"
fi

echo ""
echo "======================================"
echo "Verification Complete!"
echo "======================================"
