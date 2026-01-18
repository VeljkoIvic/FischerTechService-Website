--Aufgabe 20--
Minification mit SCSS

Um ein CSS-File zu erhalten, das möglichst nur die tatsächlich benötigten Styles enthält, wird ein dreistufiger Ansatz umgesetzt.
Zuerst werden bei Bulma nur die benötigten Komponenten selektiv über modularen Sass mit @use und @forward eingebunden, anstatt das gesamte Framework zu laden. Dadurch entstehen von Beginn an weniger CSS-Regeln.
Anschliessend wird das CSS im Build-Prozess minifiziert, wodurch unnötige Leerzeichen und Kommentare entfernt werden.
Zusätzlich sorgt Tree-Shaking durch Vite dafür, dass ungenutzte CSS-Klassen automatisch entfernt werden.

Das Resultat ist ein deutlich kleineres, performanteres CSS-Bundle, das die Ladezeit der Website spürbar verbessert.