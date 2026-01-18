--Aufgabe 22--
Betrieb und Wartung

1. Betriebskonzept:
Die Website FisherTechService wird als statische Website mit Astro, SCSS und Bulma betrieben. Inhalte und Styles werden lokal entwickelt, gebaut und anschliessend als statische Dateien ausgeliefert.

2. Komponenten der Software
- Astro: Static Site Generator für HTML-Ausgabe
- SCSS + Bulma: Styling mit modularen Komponenten
- Statische Assets: Bilder aus public/ und src/Photos/
- Build-Output: Statische Dateien in dist/

3. Relevante Commands
- NPM:
   - npm install      # Abhängigkeiten installieren
   - npm run dev      # Entwicklungsserver starten
   - npm run build    # Produktions-Build erzeugen
   - npm run preview  # Build lokal testen
- Yarn:
   - yarn install     # Abhängigkeiten installieren
   - yarn dev         # Entwicklungsserver starten
   - yarn build       # Produktions-Build erzeugen
   - yarn preview     # Build lokal testen

4. Website aktualisieren
- Inhalte werden in src/pages/*.astro angepasst
- Styles werden in src/assets/style.scss geändert
- Änderungen werden lokal getestet, danach gebaut und deployt

5. Auslieferung zum Browser
- Die Website wird statisch aus dem dist/-Ordner ausgeliefert
- Hosting erfolgt z. B. über GitHub Pages, Vercel, Netlify oder Nginx
- Der Browser lädt direkt HTML, CSS und Bilder (kein Backend notwendig)

6. Fazit
Der Betrieb ist einfach, wartungsarm und performant, da nur statische Dateien ausgeliefert werden. Updates erfolgen kontrolliert über den Build-Prozess und Deployment.